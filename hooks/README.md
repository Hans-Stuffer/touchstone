# The enforcement hook

The skill *advises* model-then-verify. An LLM will read that and then just write code anyway. This hook makes the discipline *fire*: right after Claude edits a file that sits on the invariant-bearing seam, it injects a reminder to name the invariant and verify it before moving on.

It is deliberately conservative. A retro-eval on a real production codebase found the exact engines only help on a narrow seam (merge and convergence, idempotency, pricing and bounds, state machines, serialization round-trips, authorization). Firing anywhere else is noise, so the hook matches only that seam, by filename, and stays silent otherwise. That keeps it honest: it nudges where touchstone earns its keep and shuts up where it does not.

## Enable it (opt-in)

Hooks run on every session, so this is not wired by the installer. Add it yourself, in `~/.claude/settings.json` (all projects) or a project `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          { "type": "command", "command": "node /ABSOLUTE/PATH/touchstone/hooks/touchstone-gate.mjs" }
        ]
      }
    ]
  }
}
```

Replace the path with your clone location. The hook reads the tool payload on stdin, checks the edited file's name against the seam, and either injects a one-line reminder (`additionalContext`) or exits silently.

## Tuning

- `TOUCHSTONE_HOOK_PATTERNS`: extra `|`-separated regex fragments to add to the seam (e.g. your own high-stakes module names).
- `TOUCHSTONE_HOOK_OFF=1`: disable without editing settings.

## Stricter variants

The default is a nudge, which is usually enough. If you want a hard gate, two options:

- Switch the script's output to `{"decision":"block","reason":"..."}` so the edit is held until Claude acknowledges the verification step.
- Use a `Stop` hook instead of `PostToolUse` to gate the *end* of a turn ("you touched the seam and never ran a verifier") rather than each edit.

Both are more invasive. Start with the nudge and only escalate if the discipline still gets skipped.
