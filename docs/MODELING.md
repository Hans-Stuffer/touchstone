# Modeling: where this touches real code

The engines are useless until you see a problem as something with a law. Most code has no law. It is glue, and touchstone does nothing for it. But a small, high-stakes slice of every real system does carry an invariant, and that slice is exactly where the expensive bugs live: money, auth, data corruption, state. This is the map.

## The honest scope

touchstone is not a quality booster for your whole repo. It is for the 5 to 15 percent that carries an invariant whose violation is costly and hard to catch with example-based tests. Spend it there and nowhere else.

## Where it applies in real software

| Real coding situation | The invariant | The bug it catches | Engine |
|---|---|---|---|
| Order / payment / subscription lifecycle | only legal transitions happen | refund an unpaid order, ship a cancelled one, double-charge | Z3 or Prolog reachability |
| Merge, sync, offline-first, multi-source reconcile | converges, independent of order | lost updates, "the merge depends on who synced first" | Z3, Hypothesis |
| Pricing, discounts, promos, tax, proration | total stays in [0, price], rounding conserves cents | negative charge, stacked discounts, lost cents | CrossHair, Hypothesis, Z3 |
| Authorization (RBAC or ABAC) | deny beats allow, no escalation path | a role combination that quietly grants admin | Prolog or Z3 |
| Idempotent handlers (webhooks, retries, queues) | running it twice equals running it once | a payment processed twice on a retry | Hypothesis, CrossHair |
| Serialization, parsing, schema migration | parse(serialize(x)) equals x | data corruption on a round-trip | Hypothesis |
| Refactor or optimization | the new code behaves exactly like the old | the fast path that is subtly different | Z3 equivalence, crosshair diffbehavior |
| Business-rule engines | rules are complete and do not conflict | two rules fire and contradict, or a case nobody covered | Prolog or Z3 |

None of these are math problems. They are the parts of a product where a quiet invariant decides whether you lose money or corrupt data.

## Worked example: discount stacking

Every commerce backend has this function. This one ships to prod and looks fine:

```python
def apply_discounts(price_cents, percents):
    total_pct = sum(percents)                       # additive, and uncapped
    return price_cents - price_cents * total_pct // 100
```

The senior move is not to read it harder. It is to write down the law a discount must obey: the result stays inside `[0, price]`. Then let CrossHair search the actual code for a way to break that law:

```
crosshair check pricing.py --analysis_kind asserts
=> AssertionError when calling check_never_negative(101, [100, 100])
```

Two perfectly valid 100 percent coupons, a 101 cent item, and the function returns -101. You pay the customer. The fix caps the combined discount at 100 percent, and CrossHair finds no violation on the fixed version, which is strong evidence and not a proof. Real Python, a real bug, found by searching the function's paths instead of hoping a test happened to cover it. The runnable version is in [../examples/discount-stacking.py](../examples/discount-stacking.py).

## The loop, restated for code

1. Writing something in one of the rows above? Name the invariant in one sentence.
2. Pick the engine. "Find me a breaking input" is CrossHair or Hypothesis on the real function. "Prove it for every input" is Z3. "No security hole" is Semgrep.
3. Run it on the code. Fix what it finds. Then say what you actually checked and what that check does and does not guarantee.
4. If the code is glue with no invariant, skip all of this. Forcing it wastes time and manufactures false confidence.
