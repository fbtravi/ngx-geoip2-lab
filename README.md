# ngx-geoip2-lab

A local lab for testing the nginx [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module) — in particular the `auto_reload` behavior when the GeoIP database is swapped.

It runs **two identical nginx instances** (ports `8080` and `8081`) sharing the same MMDB database via bind mount, so you can compare behaviors side by side (module versions, database swap scenarios, etc.).

## Quick start

```sh
make up        # build and start both nginx containers
make curl-a    # query nginx-a (:8080) with the default fake IP 8.8.8.8
make curl-b    # query nginx-b (:8081)
```

Run `make help` to see all available targets.

## What's here

| File | Description |
|---|---|
| `Makefile` | Shortcuts for everything (`make up`, `make test`, `make swap-b-preserve`, ...) |
| `docker-compose.yml` | Runs the two nginx (`nginx-a` on :8080, `nginx-b` on :8081) |
| `nginx.conf` | Config with `geoip2` + `auto_reload 5s` + fake IP via the `X-Test-IP` header |
| `Dockerfile` | nginx image with the geoip2 module (built from upstream) |
| `db/` | Test MMDB databases (`base-A.mmdb`, `base-B.mmdb`, `GeoLite2-City.mmdb` — the active one) |
| `set_ip.py` | Add/replace an IP or network in a database (country + city, the rest is fixed) |
| `swap-preserve-mtime.sh` | Swap the active database **preserving the mtime** (simulates production) |
| `swap-fresh-mtime.sh` | Swap the active database with a **new mtime** (normal scenario) |
| `test-reload.sh` | Staged automated test of the preserved-mtime scenario |
| `mmdbtool/` | Go source of the CLI that writes to the databases (used by `set_ip.py`) |

## Prerequisites

- Docker (with compose)
- Go (only to build the `mmdbtool` binary used for editing databases): `make build-tool`

## Testing a database swap (auto_reload)

### Scenario 1: new mtime (works on any version)

```sh
make swap-b          # activate base-B with a fresh mtime
sleep 6
make curl-a          # -> "city":"Base B"  (reload detected via the new mtime)
```

### Scenario 2: preserved mtime (the problematic case)

Simulates what happens in production when the database is replaced without updating the timestamp (Docker image layers, `cp -p`, `rsync -a`):

```sh
make swap-b-preserve
sleep 6
make curl-a
```

With a module **without** inode/size change detection, the reload never fires — nginx stays stuck on the old database forever (and may return empty data, since the mmap was rewritten in place).

### Automated test

```sh
make test
```

Runs the full scenario in 5 stages, showing each nginx's response at every step (reset, initial lookup, preserved-mtime swap, immediately after, post-reload, confirmation) plus how many reloads each one logged.

## Editing the test database

Build the writer tool once, then use `set_ip.py`:

```sh
make build-tool

# add IP 8.8.8.8 as BR with city "Sao Paulo" in the active database
python3 set_ip.py db/GeoLite2-City.mmdb 8.8.8.8 BR --city "Sao Paulo"

# add a whole network
python3 set_ip.py db/GeoLite2-City.mmdb 10.0.0.0/24 BR --city "Private Net"

# query without writing
python3 set_ip.py db/GeoLite2-City.mmdb --get 8.8.8.8
```

Or via the Makefile:

```sh
make set IP=8.8.8.8 COUNTRY=BR CITY="Sao Paulo"
make get IP=8.8.8.8
```

All other fields (location, continent, geoname ids) are fixed. Country is the 2-letter ISO code (BR, US, ...).

## Using real MMDB databases

The databases in `db/` are tiny test fixtures with only a few IPs. To use real GeoLite2/GeoIP2 databases from MaxMind:

1. Drop the real file into `db/` as `GeoLite2-City.mmdb` (the name `nginx.conf` expects), or
2. Edit the path in `nginx.conf` (`geoip2 /etc/nginx/geoip/YOUR_FILE.mmdb {`) and adjust the volume mount.

To compare different module builds (e.g. one with a fix, one without), point each service in `docker-compose.yml` at a different image — both nginx share the same database via the bind mount.

## Why two nginx?

For side-by-side comparison:

- **Module version A/B:** one with fix X, one without — same database, same request, different behavior.
- **Before/after:** keep one stable as a reference while the other goes through database swaps.
- **Reproducibility:** both read the same database via bind mount, so any difference in the response comes from the module, not the data.

## Context

This lab grew out of the investigation of issue [leev/ngx_http_geoip2_module#134](https://github.com/leev/ngx_http_geoip2_module/issues/134) and PR [#138](https://github.com/leev/ngx_http_geoip2_module/pull/138), which deal with stale/corrupted data when the database is swapped with `auto_reload` enabled.
