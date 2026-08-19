#!/usr/bin/env bash
# Show how this fork stands against upstream icedman/dash2dock-lite.
#
#   -  patch is already upstream (same patch-id) -> will drop on next rebase
#   +  patch is still ours to carry
set -euo pipefail

cd "$(dirname "$0")/.."

git remote get-url upstream >/dev/null 2>&1 || {
  echo "no 'upstream' remote; run:" >&2
  echo "  git remote add upstream https://github.com/icedman/dash2dock-lite.git" >&2
  exit 1
}

git fetch --quiet upstream

behind=$(git rev-list --count main..upstream/main)
ahead=$(git rev-list --count upstream/main..main)

echo "upstream/main  $(git log -1 --format='%h %ad %s' --date=short upstream/main)"
echo "main           ${ahead} patch(es) ahead, ${behind} commit(s) behind"
echo

git cherry -v upstream/main main | while read -r mark sha subject; do
  case "$mark" in
    -) echo "  LANDED   ${sha:0:9} ${subject}" ;;
    +) echo "  carried  ${sha:0:9} ${subject}" ;;
  esac
done

if [ "$behind" -gt 0 ]; then
  echo
  echo "upstream moved. to catch up:"
  echo "  git rebase upstream/main"
  echo "  (test, then) git push --force-with-lease origin main"
fi
