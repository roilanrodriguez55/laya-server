.PHONY: help venv install run run-auth health docker-build docker-up docker-up-fg docker-down docker-down-clean docker-logs docker-restart docker-health clean

SHELL := /bin/bash
SERVER_DIR := server
VENV := $(SERVER_DIR)/.venv
HOST ?= 127.0.0.1
PORT ?= 8000
LAYA_API_KEY ?= secret123

help:
	@echo "Local (sin Docker):"
	@echo "  make venv          - crea el entorno virtual en server/.venv"
	@echo "  make install       - instala laya[serve] en el venv"
	@echo "  make run           - corre laya-serve local en $(HOST):$(PORT), sin auth"
	@echo "  make run-auth      - corre laya-serve local con LAYA_API_KEY=$(LAYA_API_KEY)"
	@echo "  make health        - hace curl a http://$(HOST):$(PORT)/health"
	@echo ""
	@echo "Docker (produccion / entorno reproducible):"
	@echo "  make docker-build  - construye la imagen (docker compose build)"
	@echo "  make docker-up     - levanta el contenedor en background"
	@echo "  make docker-up-fg  - levanta el contenedor en primer plano (logs en vivo)"
	@echo "  make docker-down   - baja el contenedor (conserva el cache de checkpoints)"
	@echo "  make docker-down-clean - baja el contenedor y borra el volumen de checkpoints"
	@echo "  make docker-logs   - sigue los logs del contenedor"
	@echo "  make docker-restart- reinicia el contenedor"
	@echo "  make docker-health - hace curl a http://$(HOST):$(PORT)/health"
	@echo ""
	@echo "  make clean         - borra server/.venv"

## --- Local (sin Docker) ---

venv:
	cd $(SERVER_DIR) && python3 -m venv .venv

install: venv
	$(VENV)/bin/pip install -r $(SERVER_DIR)/requirements.txt

run: install
	cd $(SERVER_DIR) && LAYA_HOST=$(HOST) LAYA_PORT=$(PORT) .venv/bin/laya-serve

run-auth: install
	cd $(SERVER_DIR) && LAYA_HOST=$(HOST) LAYA_PORT=$(PORT) LAYA_API_KEY=$(LAYA_API_KEY) .venv/bin/laya-serve

health:
	curl -s http://$(HOST):$(PORT)/health | python3 -m json.tool

## --- Docker ---

docker-build:
	docker compose build

docker-up: docker-build
	docker compose up -d

docker-up-fg: docker-build
	docker compose up

docker-down:
	docker compose down

docker-down-clean:
	docker compose down -v

docker-logs:
	docker compose logs -f

docker-restart:
	docker compose restart

docker-health:
	curl -s http://$(HOST):$(PORT)/health | python3 -m json.tool

## --- Limpieza ---

clean:
	rm -rf $(VENV)
