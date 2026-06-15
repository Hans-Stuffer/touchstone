from typing import List


def apply_discounts(price_cents: int, percents: List[int]) -> int:
    """Stack percent-off coupons. Looks fine, ships to prod. The bug: stacking
    is additive and uncapped. Two valid 100%-off coupons on a 101 cent item
    return -101, so the customer gets paid to place the order."""
    total_pct = sum(percents)
    return price_cents - price_cents * total_pct // 100


def apply_discounts_fixed(price_cents: int, percents: List[int]) -> int:
    total_pct = min(100, sum(max(0, min(100, p)) for p in percents))
    return price_cents - price_cents * total_pct // 100


def check_never_negative(price_cents: int, percents: List[int]) -> None:
    # leading asserts are preconditions: a real price, each coupon a legit 0..100%
    assert price_cents >= 0
    assert price_cents <= 100_000
    assert all(0 <= p <= 100 for p in percents)
    result = apply_discounts(price_cents, percents)
    assert result >= 0  # the invariant: you never hand money to the customer


def check_fixed(price_cents: int, percents: List[int]) -> None:
    assert price_cents >= 0
    assert price_cents <= 100_000
    assert all(0 <= p <= 100 for p in percents)
    result = apply_discounts_fixed(price_cents, percents)
    assert 0 <= result <= price_cents
