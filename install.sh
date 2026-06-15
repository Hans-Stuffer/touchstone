#!/usr/bin/env bash
# rigor installer: wires a neurosymbolic toolkit into Claude Code.
# Usage: ./install.sh [--minimal] [--no-minizinc]
set -uo pipefail

RIGOR_HOME="${RIGOR_HOME:-$HOME/.rigor}"
SERVERS="$RIGOR_HOME/servers"
MZ_VERSION="${MZ_VERSION:-2.9.7}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$HERE/skills/rigor"
SKILL_DST="$HOME/.claude/skills/rigor"
WANT_MINIZINC=1
MINIMAL=0

for arg in "$@"; do
  case "$arg" in
    --no-minizinc) WANT_MINIZINC=0 ;;
    --minimal)     MINIMAL=1; WANT_MINIZINC=0 ;;
    -h|--help)     echo "usage: ./install.sh [--minimal] [--no-minizinc]"; exit 0 ;;
    *)             echo "unknown flag: $arg"; exit 1 ;;
  esac
done

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { printf '   \033[32mok\033[0m  %s\n' "$*"; }
warn() { printf '   \033[33m!!\033[0m  %s\n' "$*"; }
die()  { printf '\n\033[31mxx %s\033[0m\n' "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

wire() { # wire <name> <cmd> [args...]
  local name="$1"; shift
  claude mcp remove -s user "$name" >/dev/null 2>&1 || true
  if claude mcp add -s user "$name" -- "$@" >/dev/null 2>&1; then ok "wired $name"; else warn "could not wire $name"; fi
}

say "checking prerequisites"
have claude || die "claude CLI not found. Install Claude Code first."
have git    || die "git not found."
have uv     || die "uv not found. Install it from https://docs.astral.sh/uv then re-run."
have node   || warn "node not found. Chiasmus needs it (https://nodejs.org)."
have npm    || warn "npm not found. Chiasmus needs it."
have curl   || warn "curl not found. MiniZinc auto-download will be skipped."
ok "core tools present"
mkdir -p "$SERVERS" "$HOME/.local/bin"

# Chiasmus: Z3 + Prolog + tree-sitter code graph.
# Global install on purpose: its native better-sqlite3 binding does not build under `npx -y`.
say "Chiasmus (Z3 + Prolog + code graph)"
if have npm; then
  if npm install -g chiasmus >/dev/null 2>&1; then ok "installed chiasmus"; else warn "npm install -g chiasmus failed"; fi
  if have chiasmus; then wire chiasmus chiasmus; else warn "chiasmus not on PATH after install"; fi
else
  warn "skipping chiasmus (needs npm)"
fi

say "CLI verifiers (crosshair, ruff, pyright)"
uv tool install crosshair-tool >/dev/null 2>&1 && ok "crosshair" || warn "crosshair install failed"
uv tool install ruff           >/dev/null 2>&1 && ok "ruff"      || warn "ruff install failed"
uv tool install pyright        >/dev/null 2>&1 && ok "pyright"   || warn "pyright install failed"

if [ "$MINIMAL" = 0 ]; then
  say "Semgrep (SAST)"
  uv tool install semgrep >/dev/null 2>&1 && ok "installed semgrep" || warn "semgrep install failed"
  if have semgrep; then wire semgrep semgrep mcp; else warn "semgrep not on PATH"; fi

  say "sympy-mcp (exact symbolic math)"
  if [ -d "$SERVERS/sympy-mcp/.git" ]; then git -C "$SERVERS/sympy-mcp" pull -q || true
  else git clone --depth 1 https://github.com/sdiehl/sympy-mcp "$SERVERS/sympy-mcp" >/dev/null 2>&1 && ok "cloned" || warn "clone failed"; fi
  # pre-warm so the first health check connects instead of timing out on a cold uv cache
  timeout 240 uv run --with "mcp[cli]" --with sympy --with pydantic mcp run "$SERVERS/sympy-mcp/server.py" </dev/null >/dev/null 2>&1 || true
  wire sympy uv run --with "mcp[cli]" --with sympy --with pydantic mcp run "$SERVERS/sympy-mcp/server.py"

  say "mcp-solver (constraint + optimization)"
  if [ -d "$SERVERS/mcp-solver/.git" ]; then git -C "$SERVERS/mcp-solver" pull -q || true
  else git clone --depth 1 https://github.com/szeider/mcp-solver "$SERVERS/mcp-solver" >/dev/null 2>&1 && ok "cloned" || warn "clone failed"; fi
  uv --directory "$SERVERS/mcp-solver" sync --all-extras >/dev/null 2>&1 && ok "solver backends installed" || warn "mcp-solver sync failed"

  if [ "$WANT_MINIZINC" = 1 ] && [ -x "$RIGOR_HOME/minizinc/bin/minizinc" ]; then
    ln -sf "$RIGOR_HOME/minizinc/bin/minizinc" "$HOME/.local/bin/minizinc"
    say "MiniZinc already installed"; ok "reusing $RIGOR_HOME/minizinc"
  elif [ "$WANT_MINIZINC" = 1 ] && have curl; then
    say "MiniZinc $MZ_VERSION (Gecode + Chuffed CP solvers)"
    os="$(uname -s)"; arch="$(uname -m)"; bundle=""
    case "$os-$arch" in
      Linux-x86_64) bundle="MiniZincIDE-$MZ_VERSION-bundle-linux-x86_64.tgz" ;;
      Darwin-*)     warn "macOS: install MiniZinc from minizinc.org, then re-run" ;;
      *)            warn "no auto-bundle for $os-$arch; install MiniZinc manually" ;;
    esac
    if [ -n "$bundle" ]; then
      if curl -fsSL "https://github.com/MiniZinc/MiniZincIDE/releases/download/$MZ_VERSION/$bundle" -o "$RIGOR_HOME/mz.tgz"; then
        mkdir -p "$RIGOR_HOME/minizinc"
        tar -xzf "$RIGOR_HOME/mz.tgz" -C "$RIGOR_HOME/minizinc" --strip-components=1
        rm -f "$RIGOR_HOME/mz.tgz"
        ln -sf "$RIGOR_HOME/minizinc/bin/minizinc" "$HOME/.local/bin/minizinc"
        ok "minizinc installed"
      else
        warn "MiniZinc download failed; wiring mcp-solver without CP"
      fi
    fi
  fi

  if [ -x "$HOME/.local/bin/minizinc" ] || have minizinc; then
    wire mcp-solver uv --directory "$SERVERS/mcp-solver" run mcp-solver-mzn
  else
    warn "no minizinc found; wiring mcp-solver in ASP mode (no native dependency)"
    wire mcp-solver uv --directory "$SERVERS/mcp-solver" run mcp-solver-asp
  fi
fi

say "routing skill"
mkdir -p "$HOME/.claude/skills"
rm -rf "$SKILL_DST"
cp -r "$SKILL_SRC" "$SKILL_DST" && ok "installed skill to ${SKILL_DST/#$HOME/~}" || warn "skill copy failed"

say "done"
echo "Servers now in your user config (restart Claude Code to load them):"
claude mcp list 2>/dev/null | grep -vE '^Checking' || true
echo
echo "Restart Claude Code, then type /rigor to see the routing brain."
if ! printf '%s' "$PATH" | grep -q "$HOME/.local/bin"; then
  echo
  warn "~/.local/bin is not on your PATH. Add it so the CLI tools resolve:"
  echo '   export PATH="$HOME/.local/bin:$PATH"'
fi
