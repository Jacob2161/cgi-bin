# cgi-bin

See my blog posts related to this repo:

* [Serving 200 million requests per day with a cgi-bin](https://jacob.gold/posts/serving-200-million-requests-with-cgi-bin/)
* [Serving a half billion requests per day with Rust + CGI](https://jacob.gold/posts/serving-half-billion-requests-with-rust-cgi/)

## apache

### Build all of the required containers

```bash
scripts/build
```

## Run the gohttpd container

```bash
scripts/run gohttpd
```

## Run the apache container

```bash
scripts/run apache
```

## Benchmark writes

```bash
scripts/benchmark localhost go 3000 100
```
