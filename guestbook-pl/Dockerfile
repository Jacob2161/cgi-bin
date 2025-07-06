FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install --yes --no-install-recommends \
  build-essential \
  ca-certificates \
  libsqlite3-0 \
  libsqlite3-dev \
  sqlite3 \
  perl \
  libdbi-perl \
  libdbd-sqlite3-perl \
  libcgi-pm-perl \
  && rm --recursive --force /var/lib/apt/lists/*

WORKDIR /src

# Copy the guestbook Perl script
COPY --chmod=755 guestbook-pl/guestbook.pl guestbook.cgi

# Verify the Perl script syntax and dependencies
RUN perl -c guestbook.cgi
