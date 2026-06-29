#!/usr/bin/env bash
set -euo pipefail

# Виклик: ./scripts/fix_install_names.sh /path/to/staging_prefix
# Наприклад: ./scripts/fix_install_names.sh package/usr/local

PREFIX="${1:-package/usr/local}"
LIB_DIR="$PREFIX/lib"
BIN_DIR="$PREFIX/bin"

if [ ! -d "$PREFIX" ]; then
  echo "Prefix '$PREFIX' not found"
  exit 1
fi

echo "Fixing dylib ids in $LIB_DIR"
for dylib in "$LIB_DIR"/*.dylib; do
  [ -e "$dylib" ] || continue
  name="$(basename "$dylib")"
  echo "  set id: $dylib -> @rpath/$name"
  install_name_tool -id "@rpath/$name" "$dylib"
done

# targets: binaries and dylibs (they may hold references)
targets=()
if [ -d "$BIN_DIR" ]; then
  for f in "$BIN_DIR"/*; do
    [ -e "$f" ] || continue
    targets+=("$f")
  done
fi
for f in "$LIB_DIR"/*.dylib; do
  [ -e "$f" ] || continue
  targets+=("$f")
done

echo "Processing targets to rewrite referenced library paths and add rpath"
for target in "${targets[@]}"; do
  echo "-> $target"
  # list dependencies (skip first line)
  otool -L "$target" | tail -n +2 | awk '{print $1}' | while read -r lib; do
    [ -z "$lib" ] && continue
    # Skip system libs
    case "$lib" in
      /usr/lib/*|/System/*)
        # keep system libraries as is
        ;;
      *)
        base="$(basename "$lib")"
        # If already @rpath or @loader_path or @executable_path, skip
        case "$lib" in
          @rpath/*|@loader_path/*|@executable_path/*)
            ;;
          *)
            echo "   changing $lib -> @rpath/$base"
            install_name_tool -change "$lib" "@rpath/$base" "$target" || true
            ;;
        esac
        ;;
    esac
  done

  # add rpath so that @rpath resolves to executable's ../lib
  # only add if not already present
  if ! otool -l "$target" | grep -q '@executable_path/../lib'; then
    echo "   adding rpath @executable_path/../lib"
    install_name_tool -add_rpath "@executable_path/../lib" "$target" 2>/dev/null || true
  else
    echo "   rpath already present"
  fi
done

echo "Done. Verify with: otool -L <binary> or <dylib>"
