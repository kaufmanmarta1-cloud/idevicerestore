#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/run_with_deps.sh package/usr/local bin/idevicerestore --args...
PREFIX="${1:-package/usr/local}"
shift || true
BINARY_REL="${1:-bin/idevicerestore}"
shift || true

BINARY="$PREFIX/$BINARY_REL"
LIBDIR="$PREFIX/lib"

if [ ! -x "$BINARY" ]; then
  echo "Binary not found or not executable: $BINARY"
  exit 2
fi

export DYLD_LIBRARY_PATH="$LIBDIR:${DYLD_LIBRARY_PATH:-}"
echo "Running $BINARY with DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH"
exec "$BINARY" "$@"
