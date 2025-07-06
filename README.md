# cgi-bin

See my blog post [Serving 200 million requests per day with a cgi-bin](https://jacob.gold/posts/serving-200-million-requests-with-cgi-bin/)

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
plow \
  --method POST \
  --body "name=John+Carmack&message=Hello+from+id+software%21" \
  --content "application/x-www-form-urlencoded" \
  --concurrency 16 \
  --requests 100000 \
    http://localhost:1111/~jakegold/cgi-bin/guestbook-go.cgi

plow \
  --method POST \
  --body "name=John+Carmack&message=Hello+from+id+software%21" \
  --content "application/x-www-form-urlencoded" \
  --concurrency 16 \
  --requests 100000 \
    http://localhost:1111/~jakegold/cgi-bin/guestbook-rs.cgi
```

## Benchmark reads

```bash
plow \
  --method GET \
  --concurrency 16 \
  --requests 100000 \
    http://localhost:1111/~jakegold/cgi-bin/guestbook-go.cgi

plow \
  --method GET \
  --concurrency 16 \
  --requests 100000 \
    http://localhost:1111/~jakegold/cgi-bin/guestbook-rs.cgi
```
