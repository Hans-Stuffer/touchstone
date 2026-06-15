---
name: touchstone
description: Neurosymbolic modeling-and-verification toolkit. FIRST find the structure in a problem (the algebra: monoid, semilattice/CRDT, lattice, equivalence relation, constraint system, state machine), THEN verify it with an exact engine. Use when correctness matters: modeling a gnarly domain problem, proving a property or invariant, checking two implementations are equivalent, exact math, solving a constraint or optimization problem, hunting counterexamples, or a security pass. Routes to an exact engine (Z3, SymPy, MiniZinc, Prolog, CrossHair, Semgrep) instead of guessing.
trigger: /touchstone
---

# touchstone: stop guessing, start proving

You write good code and you are bad at being sure it is correct. These tools close that gap. The division of labor is simple: you translate and generate, the engines prove and solve. When a sub-problem has an exact answer, hand it to the thing that computes exact answers instead of reasoning it out in your head.

The engines are wired into this Claude Code as MCP servers (`chiasmus_*`, `sympy` tools, `semgrep_*`, `mcp-solver` model tools) plus three command-line tools (`crosshair`, `pyright`, `ruff`). They are always available. Your job is two things: find the structure first, then pick the engine that proves it.

## Model before you reach for a tool

Before writing code for a non-trivial domain problem, find the structure. Most messes are one of a few shapes wearing a costume. Spend thirty seconds matching the problem to a structure, because the structure tells you which laws to prove.

| If the problem is about | It probably wants to be a | Which hands you |
|---|---|---|
| combining, merging, reconciling, syncing views | semilattice / CRDT | order independence: commutative, associative, idempotent |
| accumulating, folding, reducing a sequence | monoid | an identity element, and safe partial or parallel reduction |
| precedence, overrides, "most specific wins" | lattice / partial order | a defined winner for every conflict |
| dedup, "are these the same thing", canonicalize | equivalence relation + normal form | one representative per class |
| rules plus a thing to maximize | constraint / optimization model | the real optimum, not a greedy guess |
| lifecycles, legal vs illegal transitions | state machine | impossible states you cannot even represent |

The move, in six steps:
1. Name the core operation or relation in one sentence.
2. Ask what laws it should obey: identity, commutative, associative, idempotent, monotonic, total or partial.
3. Match it to a structure above and name it out loud.
4. Write the canonical form and the invariants down, in words, before any code.
5. Implement against that, then prove the laws hold with the engines below. Z3 for "for all inputs", Hypothesis or CrossHair for "I tried hard and could not break it".
6. Honesty gate: if nothing clean fits, say so and stop modelling. Forcing an abstraction onto genuinely messy logic is the false-confidence trap one level up.

The goal is not to mathematise everything. It is to notice when a sprawl of special cases is secretly one law, collapse it to that law, and prove the collapse was valid. A junior writes the forty cases. You find the one law that makes thirty-nine of them vanish, and you prove it holds.

## When to reach for which engine

Match the sub-problem, pick the tool:

| You are about to | Reach for | What it buys you |
|---|---|---|
| claim a function is correct, or an invariant always holds | `chiasmus_verify` (Z3 SMT) | a proof, or a concrete counterexample. not a vibe |
| say "this refactor is equivalent to the old one" | `chiasmus_verify` (assert inputs equal and outputs differ; UNSAT means equivalent) | the exact input where they diverge, if one exists |
| do algebra, calculus, simplification, exact arithmetic | the `sympy` tools (`solve_algebraically`, `integrate_expression`, `simplify_expression`, ...) | you fumble symbolic math and floating point. SymPy does not |
| reason over relations, reachability, conflicting rules | `chiasmus_solve` (Prolog) | transitive closure and logic done correctly |
| schedule, allocate, pack, assign, optimize | `mcp-solver` (`add_item` then `solve_model`) | the optimum under constraints, not a greedy guess |
| find the input that breaks a Python function | `crosshair check` (CLI) | symbolic execution walks every path and hands you the break |
| confirm two functions agree everywhere | `crosshair diffbehavior` (CLI) | a disagreeing input, or silence |
| check types, lint, catch bug classes | `pyright`, `ruff` (CLI) | cheap and fast. run it every time |
| catch injection, taint, security smells | `semgrep_scan` | thousands of deterministic rules |
| understand call structure, dead code, blast radius | `chiasmus_graph` | a real graph, not grep and hope |

> SymPy is stateful. Declare each variable with `intro` (and its assumptions, like `real`) **before** you introduce an expression that uses it, then solve. Skip that and `solve_algebraically` silently returns the empty set, because the expression's symbol is a different object from the one you solved for.

## The two moves

**Translate then solve.** Turn the fuzzy thing into the engine's language, let it compute the exact answer, read it back in plain words. This is math, constraints, and optimization.

**Generate then verify.** Write the candidate. Then prove it or break it. If the engine returns a counterexample, feed that input back to yourself and fix the code. Loop until it comes back clean. This is where most of the value lives, and it is exactly the move people skip.

## The rule that keeps you honest

The engine proves your *encoding*, not your *intention*. Translate the problem wrong and you get a rigorous answer to the wrong question, which is worse than no answer because it looks trustworthy. So after every proof, state in one plain sentence what you actually proved, and sanity-check that it is what you meant.

Know exactly what each result guarantees:
- Z3 returning UNSAT over the integers is a real proof for all integer inputs.
- MiniZinc returning OPTIMAL is a real optimum for the model you wrote.
- CrossHair finding no counterexample is **not** a proof. It means it did not find a break inside the time budget you gave it. Absence of evidence.
- Tests passing is evidence, never certainty.

## Do not solver-everything

Most code is glue. Buttons, routes, CRUD, async plumbing, product logic. None of it has a clean spec, so a prover has nothing to bite on, and forcing it through one is wasted effort and false confidence. Use these engines on the slice that has a spec: algorithms, math, invariants, equivalence, constraints, optimization. Everything else stays on types, lint, tests, and a second reader.

## Command-line quick reference

```
# prove or break a Python function (give it a timeout, target one function)
uvx --from crosshair-tool crosshair check path/to/mod.py --per_condition_timeout 15

# do two functions ever disagree?
uvx --from crosshair-tool crosshair diffbehavior mypkg.mod.f mypkg.mod.g

# types and lint
pyright --outputjson path/        ;  ruff check --output-format=json path/

# security (prefer the semgrep_scan MCP tool; this is the CLI fallback)
semgrep scan --config auto path/
```

## How to report it

Name the engine and the guarantee. "Z3 proved the index stays in bounds for every int input." "CrossHair found n = -1 breaks it." "MiniZinc says 42 is optimal." Never launder a solver result into a soft reassurance like "this should be fine." If you did not prove it, say you did not prove it.
