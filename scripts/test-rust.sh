#!/bin/bash
#
# test-rust.sh - Run Rust tests for USM Core
#
# Usage:
#   ./scripts/test-rust.sh              # Run all tests
#   ./scripts/test-rust.sh --release    # Run tests in release mode
#   ./scripts/test-rust.sh --verbose    # Run with verbose output
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$PROJECT_DIR/server/usm-core"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Parse arguments
RELEASE_MODE=false
VERBOSE=false
for arg in "$@"; do
    case $arg in
        --release)
            RELEASE_MODE=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
    esac
done

echo "Running Rust tests for USM Core..."
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}ERROR: Rust/Cargo not installed${NC}"
    echo "Install Rust with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

# Check if project exists
if [ ! -d "$RUST_DIR" ]; then
    echo -e "${RED}ERROR: Rust project not found at $RUST_DIR${NC}"
    exit 1
fi

cd "$RUST_DIR"

# Build test command
TEST_CMD="cargo test"

if [ "$RELEASE_MODE" = true ]; then
    TEST_CMD="$TEST_CMD --release"
    echo "Running in release mode..."
fi

if [ "$VERBOSE" = true ]; then
    TEST_CMD="$TEST_CMD -- --nocapture"
    echo "Running with verbose output..."
fi

echo "Command: $TEST_CMD"
echo ""

# Run tests
if $TEST_CMD; then
    echo ""
    echo -e "${GREEN}All Rust tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some Rust tests failed${NC}"
    exit 1
fi
