#!/usr/bin/env bash
# rigor uninstaller. Usage: ./uninstall.sh [--purge]
set -uo pipefail

RIGOR_HOME="${RIGOR_HOME:-$HOME/.rigor}"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

for s in chiasmus semgrep sympy mcp-solver; do
  if claude mcp remove -s user "$s" >/dev/null 2>&1; then echo "unwired $s"; fi
done

rm -rf "$HOME/.claude/skills/rigor" && echo "removed skill"
rm -f  "$HOME/.local/bin/minizinc"  2>/dev/null || true
rm -rf "$RIGOR_HOME" && echo "removed $RIGOR_HOME"

if [ "$PURGE" = 1 ]; then
  npm remove -g chiasmus >/dev/null 2>&1 || true
  uv tool uninstall semgrep crosshair-tool ruff pyright >/dev/null 2>&1 || true
  echo "purged global tools (chiasmus, semgrep, crosshair, ruff, pyright)"
fi

echo "done. restart Claude Code."
