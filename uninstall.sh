#!/usr/bin/env bash
# touchstone uninstaller. Usage: ./uninstall.sh [--purge]
set -uo pipefail

TOUCHSTONE_HOME="${TOUCHSTONE_HOME:-$HOME/.touchstone}"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

for s in chiasmus semgrep sympy mcp-solver; do
  if claude mcp remove -s user "$s" >/dev/null 2>&1; then echo "unwired $s"; fi
done

rm -rf "$HOME/.claude/skills/touchstone" && echo "removed skill"
rm -f  "$HOME/.local/bin/minizinc"  2>/dev/null || true
rm -rf "$TOUCHSTONE_HOME" && echo "removed $TOUCHSTONE_HOME"

if [ "$PURGE" = 1 ]; then
  npm remove -g chiasmus >/dev/null 2>&1 || true
  uv tool uninstall semgrep crosshair-tool ruff pyright >/dev/null 2>&1 || true
  echo "purged global tools (chiasmus, semgrep, crosshair, ruff, pyright)"
fi

echo "done. restart Claude Code."
