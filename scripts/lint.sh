#!/bin/bash
set -e
echo "Running SwiftLint..."

# Check if swiftlint is available
if ! command -v swiftlint &> /dev/null; then
    echo "WARNING: SwiftLint not installed"
    if [ "${SKIP_LINT_IF_UNAVAILABLE:-false}" = "true" ]; then
        echo "SKIP_LINT_IF_UNAVAILABLE=true, skipping lint check"
        exit 0
    else
        echo "Install SwiftLint with: brew install swiftlint"
        echo "Or set SKIP_LINT_IF_UNAVAILABLE=true to skip"
        exit 1
    fi
fi

swiftlint lint --strict
echo "Code passes linting"
