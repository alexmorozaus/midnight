# FILE: midnight/schemas/event.py
from decimal import Decimal
from pydantic import BaseModel, Field, field_validator

class EventIn(BaseModel):
    type: str
    amount: Decimal = Field(ge=Decimal("0"))
    user_id: int
    t: int

    @field_validator("type")
    @classmethod
    def _type(cls, v: str) -> str:
        if v not in ("deposit", "withdraw"):
            raise ValueError("type must be deposit|withdraw")
        return v

class EventOut(BaseModel):
    alert: bool
    alert_codes: list[int]
    user_id: int

