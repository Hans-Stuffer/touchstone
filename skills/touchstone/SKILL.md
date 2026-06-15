---
name: touchstone
description: Prove the design before you write the code. When a problem carries a real invariant (a merge or sync, money or pricing, a state machine, idempotency, serialization, authorization, an algorithm, an equivalence, a constraint problem), FIRST model the operation and prove its laws on the abstract design with an exact engine, THEN implement and verify the code matches. Routes to Z3, SymPy, MiniZinc, Prolog, CrossHair, fast-check, Semgrep. Use at design time on the invariant-bearing seam, not as an afterthought.
trigger: /touchstone
---

# touchstone: prove the design before you write it

The move this skill enforces is the one good engineers make and the rest skip. When a problem carries a real invariant, you do not write the code and check it afterward. You find the structure first, prove the law on the abstract design, and then the code is a transcription you verify against the model. Catching a design flaw before code is the cheapest catch there is. Catching it in a test run is the most expensive, and most real bugs are already baked in by the time code exists.

This applies to the invariant-bearing seam, and only there: merges and sync, money and pricing, state machines, idempotency, serialization, authorization, algorithms, equivalence, constraints. Most code is glue with no invariant. For that, skip all of this and use tests and a reviewer.

## Step 1: find the algebra, before any code

Match the problem to a structure and name the laws it must obey.

| The problem is about | It must be a | Laws to prove |
|---|---|---|
| merge / sync / reconcile | semilattice join | commutative, associative, idempotent, and updates monotone (then convergence is correct by construction) |
| fold / accumulate / reduce | monoid | associative, with an identity |
| precedence / override / "most specific wins" | lattice | a defined winner for every pair |
| dedup / "are these the same" | equivalence relation + normal form | the normal form is idempotent: `norm(norm(x)) = norm(x)` |
| lifecycle / status | state machine | only legal transitions, bad states unreachable |
| schedule / allocate / optimize | constraint model | feasibility and optimality |

If the operation is not the structure it should be, that is the design risk and you just found it. A merge that is first-wins or last-write, a greedy or anchor-relative match, a `count += count` accumulator, a normal form that is not a fixpoint: name the problem now, before it ships.

## Step 2: prove the laws in Z3, on the design, not the code

Encode the abstract operation with `chiasmus_verify` (Z3) and assert the NEGATION of each law. UNSAT proves it holds for every input. SAT hands you the counterexample to fix before you write a line. For a merge, the obligations verbatim:

```
; commutative
(assert (not (= (merge a b) (merge b a))))                       ; want UNSAT
; associative
(assert (not (= (merge (merge a b) c) (merge a (merge b c)))))   ; want UNSAT
; idempotent
(assert (not (= (merge a a) a)))                                 ; want UNSAT
; updates only add information (monotone)
(assert (not (leq a (update a))))                                ; want UNSAT
```

Model the per-element combine. A pointwise lift of a semilattice over a key-map is still a semilattice, so proving the element combine plus union-of-keys proves the whole merge. Keep the model abstract and small. That is exactly why this is cheaper and more decisive than verifying code: the design is tiny, the code is not. Point Z3 at the usual killers: first-wins or last-write breaks commutativity, greedy or anchor-relative matching breaks associativity, `count += count` breaks idempotence, and a canonicalization that is not a fixpoint breaks every layer above it.

For a state machine, model the transition relation, assert that a bad state is reachable, and want UNSAT. For a fold, prove associativity and the identity. SymPy for exact math, MiniZinc for constraints.

## Step 3: fix the design, then implement, then verify the code matches

If a law failed, change the operation and re-prove until it holds. A deterministic value-merge instead of first-wins. Union-find over the symmetric relation instead of greedy matching. Key or set the counter instead of adding. Only once the design holds do you write the code, as a transcription of the proven design. Then verify the implementation against the same laws with a property test: Hypothesis for Python, fast-check for JavaScript or TypeScript, or CrossHair to hunt a breaking input. That last step is the safety net, not the main event.

## The engines behind the steps

When you need a specific check, this is the toolbox. They are wired into this Claude Code as MCP servers (`chiasmus_*`, `sympy` tools, `semgrep_*`, `mcp-solver`) plus the command-line tools (`crosshair`, `pyright`, `ruff`, `fast-check`, `tsc`, `eslint`).

