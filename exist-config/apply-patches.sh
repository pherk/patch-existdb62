#!/bin/bash

# Usage
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <Target directory (eXist config etc.)> [--apply] (default is dry run)"
  exit 1
fi

# Target directory
TARGET_DIR="$1"

# Get absolute path to the directory where the script is running
SCRIPT_DIR="$(pwd)"

# Apply flag
APPLY=""
if [ "$#" -gt 1 ] && [ "$2" == "--apply" ]; then
  APPLY="--apply"
fi

# Patch operation
if [ -z "$APPLY" ]; then
  echo "Running test to see if patches apply."
  find ./patches/ -name "*.patch" -exec sh -c "cd \"$TARGET_DIR\" && patch --dry-run -p1 < \"$SCRIPT_DIR/{}\" && cd -" \;
else
  echo "Applying patches."
  find ./patches/ -name "*.patch" -exec sh -c "cd \"$TARGET_DIR\" && patch -p1 < \"$SCRIPT_DIR/{}\" && cd -" \;
fi
