# FILE: midnight/storage/user_state_repository.py
from abc import ABC, abstractmethod
import threading
from midnight.domain.models import UserState

class UserStateRepository(ABC):
    """Repository contract for accessing per-user UserState aggregates."""

    @abstractmethod
    def get_user(self, user_id: int) -> UserState:
        """Return (or create) a UserState for the given user_id."""
        ...

    @abstractmethod
    def lock(self) -> threading.Lock:
        """Return a process-wide lock to guard critical sections involving states."""
        ...
