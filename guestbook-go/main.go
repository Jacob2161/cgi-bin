package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"net/http/cgi"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

const guestbookHTML = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Guestbook</title>
<style>body{font-family:sans-serif}form{margin-bottom:2em}textarea{width:100%;height:6em}</style>
</head><body><h2>Guestbook</h2>
<form method="post" action="{{.ScriptURL}}">
<label>Name:<br><input name="name" required></label><br>
<label>Message:<br><textarea name="message" required></textarea></label><br>
<button type="submit">Sign</button></form>
{{range .Entries}}<div><strong>{{.Name}}</strong> <em>{{.Created}}</em><p>{{.Message}}</p></div><hr>{{end}}
</body></html>`

type entry struct {
	Name    string
	Message string
	Created string
}

type page struct {
	ScriptURL string
	Entries   []entry
}

const (
	databaseFile = "/tmp/guestbook-go.db"
)

var (
	db        *sql.DB
	templates = template.Must(template.New("page").Parse(guestbookHTML))
)

func main() {
	_, err := os.Stat(databaseFile)
	createTable := os.IsNotExist(err)

	dsn := fmt.Sprintf("file:%s?_journal_mode=WAL&_synchronous=NORMAL&_busy_timeout=5000&_cache_size=10000", databaseFile)
	db, err = sql.Open("sqlite3", dsn)
	if err != nil {
		slog.Error("open database failed", "error", err)
		os.Exit(1)
	}
	db.SetMaxOpenConns(1)

	if createTable {
		if _, err = db.Exec(`
			CREATE TABLE guestbook(
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				name TEXT NOT NULL,
				message TEXT NOT NULL,
				created DATETIME DEFAULT CURRENT_TIMESTAMP
			);
			CREATE INDEX index_guestbook_created ON guestbook(created);
			CREATE INDEX index_guestbook_name ON guestbook(name);
			CREATE INDEX index_guestbook_message ON guestbook(message);
		`); err != nil {
			slog.Error("create table failed", "error", err)
			os.Exit(1)
		}
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			signHandler(w, r)
		} else {
			listHandler(w, r)
		}
	})
	cgi.Serve(http.DefaultServeMux)
}

func listHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(`
		SELECT 
			name, message, created
		FROM
			guestbook
		ORDER BY
			created DESC
		LIMIT
			100
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var entries []entry
	for rows.Next() {
		var e entry
		if err = rows.Scan(&e.Name, &e.Message, &e.Created); err != nil {
			slog.Error("scan row failed", "error", err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		entries = append(entries, e)
	}
	if err = rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	scriptURL := r.URL.RequestURI()
	if scriptURL == "" {
		scriptURL = os.Getenv("SCRIPT_NAME")
	}

	data := page{
		ScriptURL: scriptURL,
		Entries:   entries,
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := templates.Execute(w, data); err != nil {
		slog.Error("execute template failed", "error", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func signHandler(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	name, msg := r.Form.Get("name"), r.Form.Get("message")
	if name == "" || msg == "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	if _, err := db.Exec(`
		INSERT INTO
			guestbook (name, message)
		VALUES
			(?, ?)
	`, name, msg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	redirectURL := r.URL.RequestURI()
	if redirectURL == "" {
		redirectURL = os.Getenv("SCRIPT_NAME")
	}
	http.Redirect(w, r, redirectURL, http.StatusSeeOther)
}
