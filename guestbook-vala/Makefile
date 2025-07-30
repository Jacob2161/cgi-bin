CC      = valac
CFLAGS  = -O2 -pipe -Wall -Wextra
LDLIBS  = --pkg sqlite3

guestbook.cgi: guestbook.vala
# 	$(CC) $<
	$(CC) $(LDLIBS) $< -o $@ 

clean:
	rm --force guestbook.cgi
