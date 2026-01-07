#!/bin/bash
# Post-edit Swift lint hook for Claude Code
# Lints Swift files after editing
# Returns exit code 2 to report error, 0 on success

set -e

# Read stdin to get tool input
INPUT=$(cat)

# Extract the file path from the JSON input
FILE_PATH=$(echo "$INPUT" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('tool_input', {}).get('file_path', ''))" 2>/dev/null || echo "")

# Only check Swift files
if [[ "$FILE_PATH" == *.swift ]]; then
    cd "$CLAUDE_PROJECT_DIR" || exit 0

    # Check if swiftlint is available
    if ! command -v swiftlint &> /dev/null; then
        exit 0
    fi

    # Run swiftlint on the specific file (positional arg, not --path which is deprecated)
    if ! swiftlint lint "$FILE_PATH" --quiet --strict 2>/dev/null; then
        echo "SwiftLint violations in $FILE_PATH. Fix before committing." >&2
        exit 2
    fi
fi

exit 0
