# Design review: explore, then commit

For a decision that matters (a new subsystem, a schema, a protocol, a refactor that touches many files), do not take the first plausible idea. The cost of the wrong architecture dwarfs the hour spent comparing a few.

## The loop

1. State the problem and the constraints in a few lines: what must be true, what must scale, what must never happen.
2. Sketch two or three genuinely different designs. Not variations, real alternatives: state-based versus op-based, sync versus async, normalized versus denormalized, push versus pull.
3. For each, write the tradeoffs against the constraints: complexity, coupling, failure modes, how it scales, how it fails.
4. Red-team each with Codex. It is an independent model, so it sees what you anchored past. Use the codex plugin's adversarial review, or hand it the design and ask it to break the thing: where does this fall over at ten times the load, what invariant does it quietly violate, what is the worst input, what happens on partial failure.
5. Pick on purpose, and write down why, including why you rejected the others. That rejection record is the most useful part, and it is what the system model keeps.

## The honest part

Most changes are not design decisions and do not need any of this. A new endpoint that follows the existing pattern is not a design decision. Spend this only on the handful of choices that are expensive to reverse. Running it on everything is the same false-confidence trap as proving glue code.
