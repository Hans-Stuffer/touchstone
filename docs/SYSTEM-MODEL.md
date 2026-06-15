# The system model: hold the design, do not re-derive it

An LLM pattern-matches locally and forgets why the system is the way it is. The fix is a durable model it consults before designing and updates after: what the architecture is, what the invariants are, and what was decided and why.

## Two pieces

- **The architecture, as a graph.** Build and refresh a knowledge graph of the codebase (modules, call structure, dependencies, the seams). Before a non-trivial change, query it instead of guessing at the structure: what depends on this, what is the blast radius, where does this data actually flow. A tool like graphify does this; the point is to consult a real map, not reconstruct it from a few open files.
- **The decisions, as a log.** Keep an append-only decisions record, one short entry per real decision: the context, the choice made, the alternatives rejected, and the reason. Before designing, read the relevant entries. After deciding, add one. This is the memory that stops the agent from quietly undoing a choice it does not remember was deliberate.

## Keep it light

One entry per decision that was expensive to make or expensive to reverse, not per commit. A stale model is worse than none, so update it as part of the change, not as a chore afterward. If maintaining it feels like overhead, you are recording too much; record only what a new senior engineer would need to not repeat a mistake.
