#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DB="/tmp/guestbook-sh.db"
# Use SCRIPT_NAME if available, otherwise construct it from REQUEST_URI or use a default
SCRIPT="${SCRIPT_NAME:-}"
if [[ -z $SCRIPT ]]; then
  # Fallback to a reasonable default
  SCRIPT="/~jakegold/cgi-bin/guestbook-sh.cgi"
fi

url_decode() {
  local data=${1//+/ } out i h
  while [[ $data =~ %([0-9A-Fa-f]{2}) ]]; do
    h=${BASH_REMATCH[1]}
    printf -v i "\\x$h"
    data=${data//%$h/$i}
  done
  printf '%s' "$data"
}

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

init_db() {
  [[ -e $DB ]] && return
  sqlite3 "$DB" <<'SQL' > /dev/null
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA busy_timeout=5000;
PRAGMA cache_size=10000;
CREATE TABLE IF NOT EXISTS guestbook(
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  name    TEXT NOT NULL,
  message TEXT NOT NULL,
  created DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_guestbook_created ON guestbook(created);
CREATE INDEX IF NOT EXISTS idx_guestbook_name    ON guestbook(name);
CREATE INDEX IF NOT EXISTS idx_guestbook_message ON guestbook(message);
SQL
}

insert_entry() {
  # Use sqlite3 with proper SQL string escaping
  sqlite3 "$DB" "PRAGMA busy_timeout=5000; INSERT INTO guestbook(name, message) VALUES('$(printf '%s' "$1" | sed "s/'/''/g")', '$(printf '%s' "$2" | sed "s/'/''/g")');" > /dev/null
}

list_entries() {
  sqlite3 -separator $'\t' "$DB" \
    'SELECT name, message, created FROM guestbook ORDER BY created DESC LIMIT 100' 2>/dev/null
}

# Setup the database
init_db

# Handle the POST request
if [[ "${REQUEST_METHOD:-GET}" == "POST" ]]; then
  read -r -N "${CONTENT_LENGTH:-0}" POST_DATA || true
  declare -A kv
  for pair in ${POST_DATA//&/ }; do
    IFS='=' read -r k v <<<"$pair"
    kv[$(url_decode "$k")]=$(url_decode "$v")
  done
  name=${kv[name]:-}
  msg=${kv[message]:-}
  [[ -n $name && -n $msg ]] && insert_entry "$name" "$msg"
  printf 'Status: 303 See Other\r\nLocation: %s\r\n\r\n' "$SCRIPT"

# Handle the GET request
else
  printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
  cat <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Guestbook</title>
<style>body{font-family:sans-serif}form{margin-bottom:2em}textarea{width:100%;height:6em}</style>
</head><body><h2>Guestbook</h2>
<form method="post" action="${SCRIPT}">
<label>Name:<br><input name="name" required></label><br>
<label>Message:<br><textarea name="message" required></textarea></label><br>
<button type="submit">Sign</button></form>
HTML
  while IFS=$'\t' read -r name msg created; do
    printf '<div><strong>%s</strong> <em>%s</em><p>%s</p></div><hr>\n' \
      "$(printf '%s' "$name" | html_escape)" \
      "$(printf '%s' "$created" | html_escape)" \
      "$(printf '%s' "$msg" | html_escape | sed 's/$/<br>/')"
  done < <(list_entries)
  printf '</body></html>'
fi
