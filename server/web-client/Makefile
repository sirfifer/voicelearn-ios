# UnaMentis Web Client - Development Makefile
# Common tasks for development workflow

.PHONY: help install dev build start test lint format typecheck clean ci setup

# Default target
help:
	@echo "UnaMentis Web Client - Available Commands"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make install    - Install dependencies with pnpm"
	@echo "  make setup      - Full setup (install + husky)"
	@echo ""
	@echo "Development:"
	@echo "  make dev        - Start development server"
	@echo "  make build      - Create production build"
	@echo "  make start      - Start production server"
	@echo ""
	@echo "Testing:"
	@echo "  make test       - Run unit tests"
	@echo "  make test-watch - Run tests in watch mode"
	@echo "  make test-ui    - Run tests with UI"
	@echo "  make coverage   - Run tests with coverage"
	@echo "  make e2e        - Run E2E tests"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint       - Run ESLint"
	@echo "  make lint-fix   - Run ESLint with auto-fix"
	@echo "  make format     - Format code with Prettier"
	@echo "  make typecheck  - Run TypeScript type checking"
	@echo ""
	@echo "CI/Maintenance:"
	@echo "  make ci         - Run full CI pipeline"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make precommit  - Run pre-commit checks"

# Setup & Installation
install:
	pnpm install

setup: install
	pnpm exec husky install
	@echo "Setup complete!"

# Development
dev:
	pnpm dev

build:
	pnpm build

start:
	pnpm start

# Testing
test:
	pnpm test

test-watch:
	pnpm test:watch

test-ui:
	pnpm test:ui

coverage:
	pnpm test:coverage

e2e:
	pnpm test:e2e

e2e-ui:
	pnpm test:e2e:ui

# Code Quality
lint:
	pnpm lint

lint-fix:
	pnpm lint:fix

format:
	pnpm format

format-check:
	pnpm format:check

typecheck:
	pnpm typecheck

# CI/Maintenance
ci:
	pnpm ci

precommit:
	pnpm precommit

clean:
	pnpm clean

# Combined targets
check: lint typecheck test
	@echo "All checks passed!"

all: clean install ci
	@echo "Full build complete!"
