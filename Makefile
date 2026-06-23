PROJECT_NAME := runit-maps

# Detect OS for protoc
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
ifeq ($(UNAME_S),Windows)
PROTOC ?= $(USERPROFILE)\.protoc\bin\protoc.exe
else
PROTOC ?= $(HOME)/.protoc/bin/protoc
endif

export PROTOC

.PHONY: all build test lint run release clean proto docs check

all: build

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

## Run the server (serve subcommand)
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
