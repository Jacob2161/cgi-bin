use std::{
    env,
    path::Path,
    time::Duration,
};

use cgi::{html_response, Request, Response};
use cgi::http::StatusCode;
use rusqlite::{params, Connection};
use url::form_urlencoded;

const DB_PATH: &str = "/tmp/guestbook-rs.db";

const PAGE_TMPL: &str = r#"<!DOCTYPE html><html><head><meta charset="utf-8"><title>Guestbook</title>
<style>body{font-family:sans-serif}form{margin-bottom:2em}textarea{width:100%;height:6em}</style>
</head><body><h2>Guestbook</h2>
<form method="post" action="{script}">
<label>Name:<br><input name="name" required></label><br>
<label>Message:<br><textarea name="message" required></textarea></label><br>
<button type="submit">Sign</button></form>
{entries}
</body></html>"#;

struct Entry {
    name: String,
    message: String,
    created: String,
}

fn open_db() -> Connection {
    let new = !Path::new(DB_PATH).exists();
    let conn = Connection::open(DB_PATH).expect("open db");

    // Same pragmas the Go DSN enables.
    conn.pragma_update(None, "journal_mode", &"WAL").ok();
    conn.pragma_update(None, "synchronous", &"NORMAL").ok();
    conn.busy_timeout(Duration::from_millis(5_000)).ok();
    conn.pragma_update(None, "cache_size", &10_000i32).ok();

    if new {
        conn.execute_batch(
            r#"
            CREATE TABLE guestbook(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              message TEXT NOT NULL,
              created DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX index_guestbook_created  ON guestbook(created);
            CREATE INDEX index_guestbook_name     ON guestbook(name);
            CREATE INDEX index_guestbook_message  ON guestbook(message);
        "#,
        )
        .expect("create table");
    }
    conn
}

fn list(conn: &Connection, script_url: &str) -> Response {
    let mut stmt = conn
        .prepare(
            "SELECT name, message, created
             FROM guestbook
             ORDER BY created DESC
             LIMIT 100",
        )
        .unwrap();

    let rows = stmt
        .query_map([], |r| {
            Ok(Entry {
                name: r.get(0)?,
                message: r.get(1)?,
                created: r.get(2)?,
            })
        })
        .unwrap();

    let mut entries = String::new();
    for row in rows {
        let e = row.unwrap();
        entries.push_str(&format!(
            "<div><strong>{}</strong> <em>{}</em><p>{}</p></div><hr>",
            html_escape::encode_text(&e.name),
            html_escape::encode_text(&e.created),
            html_escape::encode_text(&e.message)
        ));
    }

    let body = PAGE_TMPL
        .replace("{script}", script_url)
        .replace("{entries}", &entries);

    html_response(200, body)
}

fn sign(req: &mut Request, conn: &Connection, redirect_url: &str) -> Response {
    let buf = req.body();

    let mut name = String::new();
    let mut message = String::new();
    for (k, v) in form_urlencoded::parse(buf) {
        match &*k {
            "name" => name = v.into_owned(),
            "message" => message = v.into_owned(),
            _ => {}
        }
    }

    if !name.is_empty() && !message.is_empty() {
        let _ = conn.execute(
            "INSERT INTO guestbook (name, message) VALUES (?, ?)",
            params![name, message],
        );
    }

    redirect(redirect_url)
}

fn redirect(loc: &str) -> Response {
    let mut response = Response::new(Vec::new());
    *response.status_mut() = StatusCode::SEE_OTHER;
    response.headers_mut().insert("Location", loc.parse().unwrap());
    response
}

fn main() {
    let conn = open_db();

    cgi::handle(|mut req: Request| -> Response {
        let script_name = env::var("SCRIPT_NAME").unwrap_or_else(|_| "/".to_string());
        let script = req
            .uri()
            .path_and_query()
            .map(|p| p.as_str().to_string())
            .filter(|s| !s.is_empty())
            .unwrap_or(script_name);

        match req.method().as_str() {
            "POST" => sign(&mut req, &conn, &script),
            _ => list(&conn, &script),
        }
    });
}
