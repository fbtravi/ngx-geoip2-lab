.PHONY: help up down restart logs logs-a logs-b ps test \
        swap-a swap-b swap-a-preserve swap-b-preserve \
        set get build-tool clean

COMPOSE = docker compose
IP     ?= 8.8.8.8
CITY   ?= Test City

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

## --- lab lifecycle -----------------------------------------------------------

build-tool: ## Build the mmdbtool binary (needed by set/get)
	cd mmdbtool && go build -o ../bin/mmdbtool .

up: ## Build and start both nginx containers
	$(COMPOSE) up -d --build

down: ## Stop and remove the containers
	$(COMPOSE) down

restart: ## Restart both nginx containers
	$(COMPOSE) restart

ps: ## Show container status
	$(COMPOSE) ps

logs: ## Tail logs from both containers
	$(COMPOSE) logs -f

logs-a: ## Tail logs from nginx-a (:8080)
	$(COMPOSE) logs -f nginx-a

logs-b: ## Tail logs from nginx-b (:8081)
	$(COMPOSE) logs -f nginx-b

## --- database operations -----------------------------------------------------

set: build-tool ## Set an IP/network: make set IP=8.8.8.8 COUNTRY=BR [CITY="Sao Paulo"]
	python3 set_ip.py db/GeoLite2-City.mmdb $(IP) $(COUNTRY) --city "$(CITY)"

get: build-tool ## Get an IP from the db: make get IP=8.8.8.8
	python3 set_ip.py db/GeoLite2-City.mmdb --get $(IP)

## --- swap scenarios ----------------------------------------------------------

swap-a: ## Activate base-A with a FRESH mtime (normal scenario)
	./swap-fresh-mtime.sh db/base-A.mmdb

swap-b: ## Activate base-B with a FRESH mtime (normal scenario)
	./swap-fresh-mtime.sh db/base-B.mmdb

swap-a-preserve: ## Activate base-A PRESERVING mtime (production scenario)
	./swap-preserve-mtime.sh db/base-A.mmdb

swap-b-preserve: ## Activate base-B PRESERVING mtime (production scenario)
	./swap-preserve-mtime.sh db/base-B.mmdb

## --- testing -----------------------------------------------------------------

test: ## Run the staged reload test (preserved-mtime scenario)
	./test-reload.sh

curl-a: ## Query nginx-a with IP: make curl-a IP=8.8.8.8
	@curl -s -H "X-Test-IP: $(IP)" http://localhost:8080/geoip; echo

curl-b: ## Query nginx-b with IP: make curl-b IP=8.8.8.8
	@curl -s -H "X-Test-IP: $(IP)" http://localhost:8081/geoip; echo

clean: down ## Stop containers and remove built images
	-docker rmi ngx-geoip2-lab:latest
