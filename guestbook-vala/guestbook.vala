
const string DB_PATH = "/tmp/guestbook-cs.db";

static int main(string[] args) {
    Sqlite.Database db;
    var method = GLib.Environment.get_variable("REQUEST_METHOD");
    var uri = GLib.Environment.get_variable("REQUEST_URI");
    var self = uri != null && uri != "" ? uri : GLib.Environment.get_variable("SCRIPT_NAME") ?? "/";
    init_db(out db);

    if (method == "POST")
        sign_handler(self, db);
    else
        list_handler(self, db);
    return 0;
}

static void list_handler(string self, Sqlite.Database db) {
    stdout.printf("Content-Type: text/html; charset=utf-8\r\n\n");
    stdout.printf("""<!DOCTYPE html><html><head><meta charset=utf-8>
<title>Guestbook</title>
<style>body{font-family:sans-serif}
form{margin-bottom:2em}
textarea{width:100%;height:6em}</style></head><body><h2>Guestbook</h2>""");
    stdout.printf("""<form method=post action='%s'>
<label>Name:<br><input name=name required maxlength=100></label><br>
<label>Message:<br><textarea name=message required maxlength=2000></textarea></label><br>
<button type=submit>Sign</button></form>""", self);

    Sqlite.Statement stmt;
    int ec = -1;
    const string prepared_query_str = "SELECT name, message, created FROM guestbook ORDER BY created DESC LIMIT 100;";
    ec = db.prepare_v2(prepared_query_str, prepared_query_str.length, out stmt);
    if (ec != Sqlite.OK) {
        return;
    }

    // int param_position = stmt.bind_parameter_index ("$UID");
    // assert (param_position > 0);

    // stmt.bind_int (param_position, 1);
    while (stmt.step() == Sqlite.ROW) {
        var name = stmt.column_text(0);
        var msg = stmt.column_text(1);
        var create = stmt.column_text(2);
        stdout.printf("<div><strong>%s</strong><em>%s</em><p>%s</p></div><hr>\n", name, create, msg);
    }

    stdout.printf("</body></html>\n");
}

static void sign_handler(string self, Sqlite.Database db) {
    int len = -1;
    string content_length = GLib.Environment.get_variable("CONTENT_LENGTH");
    if (content_length == null) {
        redirect(self); return;
    }
    var result = int.try_parse(content_length, out len);

    if (!result || len <= 0 || len > 16 * 1024) {
        redirect(self); return;
    }
    // load content:
	uint8[] buf = new uint8[len];
	size_t read = stdin.read (buf);
	assert (len == read);

	// display content:
    //  stdin.read( buf, len)
    var name = "";
    var msg = "";
    try{
        var queryString = GLib.Uri.parse_params((string) buf);
        name = queryString.get("name");
        msg = queryString.get("msg");

    }catch(Error err){
        // No Error log
    }

    if(name == null || name == "" || msg == null || msg == "" || name.length > 100 || msg.length > 2000 )
    {
        redirect(self);
        return;
    }

    const string insertQuery = "INSERT INTO guestbook(name,message) VALUES($name, $msg);";

    Sqlite.Statement stmt;
    int ec = -1;
    ec = db.prepare_v2(insertQuery, insertQuery.length, out stmt);
    if (ec != Sqlite.OK) {
        return;
    }

    int param_name_position = stmt.bind_parameter_index ("$name");
    int param_msg_position = stmt.bind_parameter_index ("$msg");
    stmt.bind_int (param_name_position, 1);
    stmt.bind_int (param_msg_position, 1);
    stmt.step();
    stmt.reset ();
    redirect(self);
}

static void redirect(string loc) {
    stdout.printf("Status: 303 See Other\r\nLocation: %s\r\n\n", loc);
}

static int init_db(out Sqlite.Database db) {
    int ec = Sqlite.Database.open(DB_PATH, out db);
    string errmsg;

    if (ec != Sqlite.OK) {
        return -1;
    }

    string query = """
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA cache_size=10000;

CREATE TABLE IF NOT EXISTS guestbook(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  message TEXT NOT NULL,
  created DATETIME DEFAULT CURRENT_TIMESTAMP);

CREATE INDEX IF NOT EXISTS idx_created  ON guestbook(created);
CREATE INDEX IF NOT EXISTS idx_name     ON guestbook(name);
CREATE INDEX IF NOT EXISTS idx_message  ON guestbook(message);
""";
    ec = db.exec(query, null, out errmsg);
    if (ec != Sqlite.OK) {
        return -1;
    }
    return ec;
}