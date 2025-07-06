#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBI;
use CGI qw(:standard escapeHTML);

my $DB  = '/tmp/guestbook-pl.db';
my $DSN = "dbi:SQLite:dbname=$DB";

# Database setup
my $new_db = !-e $DB;
my $dbh    = DBI->connect(
    $DSN, '', '',
    {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
        sqlite_use_immediate_transaction => 1,
    }
);

$dbh->do('PRAGMA journal_mode=WAL');
$dbh->do('PRAGMA synchronous=NORMAL');
$dbh->do('PRAGMA busy_timeout=5000');
$dbh->do('PRAGMA cache_size=10000');

if ($new_db) {
    $dbh->do(<<'SQL');
CREATE TABLE guestbook(
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT NOT NULL,
    message TEXT NOT NULL,
    created DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_guestbook_created ON guestbook(created);
CREATE INDEX idx_guestbook_name    ON guestbook(name);
CREATE INDEX idx_guestbook_message ON guestbook(message);
SQL
}

# Handle POST request: insert new entry
my $cgi = CGI->new;
if ( $cgi->request_method eq 'POST' ) {
    my $name = $cgi->param('name')    // '';
    my $msg  = $cgi->param('message') // '';
    if ( $name ne '' && $msg ne '' ) {
        my $sth = $dbh->prepare('INSERT INTO guestbook(name, message) VALUES(?,?)');
        $sth->execute( $name, $msg );
    }
    print $cgi->redirect( $cgi->url(-path_info=>1) );
    exit;
}

# Handle GET request: display entries
my $rows = $dbh->selectall_arrayref(
    'SELECT name, message, created FROM guestbook ORDER BY created DESC LIMIT 100',
    { Slice => {} }
);

print $cgi->header( -type => 'text/html', -charset => 'UTF-8' );
print <<'HTML';
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Guestbook</title>
<style>body{font-family:sans-serif}form{margin-bottom:2em}textarea{width:100%;height:6em}</style>
</head><body><h2>Guestbook</h2>
HTML

print '<form method="post" action="', escapeHTML( $cgi->url(-path_info=>1) ), '">';
print q{<label>Name:<br><input name="name" required></label><br>};
print q{<label>Message:<br><textarea name="message" required></textarea></label><br>};
print q{<button type="submit">Sign</button></form>};

for my $e (@$rows) {
    print '<div><strong>', escapeHTML($e->{name}), '</strong> <em>', escapeHTML($e->{created}),
          '</em><p>', escapeHTML($e->{message}), '</p></div><hr>';
}

print '</body></html>';
