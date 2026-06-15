# The toolbox

What each engine is, what it actually guarantees, and when to call it.

## Chiasmus (MCP server)

Three engines behind one server. Installed globally over npm (`chiasmus`), runs Z3 and SWI-Prolog as bundled WASM so there is no native solver to compile.

- `chiasmus_verify`: submit SMT-LIB to Z3 (or a Prolog goal) and get a verified result back, with unsat cores or derivation traces. This is your prover. To prove a property, assert its negation and check for UNSAT. UNSAT means no counterexample exists. SAT hands you the counterexample.
- `chiasmus_solve`: solve a constraint system.
- `chiasmus_graph`: tree-sitter call graph: callers, callees, reachability, cycles, dead code, taint and impact analysis. Real structure, not a text search.
- `chiasmus_map`, `chiasmus_formalize`, `chiasmus_craft`, and friends: codebase outline, pick a verification template, build reusable templates.

Guarantee: a Z3 UNSAT result is a genuine proof over the declared theory (ints, reals, bitvectors, arrays). Watch the theory you chose. A proof over reals is not a proof over floats.

## SymPy (MCP server: sympy)

About forty tools wrapping SymPy for exact computer algebra: `solve_algebraically`, `solve_linear_system`, `dsolve_ode`, `integrate_expression`, `differentiate_expression`, `simplify_expression`, matrices, vector calculus, units. Results are exact rationals, radicals, and symbolic forms.

Use it whenever you would otherwise compute math in your head or in float. To check an identity, simplify `lhs - rhs` and confirm it is zero.

Security note: SymPy parses expressions with eval underneath. Feed it expressions you control.

## mcp-solver with MiniZinc (MCP server: mcp-solver)

A stateful model-building interface (`add_item`, `replace_item`, `solve_model`, `get_model`) over MiniZinc, with Gecode and Chuffed as the constraint solvers. Backed by a SAT 2025 paper.

Use it for constraint satisfaction and optimization: scheduling, packing, assignment, routing, resource allocation. The installer wires the MiniZinc backend by default. mcp-solver also ships SAT, MaxSAT, SMT, and ASP backends if you want them.

Guarantee: an OPTIMAL result is a true optimum for the model you wrote. INFEASIBLE means no solution exists under your constraints. As always, it is your model that gets solved, so read it back.

## Semgrep (MCP server: semgrep)

`semgrep_scan`, `security_check`, custom-rule scanning, AST queries. Thousands of rules across many languages for security and bug-class detection. Deterministic and fast. Local scanning needs no token.

This is pattern and dataflow analysis, not type inference. Pair it with pyright for types.

## CrossHair (CLI)

`uvx --from crosshair-tool crosshair check <target>` symbolically executes a Python function looking for inputs that violate its type annotations, contracts, or asserts. `crosshair diffbehavior f g` finds an input where two functions disagree. `crosshair cover` generates path-covering examples.

Guarantee: a reported counterexample is real, reproduce it. No counterexample is NOT a proof. It means CrossHair did not find a break within the timeout. Always pass `--per_condition_timeout` and target specific functions, it is slow per function.

## pyright and ruff (CLI)

`pyright --outputjson` for type checking, `ruff check --output-format=json` for fast lint and bug-class detection. Cheap enough to run on every change. These catch the boring bugs before the expensive engines ever get involved.
