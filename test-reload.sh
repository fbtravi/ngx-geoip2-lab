#!/bin/bash
# test-reload.sh - testa a troca da base com mtime preservado nos dois nginx.
#
# Uso: ./test-reload.sh
#
# Estagios:
#   0. reset: base A ativa com mtime velho (2020)
#   1. lookup inicial: popula o cache dos dois (espera Base A)
#   2. troca: cp base-B por cima, mtime volta para 2020 (preservado)
#   3. imediato: consulta logo apos a troca
#   4. pos-reload: espera 10s e consulta de novo
#   5. confirmacao: consulta final para ver o estado estavel

cd "$(dirname "$0")" || exit 1

A="http://localhost:8080/geoip"
B="http://localhost:8081/geoip"
IP="8.8.8.8"

city() { curl -s -H "X-Test-IP: $IP" "$1" | grep -o '"city":"[^"]*"' | cut -d'"' -f4; }

echo "=============================================================="
echo " STAGE 0 - reset: base A ativa, mtime = 2020-01-01"
echo "=============================================================="
cp db/base-A.mmdb db/GeoLite2-City.mmdb
touch -t 202001010000 db/GeoLite2-City.mmdb
docker compose restart > /dev/null 2>&1
sleep 6
echo "base ativa: $(md5 -q db/GeoLite2-City.mmdb)"
echo "mtime:      $(stat -f '%Sm' db/GeoLite2-City.mmdb)"
echo

echo "=============================================================="
echo " STAGE 1 - lookup inicial (popula cache dos dois nginx)"
echo "=============================================================="
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " STAGE 2 - troca da base: cp base-B, mtime PRESERVADO (2020)"
echo "=============================================================="
cp db/base-B.mmdb db/GeoLite2-City.mmdb
touch -t 202001010000 db/GeoLite2-City.mmdb
echo "base ativa: $(md5 -q db/GeoLite2-City.mmdb)  (era base-B)"
echo "mtime:      $(stat -f '%Sm' db/GeoLite2-City.mmdb)  <- nao mudou!"
echo "size:       $(stat -f %z db/GeoLite2-City.mmdb)  (A=$(stat -f %z db/base-A.mmdb), B=$(stat -f %z db/base-B.mmdb))"
echo

echo "=============================================================="
echo " STAGE 3 - imediato apos a troca (reload ainda nao rodou)"
echo "=============================================================="
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " STAGE 4 - 10s depois (auto_reload 5s ja deveria ter rodado)"
echo "=============================================================="
sleep 10
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " STAGE 5 - confirmacao: segunda consulta (estado estavel)"
echo "=============================================================="
printf "  nginx-a (8080): '%s'\n" "$(city $A)"
printf "  nginx-b (8081): '%s'\n" "$(city $B)"
echo

echo "=============================================================="
echo " reloads disparados (ultimos 2 min):"
echo "   nginx-a: $(docker compose logs nginx-a --since 2m 2>&1 | grep -c 'Reload MMDB' || true)"
echo "   nginx-b: $(docker compose logs nginx-b --since 2m 2>&1 | grep -c 'Reload MMDB' || true)"
echo "=============================================================="
