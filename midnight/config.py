# FILE: midnight/config.py
from __future__ import annotations
import os
from dataclasses import dataclass
from decimal import Decimal

def _get_int(name: str, default: int) -> int:
    v = os.getenv(name)
    return int(v) if v is not None and v.strip() != "" else default

def _get_dec(name: str, default: Decimal) -> Decimal:
    v = os.getenv(name)
    return Decimal(v) if v is not None and v.strip() != "" else default

@dataclass(frozen=True)
class Settings:
    # Alert codes
    ALERT_WITHDRAW_GT:        int
    ALERT_3_CONSEC_WITHDRAWS: int
    ALERT_3_INC_DEPOSITS:     int
    ALERT_30S_DEPOSITS_GT:    int

    # Rule parameters
    RULE_WITHDRAW_GT_AMOUNT: Decimal
    RULE_CONSEC_WITHDRAWS_COUNT: int
    RULE_INC_DEPOSITS_COUNT: int
    RULE_DEPOSIT_SUM_WINDOW_SECONDS: int
    RULE_DEPOSIT_SUM_THRESHOLD: Decimal

    # Aggregation params
    DEPOSIT_BUCKET_SIZE_SECONDS: int

def load_settings() -> Settings:
    return Settings(
        ALERT_WITHDRAW_GT=_get_int("MIDNIGHT_ALERT_CODE_WITHDRAW_GT", 1100),
        ALERT_3_CONSEC_WITHDRAWS=_get_int("MIDNIGHT_ALERT_CODE_3_CONSEC_WITHDRAWS", 30),
        ALERT_3_INC_DEPOSITS=_get_int("MIDNIGHT_ALERT_CODE_3_INC_DEPOSITS", 300),
        ALERT_30S_DEPOSITS_GT=_get_int("MIDNIGHT_ALERT_CODE_30S_DEPOSITS_GT", 123),

        RULE_WITHDRAW_GT_AMOUNT=_get_dec("MIDNIGHT_RULE_WITHDRAW_GT_AMOUNT", Decimal("100")),
        RULE_CONSEC_WITHDRAWS_COUNT=_get_int("MIDNIGHT_RULE_CONSEC_WITHDRAWS_COUNT", 3),
        RULE_INC_DEPOSITS_COUNT=_get_int("MIDNIGHT_RULE_INC_DEPOSITS_COUNT", 3),
        RULE_DEPOSIT_SUM_WINDOW_SECONDS=_get_int("MIDNIGHT_RULE_DEPOSIT_SUM_WINDOW_SECONDS", 30),
        RULE_DEPOSIT_SUM_THRESHOLD=_get_dec("MIDNIGHT_RULE_DEPOSIT_SUM_THRESHOLD", Decimal("200")),

        DEPOSIT_BUCKET_SIZE_SECONDS=_get_int("MIDNIGHT_DEPOSIT_BUCKET_SIZE_SECONDS", 1),
    )
