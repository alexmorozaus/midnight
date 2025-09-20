# FILE: midnight/storage/memory_user_state_repository.py
import threading
from typing import Dict
from midnight.domain.models import UserState
from .user_state_repository import UserStateRepository

class MemoryUserStateRepository(UserStateRepository):
    """In-memory implementation of UserStateRepository."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._users: Dict[int, UserState] = {}

    def get_user(self, user_id: int) -> UserState:
        state = self._users.get(user_id)
        if state is None:
            state = UserState()
            self._users[user_id] = state
        return state

    def lock(self) -> threading.Lock:
        return self._lock
