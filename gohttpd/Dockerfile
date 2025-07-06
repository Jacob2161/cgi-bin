# Build gohttpd
FROM golang:1.24-bookworm AS build-gohttpd
WORKDIR /src
COPY gohttpd/go.mod gohttpd/go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  go mod download

COPY gohttpd/main.go ./
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN --mount=type=cache,target=/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  go build \
    -ldflags='-s -w -extldflags "-static"' \
    -o gohttpd ./main.go

# Server container
FROM debian:bookworm-slim

ARG PORT=1111
ARG HTTP_LISTEN_ADDRESS=0.0.0.0:${PORT}
ARG CGI_BIN_DIR=/home/jakegold/cgi-bin
ARG CGI_URL_PREFIX=/~jakegold/cgi-bin
ARG NODE_VERSION="24.3.0"

# Install dependencies
RUN apt-get update && apt-get install --yes --no-install-recommends \
  ca-certificates \
  curl \
  xz-utils \
  libsqlite3-0 \
  libsqlite3-dev \
  sqlite3 \
  python3 \
  perl \
  libdbi-perl \
  libdbd-sqlite3-perl \
  libcgi-pm-perl \
  && rm --recursive --force /var/lib/apt/lists/*

# Install Node.js
RUN curl --fail --silent --show-error --location \
  "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
  | tar --extract --xz --directory /usr/local --strip-components=1

RUN npm install --global sqlite3

# Copy the gohttpd binary
COPY --from=build-gohttpd /src/gohttpd /usr/local/bin/gohttpd
RUN chmod +x /usr/local/bin/gohttpd

# Create user directory
RUN mkdir --parents /home/jakegold/cgi-bin

# Copy guestbook-go.cgi
COPY \
  --from=guestbook-go:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-go.cgi

# Copy guestbook-rs.cgi
COPY \
  --from=guestbook-rs:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-rs.cgi

# Copy guestbook-c.cgi
COPY \
  --from=guestbook-c:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-c.cgi

# Copy guestbook-py.cgi
COPY \
  --from=guestbook-py:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-py.cgi

# Copy guestbook-pl.cgi
COPY \
  --from=guestbook-pl:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-pl.cgi

# Copy guestbook-sh.cgi
COPY \
  --from=guestbook-sh:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-sh.cgi

# Copy guestbook-js.cgi
COPY \
  --from=guestbook-js:latest \
  --chmod=755 /src/guestbook.cgi \
  /home/jakegold/cgi-bin/guestbook-js.cgi

ENV HTTP_LISTEN_ADDRESS=${HTTP_LISTEN_ADDRESS}
ENV CGI_BIN_DIR=${CGI_BIN_DIR}
ENV CGI_URL_PREFIX=${CGI_URL_PREFIX}

EXPOSE ${PORT}
ENTRYPOINT ["/usr/local/bin/gohttpd"]
