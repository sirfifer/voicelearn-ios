#!/bin/bash
#
# lint-python.sh - Python code quality checks
#
# Runs the same checks as CI to ensure local/CI parity:
# - ruff: Fast Python linter (replaces flake8, isort, etc.)
# - bandit: Security vulnerability scanner
#
# Usage:
#   ./scripts/lint-python.sh           # Lint all Python files
#   ./scripts/lint-python.sh --fix     # Auto-fix issues where possible
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

FIX_MODE=false
if [ "$1" = "--fix" ]; then
    FIX_MODE=true
fi

ERRORS=0

# Check for ruff
if ! command -v ruff &> /dev/null; then
    log_warn "ruff not installed. Install with: pip install ruff"
    log_warn "Skipping Python lint check"
else
    log_info "Running ruff linter on server/..."
    if [ "$FIX_MODE" = true ]; then
        ruff check server/ --fix || ERRORS=$((ERRORS + 1))
    else
        ruff check server/ || ERRORS=$((ERRORS + 1))
    fi
fi

# Check for bandit
if ! command -v bandit &> /dev/null; then
    log_warn "bandit not installed. Install with: pip install bandit"
    log_warn "Skipping security scan"
else
    log_info "Running bandit security scan on server/..."
    # Medium and high severity only, skip tests
    bandit -r server/ -ll --exclude "*/tests/*" -q || ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
    log_info "Python lint checks passed"
    exit 0
else
    log_error "Python lint checks failed"
    exit 1
fi
