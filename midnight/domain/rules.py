# midnight/domain/rules.py
from __future__ import annotations
from bisect import bisect_right
from collections import deque
from decimal import Decimal
from .models import UserState
from midnight.config import Settings

def _append_deposit_prefix(state: UserState, amount: Decimal, t: int) -> None:
    """
    Append a deposit at time t into prefix arrays.
    Invariants: times strictly increase (enforced by service-level monotonicity check).
    """
    if state.deposit_cums:
        new_cum = state.deposit_cums[-1] + amount
    else:
        new_cum = amount
    state.deposit_times.append(t)
    state.deposit_cums.append(new_cum)

def _cum_at(state: UserState, t_query: int) -> Decimal:
    """
    Return cumulative deposit sum at time <= t_query (i.e., sum over all deposits with time <= t_query).
    If no deposits at or before t_query, return 0.
    """
    if not state.deposit_times:
        return Decimal("0")
    # index of first time > t_query
    idx = bisect_right(state.deposit_times, t_query) - 1
    if idx < 0:
        return Decimal("0")
    return state.deposit_cums[idx]

def _sum_window_prefix(state: UserState, t: int, window_seconds: int) -> Decimal:
    """
    Sum of deposits over (t - window_seconds, t], using prefix sums:
      sum = cum_at(t) - cum_at(t - window_seconds)
    Also prunes old points to cap memory.
    """
    threshold = t - window_seconds
    total_now = _cum_at(state, t)
    total_before = _cum_at(state, threshold)
    window_sum = total_now - total_before

    # --- pruning (optional but recommended) ---
    # Keep from max(0, left_index - 1) to preserve exactly one anchor point
    # at or before the threshold for future queries.
    if state.deposit_times:
        cut = bisect_right(state.deposit_times, threshold)  # first index with time > threshold
        keep_from = max(0, cut - 1)
        if keep_from > 0:
            # slice lists to drop old heads
            state.deposit_times = state.deposit_times[keep_from:]
            state.deposit_cums   = state.deposit_cums[keep_from:]
            # nothing else to adjust: we store absolute cumulative values

    return window_sum

def apply_event_and_collect_alerts(
    state: UserState,
    etype: str,
    amount: Decimal,
    t: int,
    cfg: Settings,
) -> list[int]:
    alerts: list[int] = []

    if etype == "withdraw":
        # Rule: single withdraw > threshold
        if amount > cfg.RULE_WITHDRAW_GT_AMOUNT:
            alerts.append(cfg.ALERT_WITHDRAW_GT)

        # Rule: N consecutive withdraws
        state.consec_withdraws += 1
        if state.consec_withdraws >= cfg.RULE_CONSEC_WITHDRAWS_COUNT:
            alerts.append(cfg.ALERT_3_CONSEC_WITHDRAWS)

    else:
        # deposit branch
        state.consec_withdraws = 0

        # Keep deque capacity for "increasing deposits" aligned with config
        if state.last_deposits.maxlen != cfg.RULE_INC_DEPOSITS_COUNT:
            state.last_deposits = deque(state.last_deposits, maxlen=cfg.RULE_INC_DEPOSITS_COUNT)

        # Track last deposits for strictly increasing rule
        state.last_deposits.append(amount)
        if len(state.last_deposits) == cfg.RULE_INC_DEPOSITS_COUNT:
            it = iter(state.last_deposits)
            prev = next(it)
            strictly_inc = True
            for cur in it:
                if not (prev < cur):
                    strictly_inc = False
                    break
                prev = cur
            if strictly_inc:
                alerts.append(cfg.ALERT_3_INC_DEPOSITS)

        # Prefix sums for sliding window rule
        _append_deposit_prefix(state, amount, t)
        window_sum = _sum_window_prefix(state, t, cfg.RULE_DEPOSIT_SUM_WINDOW_SECONDS)
        if window_sum > cfg.RULE_DEPOSIT_SUM_THRESHOLD:
            alerts.append(cfg.ALERT_30S_DEPOSITS_GT)

    return alerts
