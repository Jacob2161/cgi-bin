#define _GNU_SOURCE
#include <ctype.h>
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static const char *DB_PATH = "/tmp/guestbook-c.db";

//
// Helpers
//
static void url_decode(char *s) {
    char *d = s;
    while (*s) {
        if (*s == '+') { *d++ = ' '; s++; }
        else if (*s == '%' && isxdigit((unsigned char)s[1]) && isxdigit((unsigned char)s[2])) {
            int v; sscanf(s + 1, "%2x", &v); *d++ = v; s += 3;
        } else { *d++ = *s++; }
    }
    *d = '\0';
}
static void html_escape(const char *src, FILE *out) {
    for (; *src; src++) {
        switch (*src) {
            case '&': fputs("&amp;",  out); break;
            case '<': fputs("&lt;",   out); break;
            case '>': fputs("&gt;",   out); break;
            case '"': fputs("&quot;", out); break;
            case '\'': fputs("&#x27;", out); break;
            default: fputc(*src, out);
        }
    }
}
static int db_init(sqlite3 **db) {
    int new = access(DB_PATH, F_OK);
    if (sqlite3_open(DB_PATH, db) != SQLITE_OK) return 1;
    sqlite3_busy_timeout(*db, 5000);
    sqlite3_exec(*db, "PRAGMA journal_mode=WAL;"
                       "PRAGMA synchronous=NORMAL;"
                       "PRAGMA cache_size=10000;", 0, 0, 0);
    if (new == 0) return 0;
    const char *schema =
        "CREATE TABLE guestbook("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT NOT NULL,"
        "message TEXT NOT NULL,"
        "created DATETIME DEFAULT CURRENT_TIMESTAMP);"
        "CREATE INDEX idx_created  ON guestbook(created);"
        "CREATE INDEX idx_name     ON guestbook(name);"
        "CREATE INDEX idx_message  ON guestbook(message);";
    return sqlite3_exec(*db, schema, 0, 0, 0) != SQLITE_OK;
}

//
// Request handlers
//
static void redirect(const char *loc) {
    printf("Status: 303 See Other\r\nLocation: %s\r\n\r\n", loc);
}

static void sign_handler(sqlite3 *db, const char *self) {
    long len = strtol(getenv("CONTENT_LENGTH") ?: "0", 0, 10);
    if (len <= 0 || len > 16 * 1024) { redirect(self); return; }

    char *buf = malloc(len + 1);
    if (!buf) { redirect(self); return; }
    
    size_t total_read = 0;
    while (total_read < (size_t)len) {
        size_t read_now = fread(buf + total_read, 1, len - total_read, stdin);
        if (read_now == 0) break;
        total_read += read_now;
    }
    buf[total_read] = '\0';

    char *name = NULL, *msg = NULL, *tok, *save;
    for (tok = strtok_r(buf, "&", &save); tok; tok = strtok_r(NULL, "&", &save)) {
        char *eq = strchr(tok, '=');
        if (!eq) continue;
        *eq = '\0';
        url_decode(tok); url_decode(eq + 1);
        if (strcmp(tok, "name") == 0)    name = eq + 1;
        else if (strcmp(tok, "message") == 0) msg = eq + 1;
    }
    
    if (name && *name && msg && *msg && 
        strlen(name) <= 100 && strlen(msg) <= 2000) {
        sqlite3_stmt *st;
        if (sqlite3_prepare_v2(db, "INSERT INTO guestbook(name,message) VALUES(?,?)", -1, &st, 0) == SQLITE_OK) {
            sqlite3_bind_text(st, 1, name, -1, SQLITE_STATIC);
            sqlite3_bind_text(st, 2, msg,  -1, SQLITE_STATIC);
            sqlite3_step(st);
            sqlite3_finalize(st);
        }
    }
    free(buf);
    redirect(self);
}

static void list_handler(sqlite3 *db, const char *self) {
    puts("Content-Type: text/html; charset=utf-8\r\n");
    puts("<!DOCTYPE html><html><head><meta charset=utf-8>"
         "<title>Guestbook</title>"
         "<style>body{font-family:sans-serif}"
         "form{margin-bottom:2em}"
         "textarea{width:100%;height:6em}</style></head><body><h2>Guestbook</h2>");
    printf("<form method=post action=\"%s\">"
           "<label>Name:<br><input name=name required maxlength=100></label><br>"
           "<label>Message:<br><textarea name=message required maxlength=2000></textarea></label><br>"
           "<button type=submit>Sign</button></form>\n", self);

    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(db,
        "SELECT name, message, created FROM guestbook ORDER BY created DESC LIMIT 100", -1, &st, 0) == SQLITE_OK) {
        while (sqlite3_step(st) == SQLITE_ROW) {
            const char *name = (const char *)sqlite3_column_text(st, 0);
            const char *msg  = (const char *)sqlite3_column_text(st, 1);
            const char *cre  = (const char *)sqlite3_column_text(st, 2);
            fputs("<div><strong>", stdout); html_escape(name, stdout); fputs("</strong> <em>", stdout);
            html_escape(cre, stdout); fputs("</em><p>", stdout); html_escape(msg, stdout);
            fputs("</p></div><hr>", stdout);
        }
        sqlite3_finalize(st);
    }
    puts("</body></html>");
}

/* --- main ------------------------------------------------------------ */
int main(void) {
    sqlite3 *db;
    if (db_init(&db)) { fprintf(stderr, "db init failed\n"); return 1; }

    const char *method = getenv("REQUEST_METHOD") ?: "GET";
    const char *uri    = getenv("REQUEST_URI");
    const char *self   = (uri && *uri) ? uri : (getenv("SCRIPT_NAME") ?: "/");

    if (strcmp(method, "POST") == 0)
        sign_handler(db, self);
    else
        list_handler(db, self);

    sqlite3_close(db);
    return 0;
}
