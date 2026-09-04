#!/usr/bin/env bash
# Run on a teammate laptop (or the operator laptop). Installs SSH config for glm-flash.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/configs/ssh/glm-flash"
DEST_DIR="${HOME}/.ssh/config.d"
DEST="$DEST_DIR/glm-flash"
CONFIG="${HOME}/.ssh/config"
INCLUDE_LINE='Include ~/.ssh/config.d/glm-flash'

umask 077
install -d -m 700 "$HOME/.ssh" "$DEST_DIR"
install -m 600 "$SRC" "$DEST"

if [[ ! -f "$CONFIG" ]]; then
  printf '%s\n' "$INCLUDE_LINE" >"$CONFIG"
  chmod 600 "$CONFIG"
  echo "created $CONFIG"
elif grep -Fqx "$INCLUDE_LINE" "$CONFIG"; then
  echo "ssh config already includes glm-flash"
else
  tmp="$(mktemp)"
  if grep -Fq 'Include ~/.orbstack/ssh/config' "$CONFIG"; then
    python3 - "$CONFIG" "$INCLUDE_LINE" "$tmp" <<'PY'
from pathlib import Path
import sys
src, line, dest = sys.argv[1], sys.argv[2], sys.argv[3]
text = Path(src).read_text()
needle = "Include ~/.orbstack/ssh/config\n"
if needle in text:
    text = text.replace(needle, needle + "\n" + line + "\n", 1)
else:
    text = line + "\n\n" + text
Path(dest).write_text(text)
PY
  else
    printf '%s\n\n' "$INCLUDE_LINE" >"$tmp"
    cat "$CONFIG" >>"$tmp"
  fi
  mv "$tmp" "$CONFIG"
  chmod 600 "$CONFIG"
  echo "added Include to $CONFIG"
fi

echo "Host glm-flash → LocalForward 18000 and 18428. Next: scripts/glm-up.sh"
if ! command -v tailscale >/dev/null 2>&1; then
  echo "install Tailscale from https://tailscale.com/download then log in" >&2
fi
