# cgi-bin

## apache

### Build the apache container

```bash
docker build --tag guestbook:apache --file Dockerfile.apache .
```

### Run the apache container

```bash
docker run --rm -it --network host guestbook:apache
```

## gohttpd

### Build the gohttpd container

```bash
docker build --tag guestbook:gohttpd --file Dockerfile.gohttpd .
```

### Run the gohttpd container

```bash
docker run --rm -it --network host guestbook:gohttpd
```

## Benchmark writes

```bash
plow \
  --method POST \
  --body "name=John+Carmack&message=Hello+from+id+software%21" \
  --content "application/x-www-form-urlencoded" \
  --concurrency 16 \
  --requests 100000 \
    http://localhost:1111/~jakegold/cgi-bin/guestbook.cgi
```

## Benchmark reads

```bash
plow \
  --method GET \
  --concurrency 16 \
  --requests 100000 \
    http://localhost:1111/~jakegold/cgi-bin/guestbook.cgi
```
