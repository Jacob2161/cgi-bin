FROM rust:1.88-bookworm

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
   build-essential \
   pkg-config \
   libsqlite3-dev \
 && rm --recursive --force /var/lib/apt/lists/*

WORKDIR /src

# Copy the Rust module files and download dependencies
COPY guestbook-rs/Cargo.toml guestbook-rs/Cargo.lock ./
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    cargo fetch

# Build the guestbook CGI program
COPY guestbook-rs/src ./src
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    cargo build --release --locked && \
    cp /src/target/release/guestbook /src/guestbook.cgi
