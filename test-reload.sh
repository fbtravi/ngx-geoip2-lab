#!/bin/bash
# test-reload.sh - test the database swap with preserved mtime on both nginx.
#
# Usage: ./test-reload.sh
#
# Stages:
#   0. reset: base A active with old mtime (2020)
#   1. initial lookup: populate both nginx caches (expects Base A)
#   2. swap: cp base-B over it, mtime back to 2020 (preserved)
#   3. immediate: query right after the swap
#   4. post-reload: wait 10s and query again
#   5. confirmation: final query to see the stable state

cd "$(dirname "$0")" || exit 1

A="http://localhost:8080/geoip"
B="http://localhost:8081/geoip"
IP="8.8.8.8"

city() { curl -s -H "X-Test-IP: $IP" "$1" | grep -o '"city":"[^"]*"' | cut -d'"' -f4; }

echo "=============================================================="
echo " STAGE 0 - reset: base A active, mtime = 2020-01-01"
echo "=============================================================="
cp db/base-A.mmdb db/GeoLite2-City.mmdb
touch -t 202001010000 db/GeoLite2-City.mmdb
docker compose restart > /dev/null 2>&1
sleep 6
echo "active db: $(md5 -q db/GeoLite2-City.mmdb)"
echo "mtime:     $(stat -f '%Sm' db/GeoLite2-City.mmdb)"
echo

echo "=============================================================="
echo " STAGE 1 - initial lookup (populate both nginx caches)"
echo "=============================================================="
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " STAGE 2 - swap database: cp base-B, mtime PRESERVED (2020)"
echo "=============================================================="
cp db/base-B.mmdb db/GeoLite2-City.mmdb
touch -t 202001010000 db/GeoLite2-City.mmdb
echo "active db: $(md5 -q db/GeoLite2-City.mmdb)  (was base-B)"
echo "mtime:     $(stat -f '%Sm' db/GeoLite2-City.mmdb)  <- did not change!"
echo "size:      $(stat -f %z db/GeoLite2-City.mmdb)  (A=$(stat -f %z db/base-A.mmdb), B=$(stat -f %z db/base-B.mmdb))"
echo

echo "=============================================================="
echo " STAGE 3 - immediately after the swap (reload not run yet)"
echo "=============================================================="
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " STAGE 4 - 10s later (auto_reload 5s should have run)"
echo "=============================================================="
sleep 10
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " STAGE 5 - confirmation: second query (stable state)"
echo "=============================================================="
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " reloads triggered (last 2 min):"
echo "   nginx-a: $(docker compose logs nginx-a --since 2m 2>&1 | grep -c 'Reload MMDB' || true)"
echo "   nginx-b: $(docker compose logs nginx-b --since 2m 2>&1 | grep -c 'Reload MMDB' || true)"
echo "=============================================================="
