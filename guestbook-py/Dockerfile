FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install --yes --no-install-recommends \
  build-essential \
  ca-certificates \
  libsqlite3-0 \
  libsqlite3-dev \
  sqlite3 \
  python3 \
  && rm --recursive --force /var/lib/apt/lists/*

# Verify the Python installation has all required modules
RUN python3 -c "import sqlite3, html, urllib.parse, wsgiref.handlers; print('All dependencies OK')"

WORKDIR /src

# Copy the Python guestbook script
COPY --chmod=755 guestbook-py/guestbook.py guestbook.cgi
