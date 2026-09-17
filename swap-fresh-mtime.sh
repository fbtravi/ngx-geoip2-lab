#!/bin/bash
# swap-fresh-mtime.sh - swap the active database, with a NEW mtime.
#
# The "normal" scenario: the mtime changes, so the classic auto_reload detects it.
#
# Usage: ./swap-fresh-mtime.sh db/base-B.mmdb

set -e
cd "$(dirname "$0")"

SRC="${1:?usage: $0 <database-file.mmdb>}"
DST="db/GeoLite2-City.mmdb"

cp "$SRC" "$DST"
touch "$DST"

echo "database swapped to: $SRC"
echo "mtime (new): $(stat -f '%Sm' "$DST")"
echo "md5:  $(md5 -q "$DST")"
echo "size: $(stat -f %z "$DST") bytes"
