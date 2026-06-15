<p align="center">
  <img src="assets/icon.svg" width="96" alt="touchstone">
</p>

# touchstone

Your AI coding assistant is confidently wrong sometimes. It swears the function is correct. It is not. It does arithmetic in its head and drops a carry. It waves at a proof and moves on.

touchstone hands Claude Code a set of tools that do not guess. A theorem prover. A symbolic math engine. A constraint solver. A tool that explores your function's paths to find the input that breaks it. When a problem has an exact answer, Claude stops improvising and asks the engine that knows.

The name is the old jeweller's trick. You rub gold against a dark stone and read the streak to tell real metal from fake. That is what these tools do to code.

## What gets wired in

One command adds these to Claude Code:

- **Chiasmus** bundles three engines in one server: Z3 (an SMT prover), SWI-Prolog (logic and reachability), and tree-sitter code graphs. Prove a property. Find the counterexample. Map who calls what.
- **SymPy** for exact symbolic math. Solve, integrate, simplify, check an identity. No floating point lies.
- **mcp-solver with MiniZinc** for constraint and optimization problems. Scheduling, packing, assignment. It returns the optimum, not a hopeful guess.
- **Semgrep** for security and bug-class scanning. Thousands of rules, deterministic, fast.
- **CrossHair, pyright, and ruff** as command-line tools the agent runs directly: symbolic execution to break functions, type checking, and linting.

## What it can do

Concrete jobs you can hand it. Each routes to the engine that gives a real answer instead of a confident shrug.

**Prove a function correct, or get the input that breaks it.** Ask whether something always holds and Z3 either proves it for every input or hands you a counterexample. Take the claim `2*x >= x` for all integers. Sounds fine. Z3 says no and gives you `x = -1`, because two times minus one is minus two, which is smaller than minus one. That is the bug you would have shipped, caught in a single call.

**Check that a refactor changed nothing.** You rewrote a function to make it faster. Assert that the old and new versions disagree somewhere and let Z3 look. UNSAT means they are identical on every input. SAT means here is the exact case where you broke it.

**Do the math without fumbling it.** Solving `x^2 - 1 = 0` returns `{-1, 1}` exactly, not a float that is almost right. Integrate, differentiate, simplify, expand, check an identity. SymPy does the algebra you would otherwise eyeball and get wrong at 1am.

**Solve the optimization you were about to hand-roll.** Scheduling, packing, assignment, routing. Describe the constraints and what to maximize, and MiniZinc returns the genuine optimum and tells you it is optimal. No more greedy loop that looks clever and is wrong on the case nobody tested.

**Hunt the edge case nobody wrote a test for.** CrossHair explores a Python function's paths within a time budget, looking for input that violates its types, asserts, or contracts. Point it at a tidy looking `clamp(x, lo, hi)` and it finds that the thing silently returns `lo` when `lo > hi`. Now you get to decide whether that is a bug on purpose instead of by accident.

**Read your codebase as a graph.** Who calls this. What is unreachable. Where tainted input actually flows. A real call graph from tree-sitter, not grep and a hunch.

**Scan for the bad patterns.** Semgrep runs thousands of rules over your code, the same way every time. Injection, unsafe deserialization, the usual security smells, each flagged with a file and a line.

**Settle questions of logic and rules.** Prolog does reachability, transitive closure, and "can these two rules ever both fire" the way a search through your head cannot.

## A session looks like this

You ask Claude to write a function and make sure it is right. Instead of writing it and saying "looks good," Claude writes a candidate, runs it through the matching engine, and reads the verdict. If Z3 or CrossHair hands back a breaking input, the fix goes in and it runs again. The loop ends when the engine has nothing left to complain about, not when the code merely compiles.

Then it tells you what it actually checked. Not "this should be fine." Something you can trust the shape of: "Z3 proved the index stays in bounds for every integer input," or "CrossHair found no counterexample in 15 seconds, which is good evidence but not a proof." You always know which kind of certainty you are holding.

## Why this exists

Here is the one thing language models cannot do reliably. Be sure. They pattern match, which is wonderful for a first draft and useless when you need a guarantee. A solver is the mirror image. Hopeless at writing your app, perfect at telling you whether x squared is ever smaller than x over the integers.

Bolt them together and the model does what it is good at while the solver does what it is good at. You stop shipping the bug that only shows up on the empty list.

The move that matters most is generate then verify. Claude writes a candidate. The solver tries to prove it or break it. If it breaks, the counterexample goes back and Claude tries again. You loop until the code is correct, not until it compiles and looks right. Looks-right is where the bugs live.

## Install

You need Node, Python 3.11 or newer, git, curl, and [uv](https://docs.astral.sh/uv). Then:

```bash
git clone https://github.com/Hans-Stuffer/touchstone
cd touchstone
./install.sh
```

Restart Claude Code so it loads the new servers. Done.

Trimming options:

```bash
./install.sh --no-minizinc   # skip the 75 MB CP solver bundle
./install.sh --minimal       # just Chiasmus and the skill
```

The installer is idempotent. Run it again any time to update the servers, and `./uninstall.sh` to back it all out.

## How Claude knows when to use it

The installer drops a skill into Claude Code. That skill is a routing table. It tells the model which engine fits which problem, and it drills in one rule the model must not forget: the solver proves your encoding, not your intention. Translate the problem wrong and you get a rigorous answer to the wrong question. So the skill makes Claude state, in plain words, what it actually proved on every pass.

Want the routing always-on instead of skill-triggered? Drop the contents of `skills/touchstone/SKILL.md` into your project `CLAUDE.md`. There is a per-tool reference in [docs/TOOLS.md](docs/TOOLS.md), worked before-and-after examples in [examples/](examples/README.md), a real-coding map in [docs/MODELING.md](docs/MODELING.md), and the literature behind the approach (with verified citations) in [docs/BACKGROUND.md](docs/BACKGROUND.md).

## What it is not

It is not magic and it is not for everything. Most code is glue. None of that has a clean mathematical spec, so a prover has nothing to bite on. touchstone earns its keep on the slice that does have a spec: algorithms, math, invariants, equivalence checks, constraints, optimization. Use it there. Use tests and a review for the rest.

And read the guarantees honestly. CrossHair finding no counterexample is not a proof, it just ran out of time looking. Z3 returning UNSAT over the integers is a proof, but Z3 can also answer "unknown" on a hard fragment, which settles nothing. Those are different claims and the skill keeps Claude from blurring them.

## Uninstall

```bash
./uninstall.sh            # unwire servers, remove skill, clean ~/.touchstone
./uninstall.sh --purge    # also remove the global tools it installed
```

## Standing on other people's work

The hard parts were built by other people. touchstone wires them together and teaches Claude when to call them: Chiasmus (yogthos), sympy-mcp (sdiehl), mcp-solver (Szeider, TU Wien), CrossHair (pschanely), Semgrep, Z3, SymPy, MiniZinc. Go star their repos too.

MIT licensed. Do what you want with it.
