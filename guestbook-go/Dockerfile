FROM golang:1.24-bookworm

RUN apt-get update && apt-get install --yes \
  build-essential \
  libsqlite3-dev && \
  rm --recursive --force /var/lib/apt/lists/*

WORKDIR /src

# Copy the Go module files and download dependencies
COPY guestbook-go/go.mod guestbook-go/go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  go mod download

# Build the guestbook CGI program with SQLite support
COPY guestbook-go/main.go ./
ENV CGO_ENABLED=1 GOOS=linux GOARCH=amd64
RUN --mount=type=cache,target=/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  go build -tags "sqlite_omit_load_extension" \
      -ldflags='-s -w -linkmode=external -extldflags "-static"' \
      -o guestbook.cgi ./main.go
