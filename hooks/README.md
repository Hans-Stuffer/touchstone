# The enforcement hooks

The skill advises model-then-verify. An LLM reads that and writes code anyway. These two hooks make the discipline fire, at the two moments it matters.

## touchstone-design-gate.mjs (UserPromptSubmit): the one that matters

Fires when you *ask* for work on the invariant-bearing seam, before any code exists. It injects a reminder to do the design-first move: name the operation and the structure it must be (a merge is a semilattice join; a fold a monoid; a lifecycle a state machine), prove those laws on the abstract design with Z3 first, then implement as a transcription. This is the high-leverage hook, because the cheapest place to catch a design flaw is before it is written, and after-the-fact verification catches only a small fraction of real bugs.

It is conservative. It fires only when the prompt shows both a build intent (implement, build, refactor, design, fix) and a seam topic (merge or sync, pricing or money, a state machine, idempotency, serialization, authorization, constraints). Everything else passes silently.

## touchstone-gate.mjs (PostToolUse): the safety net

Fires right after you edit a file whose name sits on the seam, reminding you to verify the invariant if you have not. This is the backstop for when the design-time nudge was missed.

## Enable them (opt-in)

Add to `~/.claude/settings.json` (all projects) or a project `.claude/settings.json`, replacing the path with your clone:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command",
                     "command": "node /ABSOLUTE/PATH/touchstone/hooks/touchstone-design-gate.mjs", "timeout": 5 } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [ { "type": "command",
                     "command": "node /ABSOLUTE/PATH/touchstone/hooks/touchstone-gate.mjs", "timeout": 5 } ] }
    ]
  }
}
```

If you already have hooks on these events, add these as *additional* entries in the arrays. Do not replace your existing ones.

## Tuning

- `TOUCHSTONE_HOOK_PATTERNS`: extra `|`-separated seam terms (your own high-stakes module names).
- `TOUCHSTONE_HOOK_OFF=1`: disable both without editing settings.

## Why conservative

A retro-analysis of a real production codebase found exact-engine verification helps on a narrow seam and nowhere else. Firing outside it is noise. Both hooks match only that seam, so they nudge where it pays and stay quiet where it does not.
