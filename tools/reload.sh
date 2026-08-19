#!/usr/bin/env bash
# Rebuild, reinstall, and reload the extension in the running shell.
#
# What this can and cannot do:
#   - Settings/schema changes and anything that runs in enable(): picked up by
#     the disable/enable cycle below.
#   - Edited JavaScript: NOT picked up. GNOME Shell 45+ imports extension.js as
#     an ES module and the module stays in the JS module registry for the life
#     of the process, so re-enabling re-runs enable() on the *old* code.
#     Restarting the shell is the only way to re-read the source.
#
# On X11 the shell can be restarted in place, keeping your windows: Alt+F2,
# type r, Enter. On Wayland that is impossible -- use `make test-shell` for a
# nested session, or log out and back in.

set -euo pipefail

UUID="dash2dock-lite@icedman.github.com"
cd "$(dirname "$0")/.."

make install

if ! gnome-extensions info "$UUID" >/dev/null 2>&1; then
  echo "reload: $UUID is not installed for this user" >&2
  exit 1
fi

echo "reload: cycling $UUID"
gnome-extensions disable "$UUID" || true
sleep 1
gnome-extensions enable "$UUID"

state=$(gnome-extensions info "$UUID" | sed -n 's/^ *State: *//p')
echo "reload: state is ${state:-unknown}"

case "${XDG_SESSION_TYPE:-}" in
x11)
  cat <<'EOF'

  JavaScript changes need a shell restart to take effect:

      Alt+F2, type  r , press Enter

  Your windows survive it. Then watch the log with:

      journalctl /usr/bin/gnome-shell -f -o cat
EOF
  ;;
wayland)
  cat <<'EOF'

  You are on Wayland -- the shell cannot be restarted in place.
  For JavaScript changes use a nested session:

      make test-shell

  or log out and back in.
EOF
  ;;
*)
  echo
  echo "  Unknown session type; restart the shell to pick up JavaScript changes."
  ;;
esac
