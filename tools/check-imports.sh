#!/usr/bin/env bash
# Resolve every relative ESM import in the extension sources and fail if the
# target file does not exist. The extension has no test suite, and a bad
# relative path only surfaces when gnome-shell tries to load the extension,
# so this is the cheap guard against a broken import after moving files.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

# tests/ and tools/ are standalone gjs scratch scripts on the legacy
# imports.* API, not part of the extension's ESM graph.
mapfile -t files < <(find . -name '*.js' \
  -not -path './build/*' \
  -not -path './node_modules/*' \
  -not -path './tests/*' \
  -not -path './tools/*' | sort)

failed=0
checked=0

for f in "${files[@]}"; do
  dir=$(dirname "$f")
  while read -r spec; do
    [ -z "$spec" ] && continue
    checked=$((checked + 1))
    if [ ! -f "$dir/$spec" ]; then
      echo "$f: unresolved import '$spec'"
      failed=$((failed + 1))
    fi
  done < <(grep -oE "from '\.\.?/[^']*'" "$f" | sed -E "s/^from '//; s/'\$//")
done

if [ "$failed" -ne 0 ]; then
  echo "check-imports: FAILED ($failed unresolved of $checked)"
  exit 1
fi

echo "check-imports: $checked relative imports, all resolve"
