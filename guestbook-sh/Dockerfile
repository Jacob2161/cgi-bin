FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install --yes --no-install-recommends \
  build-essential \
  ca-certificates \
  libsqlite3-0 \
  libsqlite3-dev \
  sqlite3 \
  && rm --recursive --force /var/lib/apt/lists/*

WORKDIR /src

# Copy the guestbook Perl script
COPY --chmod=755 guestbook-sh/guestbook.sh guestbook.cgi

# Verify the Bash script syntax
RUN bash -n guestbook.cgi
