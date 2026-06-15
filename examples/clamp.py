def clamp(x: int, lo: int, hi: int) -> int:
    return max(lo, min(x, hi))


def check_clamp(x: int, lo: int, hi: int) -> None:
    # leading asserts = preconditions (a sane range). note we do NOT assume lo <= hi
    assert -1000 <= x <= 1000
    assert -1000 <= lo <= 1000
    assert -1000 <= hi <= 1000
    result = clamp(x, lo, hi)
    assert lo <= result <= hi  # the law a clamp should obey
