# ngx-geoip2-lab

Laboratório local para testar o módulo nginx [ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module) — em especial o comportamento do `auto_reload` quando a base GeoIP é trocada.

Sobe **dois nginx idênticos** (portas `8080` e `8081`) compartilhando a mesma base MMDB via bind mount, para você comparar comportamentos lado a lado (versões do módulo, cenários de troca da base, etc.).

## O que tem aqui

| Arquivo | Descrição |
|---|---|
| `docker-compose.yml` | Sobe os dois nginx (`nginx-a` em :8080, `nginx-b` em :8081) |
| `nginx.conf` | Config com `geoip2` + `auto_reload 5s` + IP fake via header `X-Test-IP` |
| `Dockerfile` | Imagem nginx com o módulo geoip2 |
| `db/` | Bases MMDB de teste (`base-A.mmdb`, `base-B.mmdb`, `GeoLite2-City.mmdb` — a ativa) |
| `set_ip.py` | Cadastra/substitui um IP ou rede na base (country + cidade, resto fixo) |
| `swap-preserve-mtime.sh` | Troca a base ativa **preservando o mtime** (simula produção) |
| `swap-fresh-mtime.sh` | Troca a base ativa com **mtime novo** (cenário normal) |
| `test-reload.sh` | Teste automatizado em estágios do cenário de troca com mtime preservado |
| `mmdbtool/` | Fonte Go do CLI que escreve nas bases (usado pelo `set_ip.py`) |

## Pré-requisitos

- Docker (com compose)
- Para editar as bases: Go (para compilar o `mmdbtool`) **ou** usar o binário já commitado em `bin/`

## Subindo o lab

```sh
docker compose up -d
```

Verifica:

```sh
curl -H "X-Test-IP: 8.8.8.8" http://localhost:8080/geoip
# {"ip":"8.8.8.8","country_code":"US","country_name":"US","city":"Base A"}
```

> O header `X-Test-IP` define o IP "do cliente" — assim você testa qualquer IP sem depender do IP real da requisição.

## Editando a base de teste

As bases são criadas/editadas com o `set_ip.py`:

```sh
# cadastra o IP 8.8.8.8 como BR com cidade "Sao Paulo" na base ativa
python3 set_ip.py db/GeoLite2-City.mmdb 8.8.8.8 BR --city "Sao Paulo"

# cadastra uma rede inteira
python3 set_ip.py db/GeoLite2-City.mmdb 10.0.0.0/24 BR --city "Rede Privada"

# consulta sem gravar
python3 set_ip.py db/GeoLite2-City.mmdb --get 8.8.8.8
```

O restante dos campos (location, continent, geoname_ids) é fixo. Country é o ISO de 2 letras (BR, US, ...).

Para recompilar a ferramenta de escrita (opcional — o binário já está em `bin/`):

```sh
cd mmdbtool && go build -o ../bin/mmdbtool .
```

## Testando a troca da base (auto_reload)

### Cenário 1: mtime novo (funciona em qualquer versão)

```sh
./swap-fresh-mtime.sh db/base-B.mmdb
sleep 6
curl -H "X-Test-IP: 8.8.8.8" http://localhost:8080/geoip
# -> "city":"Base B"  (o reload detectou pelo mtime novo)
```

### Cenário 2: mtime preservado (o caso problemático)

Simula o que acontece em produção quando a base é trocada sem atualizar o timestamp (layers de imagem Docker, `cp -p`, `rsync -a`):

```sh
./swap-preserve-mtime.sh db/base-B.mmdb
sleep 6
curl -H "X-Test-IP: 8.8.8.8" http://localhost:8080/geoip
```

Neste cenário, o módulo **sem** detecção por inode/tamanho nunca recarrega — fica preso na base velha para sempre (e pode retornar vazio, porque o mmap foi reescrito in-place).

### Teste automatizado

```sh
./test-reload.sh
```

Roda o cenário completo em 5 estágios, mostrando a resposta de cada nginx em cada momento (reset, lookup inicial, troca com mtime preservado, imediato, pós-reload, confirmação) e quantos reloads cada um disparou nos logs.

## Usando bases MMDB reais

As bases em `db/` são de teste (pequenas, com poucos IPs). Para usar bases reais (GeoLite2/GeoIP2 da MaxMind):

1. Coloque o arquivo real em `db/` (ex.: `db/GeoLite2-City.mmdb` — o nome que o `nginx.conf` espera), ou
2. Edite o caminho no `nginx.conf` (`geoip2 /etc/nginx/geoip/SEU_ARQUIVO.mmdb {`) e monte o volume correspondente.

Para comparar módulos diferentes (ex.: um com fix, outro sem), monte imagens diferentes em cada serviço do `docker-compose.yml` — cada nginx pode apontar para uma imagem distinta enquanto compartilham a mesma base.

## Por que dois nginx?

Para comparação lado a lado:

- **A/B de versões do módulo:** um com o fix X, outro sem — mesma base, mesma requisição, comportamento diferente.
- **Antes/depois:** deixar um estável como referência enquanto o outro sofre as trocas de base.
- **Reprodutibilidade:** os dois recebem a mesma base via bind mount, então qualquer diferença na resposta vem do módulo, não do dado.

## Contexto

Este lab nasceu da investigação da issue [leev/ngx_http_geoip2_module#134](https://github.com/leev/ngx_http_geoip2_module/issues/134) e do PR [#138](https://github.com/leev/ngx_http_geoip2_module/pull/138), que tratam de dados stale/corrompidos quando a base é trocada com `auto_reload` ligado.
