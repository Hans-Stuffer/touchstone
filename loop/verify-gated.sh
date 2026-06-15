#!/usr/bin/env bash
# Verifier-gated code loop: generate, verify, repair on the counterexample, repeat
# until the verifier passes or the budget runs out. This is the "generate then
# verify" move from the docs made mechanical: the model proposes, an exact check
# disposes, and the failure is fed back as the next instruction.
#
# Usage:
#   loop/verify-gated.sh <task_prompt_file> "<verifier_cmd with {OUT}>" <out_file> [max_iters]
#
# The verifier command must exit 0 when <out_file> satisfies the spec, and nonzero
# (printing a counterexample / reason to stdout or stderr) otherwise. Use the token
# {OUT} where the candidate file path should go.
#
# Example, wired to the touchstone eval grader:
#   loop/verify-gated.sh /tmp/task.md \
#     "python3 eval/grade.py eval/tasks/cart-merge-py.json {OUT}" /tmp/sol.py 5
#
# It uses the `claude` CLI (your subscription), so it needs no API key. Each
# iteration spends a little quota; keep max_iters small. For parallel best-of-N
# instead of iterative repair, run several of these and keep the first that passes.
set -uo pipefail

TASK="${1:?task prompt file}"
VCMD="${2:?verifier command (use {OUT} for the candidate path)}"
OUT="${3:?output file for the candidate}"
MAX="${4:-5}"

command -v claude >/dev/null 2>&1 || { echo "need the claude CLI on PATH"; exit 2; }
[ -f "$TASK" ] || { echo "task prompt file not found: $TASK"; exit 2; }

prompt="$(cat "$TASK")"
feedback=""

for i in $(seq 1 "$MAX"); do
  echo "== iteration $i/$MAX ==" >&2

  ask="$prompt

Write ONLY the implementation that satisfies this. No prose, no explanation, no markdown code fences."
  if [ -n "$feedback" ]; then
    ask="$ask

Your previous attempt FAILED verification with:
$feedback

Fix the specific cause and return the FULL corrected implementation."
  fi

  # generate a candidate with the subscription CLI, then strip any stray fences
  if ! claude -p "$ask" >"$OUT.raw" 2>/dev/null; then
    echo "claude -p failed on iteration $i" >&2
    [ "$i" -eq "$MAX" ] && { echo "GAVE UP after $MAX iterations (generation failed)"; exit 1; }
    continue
  fi
  sed -e '/^[[:space:]]*```/d' "$OUT.raw" >"$OUT"

  # verify
  cmd="${VCMD//\{OUT\}/$OUT}"
  if out="$(eval "$cmd" 2>&1)"; then
    echo "$out"
    echo "PASS on iteration $i. Candidate at $OUT"
    rm -f "$OUT.raw"
    exit 0
  fi
  echo "$out" | tail -8 >&2
  feedback="$out"
done

rm -f "$OUT.raw"
echo "GAVE UP after $MAX iterations. Last candidate (still failing) at $OUT"
exit 1
