# Worked examples

Three small before-and-after stories. Each one is a place where a language model would normally nod along and ship the bug, and where an engine catches it instead.

## 1. Is this refactor actually equivalent?

You rewrote a hot function and you think it does the same thing.

```python
def old(n): return sum(range(n + 1))      # 0 + 1 + ... + n
def new(n): return n * (n + 1) // 2        # the closed form
```

Looks right. Feels right. Ask Z3 instead of trusting the feeling. Encode "there exists an integer n where old(n) and new(n) differ" and check satisfiability with `chiasmus_verify`. For `n >= 0` it comes back UNSAT, which means no such n exists, which means they are equal everywhere. Now you know, instead of hoping.

The catch the model would miss: drop the `n >= 0` guard and Z3 hands you a negative counterexample, because `range` is empty for negative n but the closed form is not. The proof forces you to state the precondition you were quietly assuming.

## 2. Find the input that breaks it

A plausible looking function:

```python
def clamp(x: int, lo: int, hi: int) -> int:
    return max(lo, min(x, hi))
```

Tests pass. Ship it? Run CrossHair first:

```bash
uvx --from crosshair-tool crosshair check mymod.py --per_condition_timeout 15
```

It walks the paths and reports the case you never wrote a test for: when `lo > hi`, the function silently returns `lo`, which is above the supposed maximum. Whether that is a bug depends on your intent, but now the decision is yours to make on purpose instead of by accident.

## 3. Stop hand-rolling the optimizer

You need to pick items under a weight limit to maximize value. The model will happily write a greedy loop that is wrong on the classic counterexamples.

Hand it to MiniZinc through `mcp-solver` instead. State the variables, the capacity constraint, and `maximize total_value`. It returns the real optimum and the exact item set, and it says OPTIMAL so you know it is not a local best. For a knapsack with a handful of items this is instant, and it is correct in the cases a greedy heuristic quietly gets wrong.

---

The pattern under all three is the same. The model writes the candidate and frames the question. The engine gives the verdict. You read the verdict back in plain words and check it answers what you meant to ask.
