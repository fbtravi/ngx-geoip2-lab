#!/bin/bash
# swap-preserve-mtime.sh - swap the active database, PRESERVING the mtime.
#
# Simulates the production scenario where the database is replaced without
# updating the timestamp (Docker image layers, cp -p, rsync -a).
#
# Usage: ./swap-preserve-mtime.sh db/base-B.mmdb

set -e
cd "$(dirname "$0")"

SRC="${1:?usage: $0 <database-file.mmdb>}"
DST="db/GeoLite2-City.mmdb"

cp "$SRC" "$DST"
touch -t 202001010000 "$DST"

echo "database swapped to: $SRC"
echo "mtime (preserved): $(stat -f '%Sm' "$DST")"
echo "md5:  $(md5 -q "$DST")"
echo "size: $(stat -f %z "$DST") bytes"
