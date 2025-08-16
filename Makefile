# Automatically pick docker or podman for compose commands
COMPOSE ?=
ifeq ($(COMPOSE),)
  ifeq (, $(shell which docker 2>/dev/null))
    COMPOSE := podman compose
  else
    COMPOSE := docker compose
  endif
endif

ENV_FILE ?= .env

.PHONY: compose-config up down ps logs
compose-config:
	$(COMPOSE) --env-file $(ENV_FILE) config

up:
	$(COMPOSE) --env-file $(ENV_FILE) up -d

down:
	$(COMPOSE) --env-file $(ENV_FILE) down --remove-orphans

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200