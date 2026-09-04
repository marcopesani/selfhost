#!/usr/bin/env bash
# Deprecated name — same as overlay.sh (ADR-028).
exec "$(cd "$(dirname "$0")" && pwd)/overlay.sh" "$@"
