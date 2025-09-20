# midnight/domain/models.py
from dataclasses import dataclass, field
from collections import deque
from decimal import Decimal

@dataclass
class UserState:
    # Rule: consecutive withdraws
    consec_withdraws: int = 0

    # Rule: strictly increasing deposits (keep last N deposits)
    last_deposits: deque[Decimal] = field(default_factory=lambda: deque(maxlen=3))

    # Prefix sums for deposits over time:
    # deposit_times[i] — event time t_i  (strictly increasing)
    # deposit_cums[i]  — cumulative sum of deposits up to and including t_i
    deposit_times: list[int] = field(default_factory=list)
    deposit_cums: list[Decimal] = field(default_factory=list)

    # Strictly increasing time validation
    last_t: int | None = None
