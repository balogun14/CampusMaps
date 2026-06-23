PROJECT_NAME := runit-maps
COMPOSE := docker compose

# Detect OS for protoc
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
ifeq ($(UNAME_S),Windows)
PROTOC ?= $(USERPROFILE)\.protoc\bin\protoc.exe
else
PROTOC ?= $(HOME)/.protoc/bin/protoc
endif

export PROTOC

.PHONY: all build test lint run release clean proto docs check
.PHONY: up down restart logs ps rebuild-tiles build-valhalla build-service

all: build

# ========================
# Rust development
# ========================

## Build (debug)
build:
	cargo build

## Run all tests
test:
	cargo test

## Lint with clippy
lint:
	cargo clippy -- -D warnings

## Format code
fmt:
	cargo fmt

## Run the server locally (serve subcommand)
run:
	cargo run -- serve

## Build release binary
release:
	cargo build --release

## Clean build artifacts
clean:
	cargo clean

## Regenerate protobuf stubs (requires protoc)
proto:
	cargo build

## Open rustdoc
docs:
	cargo doc --open --no-deps

## Full CI check: format + lint + test + build
check: fmt lint test build
	@echo "All checks passed."

# ========================
# Docker Compose
# ========================

## Start all services (Valhalla + routing-service)
up:
	$(COMPOSE) up -d

## Stop all services
down:
	$(COMPOSE) down

## Restart all services
restart: down up

## Tail logs
logs:
	$(COMPOSE) logs -f

## List service status
ps:
	$(COMPOSE) ps

## Build all Docker images
build-docker:
	$(COMPOSE) build

## Build only the Valhalla image
build-valhalla:
	$(COMPOSE) build valhalla

## Build only the Rust service image
build-service:
	$(COMPOSE) build routing-service

## Run one-shot tile build (requires Valhalla running)
rebuild-tiles:
	$(COMPOSE) --profile build run --rm tile-builder

## Full deploy: build images, start services, build tiles
deploy: build-docker up rebuild-tiles
	@echo "Deploy complete."
