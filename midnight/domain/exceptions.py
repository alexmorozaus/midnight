# FILE: midnight/domain/exceptions.py
class DomainError(Exception):
    """Base domain error."""


class NonMonotonicTime(DomainError):
    """Raised when an event time t is not strictly increasing for a user."""
    def __init__(self, user_id: int, last_t: int | None, new_t: int) -> None:
        self.user_id = user_id
        self.last_t = last_t
        self.new_t = new_t
        super().__init__(f"non-monotonic time: last_t={last_t}, new_t={new_t}, user_id={user_id}")