| You are about to | Reach for | What it buys you |
|---|---|---|
| prove a property or an invariant for all inputs | `chiasmus_verify` (Z3 SMT) | a proof, or a concrete counterexample. not a vibe |
| show a refactor is equivalent | `chiasmus_verify` (assert inputs equal and outputs differ; UNSAT means equivalent) | the exact input where they diverge, if one exists |
| do algebra, calculus, simplification, exact arithmetic | the `sympy` tools (`solve_algebraically`, `integrate_expression`, `simplify_expression`, ...) | you fumble symbolic math and floating point. SymPy does not |
| reason over relations, reachability, conflicting rules | `chiasmus_solve` (Prolog) | transitive closure and logic done correctly |
| schedule, allocate, pack, assign, optimize | `mcp-solver` (`add_item` then `solve_model`) | the optimum under constraints, not a greedy guess |
| find the input that breaks a Python function | `crosshair check` (CLI) | symbolic execution searches its paths within a time budget and hands you the break |
| break a JavaScript or TypeScript function | `fast-check` property (CLI) | random plus shrinking search for the minimal falsifying input |
| confirm two functions agree everywhere | `crosshair diffbehavior` (Python), `fast-check` or a Z3 equivalence (TS) | a disagreeing input, or silence |
| check types, lint, catch bug classes | `pyright`/`ruff` (Python), `tsc`/`eslint` (TS) | cheap and fast. run it every time |
| catch injection, taint, security smells | `semgrep_scan` | thousands of deterministic rules |
| understand call structure, dead code, blast radius | `chiasmus_graph` | a real graph, not grep and hope |

Z3, SymPy, and MiniZinc are language-neutral; they work on the math, not the source language. CrossHair and Hypothesis are Python. fast-check, tsc, and eslint cover JavaScript and TypeScript.

> SymPy is stateful. Declare each variable with `intro` (and its assumptions, like `real`) **before** you introduce an expression that uses it, then solve. Skip that and `solve_algebraically` silently returns the empty set, because the expression's symbol is a different object from the one you solved for.

## Command-line quick reference

```
# prove or break a Python function (give it a timeout, target one function)
uvx --from crosshair-tool crosshair check path/to/mod.py --per_condition_timeout 15

# do two functions ever disagree?
uvx --from crosshair-tool crosshair diffbehavior mypkg.mod.f mypkg.mod.g

# types and lint
pyright --outputjson path/        ;  ruff check --output-format=json path/

# JavaScript / TypeScript: property-test with fast-check, types with tsc, lint with eslint
# (installed under ~/.touchstone/js; in a project use `npm i -D fast-check` and run with tsx)
npx tsx prop.ts                                          # run a fast-check property
~/.touchstone/js/node_modules/.bin/tsc --noEmit file.ts  # type check

# security (prefer the semgrep_scan MCP tool; this is the CLI fallback)
semgrep scan --config auto path/
```

## The rule that keeps you honest

The engine proves your encoding, not your intention. Translate the problem wrong and you get a rigorous answer to the wrong question, which is worse than no answer because it looks trustworthy. After every proof, state in one plain sentence what you actually proved, and check it is what you meant.

Know what each result guarantees. Z3 returning UNSAT over the integers is a real proof for all integer inputs, but Z3 can also answer `unknown` on a hard fragment (nonlinear integer arithmetic, unbounded quantifiers), which settles nothing. MiniZinc OPTIMAL is a true optimum for the model you wrote. CrossHair finding no counterexample is NOT a proof; it explores paths within a time budget. Tests passing is evidence, never certainty.

## Do not solver-everything

Most code is glue. Buttons, routes, CRUD, async plumbing, product logic. None of it has a clean spec, so a prover has nothing to bite on, and forcing it through one is wasted effort and false confidence. On a real codebase the slice that carries a checkable invariant is small. Spend this there: the merge engine, the money math, the state machine, the serializer. Everywhere else, reach for types, lint, tests, and a second reader. If nothing clean fits, say so and stop.

## How to report it

Name the engine and the guarantee. "Z3 proved the merge is commutative and associative for all states." "CrossHair found n = -1 breaks it." "MiniZinc says 42 is optimal." Never launder a solver result into a soft reassurance like "this should be fine." If you did not prove it, say you did not prove it.
