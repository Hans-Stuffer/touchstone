#!/usr/bin/env node
// touchstone DESIGN-TIME hook (UserPromptSubmit).
//
// The other hook (touchstone-gate.mjs, PostToolUse) fires AFTER you edit code.
// That is too late for the move that matters: modeling and proving the design
// BEFORE writing it. This hook fires at the moment of intent. When you ask for
// work that sits on the invariant-bearing seam, it injects a reminder to find
// the algebra and prove the laws first, so design-first is in front of the model
// when it picks up the task, not after it has already coded the wrong design.
//
// Conservative by construction: it fires only when the prompt shows BOTH a build
// intent (implement/build/write/refactor/design/fix) AND a seam topic
// (merge/sync, pricing/money, state machine, idempotency, serialization, authz).
// Anything else passes silently.
//
// Wire it up (opt-in) in ~/.claude/settings.json or a project .claude/settings.json:
//   { "hooks": { "UserPromptSubmit": [
//       { "hooks": [ { "type": "command",
//                      "command": "node /ABSOLUTE/PATH/touchstone/hooks/touchstone-design-gate.mjs" } ] }
//   ] } }
//
// Env: TOUCHSTONE_HOOK_OFF=1 disables it. TOUCHSTONE_HOOK_PATTERNS adds |-separated seam terms.

import process from "node:process";

function readStdin() {
  return new Promise((resolve) => {
    let buf = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (c) => (buf += c));
    process.stdin.on("end", () => resolve(buf));
    setTimeout(() => resolve(buf), 1000);
  });
}

const BUILD = /\b(implement|build|writ(e|ing)|add|creat(e|ing)|refactor|rewrite|design|fix|change|update|handle)\b/i;

const SEAM = [
  "merge", "reconcile", "sync", "converge", "crdt", "dedup", "dedupe",
  "price", "pricing", "discount", "promo", "coupon", "tax", "prorat", "billing", "charge", "refund", "invoice", "ledger", "money",
  "idempoten", "webhook", "retry",
  "state machine", "state-machine", "transition", "lifecycle", "status",
  "serial", "deserial", "encode", "decode", "parse", "marshal", "round[- ]?trip", "schema migration",
  "auth", "permission", "rbac", "acl", "access control", "entitlement",
  "schedule", "allocat", "assignment", "constraint", "optimi", "invariant",
];

function ok() { process.exit(0); }

function main(raw) {
  if (process.env.TOUCHSTONE_HOOK_OFF === "1") return ok();
  let payload = {};
  try { payload = JSON.parse(raw || "{}"); } catch { return ok(); }

  const text = payload.prompt || payload.user_prompt || "";
  if (!text || text.length > 8000) return ok(); // skip empties and huge pastes

  const extra = (process.env.TOUCHSTONE_HOOK_PATTERNS || "").split("|").filter(Boolean);
  const seam = new RegExp([...SEAM, ...extra].join("|"), "i");
  if (!BUILD.test(text) || !seam.test(text)) return ok(); // not seam-building work: stay silent

  const note =
    "touchstone (design-first): this looks like work on the invariant-bearing seam. " +
    "Before writing code, do the senior move. (1) Name the operation and the structure it must be: " +
    "a merge is a semilattice join (commutative, associative, idempotent); a fold is a monoid; a lifecycle " +
    "is a legal-transition state machine; a normal form must be idempotent. (2) PROVE those laws on the " +
    "abstract design with Z3 via chiasmus_verify (assert the negation of each law; UNSAT proves it, SAT is your " +
    "counterexample) BEFORE implementing. Watch the killers: first-wins/last-write breaks commutativity, " +
    "greedy matching breaks associativity, count += count breaks idempotence. (3) Fix the design if a law " +
    "fails, then write the code as a transcription and verify it against the same laws (fast-check for JS/TS, " +
    "Hypothesis or CrossHair for Python). If this carries no checkable invariant, ignore this and proceed.";

  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: note },
  }));
  process.exit(0);
}

readStdin().then(main).catch(ok);
