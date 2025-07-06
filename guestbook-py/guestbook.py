#!/usr/bin/python3
import html
import os
import sqlite3
import sys
import textwrap
import time
import urllib.parse
from wsgiref.handlers import CGIHandler

DB_PATH = "/tmp/guestbook-py.db"
TEMPLATE = textwrap.dedent("""\
    <!DOCTYPE html><html><head><meta charset="utf-8"><title>Guestbook</title>
    <style>body{{font-family:sans-serif}}form{{margin-bottom:2em}}textarea{{width:100%;height:6em}}</style>
    </head><body><h2>Guestbook</h2>
    <form method="post" action="{script}">
    <label>Name:<br><input name="name" required></label><br>
    <label>Message:<br><textarea name="message" required></textarea></label><br>
    <button type="submit">Sign</button></form>
    {entries}
    </body></html>""")
ENTRY_HTML = "<div><strong>{name}</strong> <em>{created}</em><p>{msg}</p></div><hr>"
ERROR_TEMPLATE = textwrap.dedent("""\
    <!DOCTYPE html><html><head><meta charset="utf-8"><title>Error</title>
    <style>body{{font-family:sans-serif}}</style>
    </head><body><h2>Error</h2>
    <p>An error occurred while processing your request.</p>
    <p><a href="{script}">Back to Guestbook</a></p>
    </body></html>""")

def init_database():
    """Initialize the database with proper error handling"""
    try:
        conn = sqlite3.connect(
            f"file:{DB_PATH}?cache=shared&mode=rwc&_journal_mode=WAL&_busy_timeout=5000",
            uri=True,
            check_same_thread=False,
        )
        conn.execute(
            """CREATE TABLE IF NOT EXISTS guestbook(
                   id      INTEGER PRIMARY KEY AUTOINCREMENT,
                   name    TEXT    NOT NULL,
                   message TEXT    NOT NULL,
                   created DATETIME DEFAULT CURRENT_TIMESTAMP
               );"""
        )
        conn.executescript(
            """CREATE INDEX IF NOT EXISTS idx_guestbook_created ON guestbook(created);
               CREATE INDEX IF NOT EXISTS idx_guestbook_name    ON guestbook(name);
               CREATE INDEX IF NOT EXISTS idx_guestbook_message ON guestbook(message);"""
        )
        conn.commit()
        return conn
    except sqlite3.Error as e:
        print(f"Database initialization error: {e}", file=sys.stderr)
        return None

conn = init_database()

def error_response(start_response, script=""):
    """Return a generic error response"""
    error_page = ERROR_TEMPLATE.format(script=html.escape(script))
    hdr = [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(error_page)))]
    start_response("500 Internal Server Error", hdr)
    return [error_page.encode("utf-8")]

def application(environ, start_response):
    try:
        if conn is None:
            return error_response(start_response)
            
        method = environ["REQUEST_METHOD"]
        script = environ.get("SCRIPT_NAME", "") or environ.get("PATH_INFO", "/")
        
        if method == "POST":
            try:
                # read body safely; CONTENT_LENGTH may be absent for chunked requests
                length = int(environ.get("CONTENT_LENGTH", "0") or 0)
                if length > 10000:  # Limit body size to prevent DoS
                    start_response("413 Request Entity Too Large", [])
                    return [b"Request too large"]
                    
                body = environ["wsgi.input"].read(length)
                params = urllib.parse.parse_qs(body.decode("utf-8"), keep_blank_values=False)
                name = params.get("name", [""])[0].strip()
                msg = params.get("message", [""])[0].strip()
                
                if name and msg:
                    # Limit input lengths
                    name = name[:100]
                    msg = msg[:1000]
                    
                    with conn:
                        conn.execute("INSERT INTO guestbook(name, message) VALUES(?, ?)", (name, msg))
                        
            except (ValueError, UnicodeDecodeError, sqlite3.Error) as e:
                print(f"POST processing error: {e}", file=sys.stderr)
                return error_response(start_response, script)
                
            hdr = [("Location", script)]
            start_response("303 See Other", hdr)
            return [b""]  # no body
            
        # GET / – list entries
        try:
            rows = conn.execute(
                "SELECT name, message, created FROM guestbook ORDER BY created DESC LIMIT 100"
            ).fetchall()
            
            parts = []
            for r in rows:
                try:
                    parts.append(ENTRY_HTML.format(
                        name=html.escape(r[0]),
                        created=html.escape(r[2]),
                        msg=html.escape(r[1]).replace("\n", "<br>"),
                    ))
                except (IndexError, TypeError):
                    continue  # Skip malformed entries
                    
            page = TEMPLATE.format(script=html.escape(script), entries="".join(parts))
            hdr = [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(page)))]
            start_response("200 OK", hdr)
            return [page.encode("utf-8")]
            
        except sqlite3.Error as e:
            print(f"Database query error: {e}", file=sys.stderr)
            return error_response(start_response, script)
            
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return error_response(start_response, environ.get("SCRIPT_NAME", ""))

if __name__ == "__main__":
    CGIHandler().run(application)
