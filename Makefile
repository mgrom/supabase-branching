.PHONY: build up down restart logs status clean

-include .env
export

IMAGE ?= $(IMAGE_NAME):$(IMAGE_TAG)
COMPOSE := docker compose -f docker-compose.yml

build:
	./build.sh

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart postgres

logs:
	$(COMPOSE) logs -f postgres

status:
	./branch status

clean:
	$(COMPOSE) down -v
	docker rmi $(IMAGE) 2>/dev/null || true
