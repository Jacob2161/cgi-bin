# Server container
FROM httpd:2.4.63-bookworm

ARG PORT=1111

# Install dependencies
RUN apt-get update && apt-get install --yes --no-install-recommends \
  ca-certificates \
  libsqlite3-0 \
  libsqlite3-dev \
  sqlite3 \
  python3 \
  perl \
  libdbi-perl \
  libdbd-sqlite3-perl \
  libcgi-pm-perl \
  && rm --recursive --force /var/lib/apt/lists/*

# Create user directory
RUN mkdir --parents /usr/local/apache2/htdocs/~jakegold/cgi-bin

# Copy configuration files
COPY apache/httpd.conf /usr/local/apache2/conf/httpd.conf
RUN sed --in-place "s/DOCKERFILE_PORT/${PORT}/" /usr/local/apache2/conf/httpd.conf
COPY apache/perf.conf /usr/local/apache2/conf/extra/perf.conf

# Copy guestbook-go.cgi
COPY \
  --from=guestbook-go:latest \
  --chmod=755 /src/guestbook.cgi \
  /usr/local/apache2/htdocs/~jakegold/cgi-bin/guestbook-go.cgi

# Copy guestbook-rs.cgi
COPY \
  --from=guestbook-rs:latest \
  --chmod=755 /src/guestbook.cgi \
  /usr/local/apache2/htdocs/~jakegold/cgi-bin/guestbook-rs.cgi

# Copy guestbook-c.cgi
COPY \
  --from=guestbook-c:latest \
  --chmod=755 /src/guestbook.cgi \
  /usr/local/apache2/htdocs/~jakegold/cgi-bin/guestbook-c.cgi

# Copy guestbook-py.cgi
COPY \
  --from=guestbook-py:latest \
  --chmod=755 /src/guestbook.cgi \
  /usr/local/apache2/htdocs/~jakegold/cgi-bin/guestbook-py.cgi

# Copy guestbook-pl.cgi
COPY \
  --from=guestbook-pl:latest \
  --chmod=755 /src/guestbook.cgi \
  /usr/local/apache2/htdocs/~jakegold/cgi-bin/guestbook-pl.cgi

# Copy guestbook-sh.cgi
COPY \
  --from=guestbook-sh:latest \
  --chmod=755 /src/guestbook.cgi \
  /usr/local/apache2/htdocs/~jakegold/cgi-bin/guestbook-sh.cgi

EXPOSE ${PORT}
