#!/bin/bash
# swap-preserve-mtime.sh - troca a base ativa por outra, PRESERVANDO o mtime.
#
# Simula o cenario de producao em que a base e trocada sem atualizar o
# timestamp (Docker image layers, cp -p, rsync -a).
#
# Uso: ./swap-preserve-mtime.sh db/base-B.mmdb

set -e
cd "$(dirname "$0")"

SRC="${1:?uso: $0 <arquivo-base.mmdb>}"
DST="db/GeoLite2-City.mmdb"

cp "$SRC" "$DST"
touch -t 202001010000 "$DST"

echo "base trocada para: $SRC"
echo "mtime (preservado): $(stat -f '%Sm' "$DST")"
echo "md5:  $(md5 -q "$DST")"
echo "size: $(stat -f %z "$DST") bytes"
