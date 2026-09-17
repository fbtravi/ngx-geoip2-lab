#!/bin/bash
# swap-fresh-mtime.sh - troca a base ativa por outra, com mtime NOVO.
#
# Cenario "normal": o mtime muda, entao o auto_reload tradicional detecta.
#
# Uso: ./swap-fresh-mtime.sh db/base-B.mmdb

set -e
cd "$(dirname "$0")"

SRC="${1:?uso: $0 <arquivo-base.mmdb>}"
DST="db/GeoLite2-City.mmdb"

cp "$SRC" "$DST"
touch "$DST"

echo "base trocada para: $SRC"
echo "mtime (novo): $(stat -f '%Sm' "$DST")"
echo "md5:  $(md5 -q "$DST")"
echo "size: $(stat -f %z "$DST") bytes"
