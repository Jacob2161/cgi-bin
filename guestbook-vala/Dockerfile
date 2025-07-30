FROM golang:1.24-bookworm

RUN apt-get update && apt-get install --yes \
  build-essential \
  libsqlite3-dev \
  valac && \
  rm --recursive --force /var/lib/apt/lists/*

WORKDIR /src

COPY guestbook-vala/ .
RUN make
