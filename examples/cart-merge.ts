// Merging a guest cart into the account cart at login. Looks like glue code,
// secretly a commutative monoid over item -> quantity.
//
// Run the property check with fast-check:
//   npm i -D fast-check        # or use the shared ~/.touchstone/js install
//   npx tsx examples/cart-merge.ts
//
// fast-check finds the order-dependence in the buggy merge and reports the
// exact carts that break it; the fixed (additive) merge holds.
import fc from "fast-check";

type Cart = Record<string, number>;

// BUG: object spread overwrites a shared item's quantity instead of adding it,
// so merge(guest, account) and merge(account, guest) disagree. Login order
// silently changes the cart, and quantities are lost.
function mergeBuggy(a: Cart, b: Cart): Cart {
  return { ...a, ...b };
}

// The law: a cart merge is a commutative monoid. Quantities add, order is irrelevant.
function mergeFixed(a: Cart, b: Cart): Cart {
  const out: Cart = { ...a };
  for (const [item, qty] of Object.entries(b)) out[item] = (out[item] ?? 0) + qty;
  return out;
}

// Realistic SKUs as keys. (Let fast-check use arbitrary strings and it will also
// surface nastier keys like "__proto__" that break plain-object merges, which is
// a real finding but a different lesson.)
const cart = fc.dictionary(
  fc.constantFrom("apple", "pear", "banana", "kiwi", "fig", "lime"),
  fc.integer({ min: 1, max: 50 }),
);
const norm = (c: Cart) => JSON.stringify(Object.entries(c).sort());

function check(merge: (a: Cart, b: Cart) => Cart, label: string): void {
  try {
    fc.assert(
      // commutative: login order must not change the resulting cart
      fc.property(cart, cart, (a, b) => norm(merge(a, b)) === norm(merge(b, a))),
      { numRuns: 500 },
    );
    console.log(`${label}: no counterexample found`);
  } catch (e) {
    console.log(`${label}: ${(e as Error).message.split("\n")[0]}`);
  }
}

check(mergeBuggy, "buggy merge"); // fast-check surfaces a breaking pair of carts
check(mergeFixed, "fixed merge"); // holds across 500 random cases
