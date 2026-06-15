# rigor

Your AI coding assistant is confidently wrong sometimes. It swears the function is correct. It is not. It does arithmetic in its head and drops a carry. It waves its hands at a proof and moves on.

rigor hands Claude Code a set of tools that do not guess. A theorem prover. A symbolic math engine. A constraint solver. A thing that walks every path through your function hunting for the input that breaks it. When a problem has an exact answer, Claude stops improvising and asks the engine that knows.

This is the neurosymbolic idea, packaged so you can install it in about a minute.

## What gets wired in

One command adds these to Claude Code:

- **Chiasmus** bundles three engines in one server: Z3 (an SMT prover), SWI-Prolog (logic and reachability), and tree-sitter code graphs. Prove a property. Find the counterexample. Map who calls what.
- **SymPy** for exact symbolic math. Solve, integrate, simplify, check an identity. No floating point lies.
- **mcp-solver with MiniZinc** for constraint and optimization problems. Scheduling, packing, assignment. It returns the optimum, not a hopeful guess.
- **Semgrep** for security and bug-class scanning. Thousands of rules, deterministic, fast.
- **CrossHair, pyright, and ruff** as command-line tools the agent runs directly: symbolic execution to break functions, type checking, and linting.

## Why this exists

Here is the one thing language models cannot do reliably. Be sure. They pattern match, which is wonderful for a first draft and useless when you need a guarantee. A solver is the mirror image. Hopeless at writing your app, perfect at telling you whether x squared is ever smaller than x over the integers.

Bolt them together and the model does what it is good at while the solver does what it is good at. You stop shipping the bug that only shows up on the empty list.

The move that matters most is generate then verify. Claude writes a candidate. The solver tries to prove it or break it. If it breaks, the counterexample goes back and Claude tries again. You loop until the code is actually correct, not until it looks correct. That last distinction is the whole point.

## Install

You need Node, Python 3.11 or newer, git, curl, and [uv](https://docs.astral.sh/uv). Then:

```bash
git clone https://github.com/YOUR_GITHUB/rigor
cd rigor
./install.sh
```

Restart Claude Code so it loads the new servers. Done.

Trimming options:

```bash
./install.sh --no-minizinc   # skip the 75 MB CP solver bundle
./install.sh --minimal       # just Chiasmus and the skill
```

## How Claude knows when to use it

The installer drops a skill into Claude Code. That skill is a routing table. It tells the model which engine fits which problem, and it drills in one rule the model must not forget: the solver proves your encoding, not your intention. Translate the problem wrong and you get a rigorous answer to the wrong question. So the skill forces Claude to say, in plain words, what it actually proved. Every time.

Want the routing to be always-on instead of skill-triggered? Drop the contents of `skills/rigor/SKILL.md` into your project `CLAUDE.md`.

## What it is not

It is not magic and it is not for everything. Most code is glue. None of that has a clean mathematical spec, so a prover has nothing to bite on. rigor earns its keep on the slice that does have a spec: algorithms, math, invariants, equivalence checks, constraints, optimization. Use it there. Use tests and a review for the rest.

And read the guarantees honestly. CrossHair finding no counterexample is not a proof, it just ran out of time looking. Z3 returning UNSAT over the integers is a proof. Those are very different claims and the skill makes Claude keep them straight.

## Uninstall

```bash
./uninstall.sh            # unwire servers, remove skill, clean ~/.rigor
./uninstall.sh --purge    # also remove the global tools it installed
```

## Standing on other people's work

The hard parts were built by other people. rigor wires them together and teaches Claude when to call them: Chiasmus (yogthos), sympy-mcp (sdiehl), mcp-solver (Szeider, TU Wien), CrossHair (pschanely), Semgrep, Z3, SymPy, MiniZinc. Go star their repos too.

MIT licensed. Do what you want with it.
