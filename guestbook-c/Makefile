CC      = gcc
CFLAGS  = -O2 -pipe -Wall -Wextra
LDLIBS  = -lsqlite3

guestbook.cgi: guestbook.c
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

clean:
	rm --force guestbook.cgi
