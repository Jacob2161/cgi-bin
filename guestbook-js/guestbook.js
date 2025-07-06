#!/usr/local/bin/node

process.env.NODE_PATH = '/usr/local/lib/node_modules';
require('module').Module._initPaths();

const fs = require("fs");
const { parse } = require("querystring");
const sqlite3 = require("sqlite3").verbose();

const DB = "/tmp/guestbook.db";
const HTML = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Guestbook</title>
<style>body{font-family:sans-serif}form{margin-bottom:2em}textarea{width:100%;height:6em}</style>
</head><body><h2>Guestbook</h2>
<form method="post" action="{SCRIPT}">
<label>Name:<br><input name="name" required></label><br>
<label>Message:<br><textarea name="message" required></textarea></label><br>
<button type="submit">Sign</button></form>
{ENTRIES}
</body></html>`;

const esc = s =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
   .replace(/>/g, "&gt;").replace(/"/g, "&quot;");

const db = new sqlite3.Database(DB, err => err && fatal(err));
db.serialize(() => {
  db.run("PRAGMA journal_mode=WAL");
  db.run("PRAGMA synchronous=NORMAL");
  db.run("PRAGMA cache_size=10000");
  db.run(`CREATE TABLE IF NOT EXISTS guestbook(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    message TEXT NOT NULL,
    created DATETIME DEFAULT CURRENT_TIMESTAMP)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_created  ON guestbook(created)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_name     ON guestbook(name)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_message  ON guestbook(message)`);
});

const self =
  process.env.REQUEST_URI && process.env.REQUEST_URI !== ""
    ? process.env.REQUEST_URI
    : process.env.SCRIPT_NAME || "/";

(process.env.REQUEST_METHOD || "GET").toUpperCase() === "POST"
  ? sign()
  : list();

function redirect(loc) {
  process.stdout.write(`Status: 303 See Other\r\nLocation: ${loc}\r\n\r\n`);
  process.exit(0);
}

function sign() {
  const body = fs.readFileSync(0, "utf8");
  const { name = "", message = "" } = parse(body);
  if (name.trim() && message.trim()) {
    db.run(
      "INSERT INTO guestbook(name, message) VALUES(?,?)",
      [name.trim(), message.trim()],
      () => redirect(self)
    );
  } else {
    redirect(self);
  }
}

function list() {
  db.all(
    `SELECT name, message, created FROM guestbook ORDER BY created DESC LIMIT 100`,
    (err, rows) => {
      if (err) fatal(err);
      const entries = rows
        .map(
          r =>
            `<div><strong>${esc(r.name)}</strong> <em>${esc(
              r.created
            )}</em><p>${esc(r.message)}</p></div><hr>`
        )
        .join("");
      const page = HTML.replace("{SCRIPT}", esc(self)).replace("{ENTRIES}", entries);
      process.stdout.write("Content-Type: text/html; charset=utf-8\r\n\r\n" + page);
    }
  );
}

function fatal(e) {
  process.stdout.write(`Status: 500\r\n\r\n${e.message}\n`);
  process.exit(1);
}
