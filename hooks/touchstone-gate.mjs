#!/usr/bin/env node
// touchstone enforcement hook (PostToolUse).
//
// The skill ADVISES model-then-verify; an LLM will skip it and just write code.
// This hook makes the discipline FIRE: right after Claude edits a file that looks
// invariant-bearing, it injects a reminder to name the invariant and verify it
// with the matching engine before moving on.
//
// It is deliberately CONSERVATIVE. A retro-eval on a real codebase showed the
// engines only help on a narrow seam (merge/convergence, idempotency, pricing and
// bounds, state machines, serialization round-trips, authorization). Firing
// anywhere else is noise, so this matches only that seam and stays silent otherwise.
//
// Wire it up (opt-in) in ~/.claude/settings.json or a project .claude/settings.json:
//   {
//     "hooks": {
//       "PostToolUse": [
//         { "matcher": "Edit|Write|MultiEdit|NotebookEdit",
//           "hooks": [ { "type": "command",
//                        "command": "node /ABSOLUTE/PATH/touchstone/hooks/touchstone-gate.mjs" } ] }
//       ]
//     }
//   }
//
// Tunables (env): TOUCHSTONE_HOOK_PATTERNS = extra |-separated regex fragments to match.
//                 TOUCHSTONE_HOOK_OFF = 1 to disable without editing settings.

import process from "node:process";

function readStdin() {
  return new Promise((resolve) => {
    let buf = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (c) => (buf += c));
    process.stdin.on("end", () => resolve(buf));
    setTimeout(() => resolve(buf), 1000); // never hang the session
  });
}

// the seam where exact engines actually earn their keep
const SEAM = [
  "merge", "reconcile", "resolv", "sync", "crdt",
  "price", "pricing", "discount", "promo", "coupon", "tax", "prorat", "billing", "charge", "refund", "invoice", "ledger",
  "idempoten", "webhook", "retry", "dedupe", "dedup",
  "state[-_ ]?machine", "transition", "lifecycle", "status",
  "serial", "deserial", "encode", "decode", "parse", "marshal", "roundtrip",
  "auth", "permission", "rbac", "acl", "access[-_ ]?control", "entitlement",
];

function main(raw) {
  if (process.env.TOUCHSTONE_HOOK_OFF === "1") return ok();
  let payload = {};
  try { payload = JSON.parse(raw || "{}"); } catch { return ok(); }

  const tool = payload.tool_name || "";
  if (!/^(Edit|Write|MultiEdit|NotebookEdit)$/.test(tool)) return ok();

  const ti = payload.tool_input || {};
  const path = ti.file_path || ti.notebook_path || "";
  if (!path) return ok();

  const extra = (process.env.TOUCHSTONE_HOOK_PATTERNS || "").split("|").filter(Boolean);
  const re = new RegExp([...SEAM, ...extra].join("|"), "i");
  if (!re.test(path)) return ok(); // not on the seam: stay silent

  const note =
    `touchstone: you just edited \`${path.split("/").pop()}\`, which is on the invariant-bearing seam ` +
    `(merge/idempotency/pricing/state-machine/serialization/authz). Before you finish: name the one ` +
    `invariant this code must hold, then VERIFY it with the matching engine (Z3 for "for all inputs", ` +
    `CrossHair or Hypothesis for Python, fast-check for JS/TS), and say plainly what you proved. ` +
    `If, on reflection, this change carries no checkable invariant, ignore this and move on.`;

  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: note },
  }));
  process.exit(0);
}

function ok() { process.exit(0); }

readStdin().then(main).catch(ok);
