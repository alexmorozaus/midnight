# FILE: midnight/services/alert_service.py
from midnight.schemas.event import EventIn, EventOut
from midnight.storage.user_state_repository import UserStateRepository
from midnight.domain.rules import apply_event_and_collect_alerts
from midnight.domain.exceptions import NonMonotonicTime
from midnight.config import Settings

class AlertService:
    """Application service orchestrating repository and domain rules."""

    def __init__(self, repo: UserStateRepository, settings: Settings) -> None:
        self.repo = repo
        self.settings = settings

    def handle_event(self, event: EventIn) -> dict:
        # Serialize access to states to keep invariants in multi-threaded servers
        with self.repo.lock():
            state = self.repo.get_user(event.user_id)

            # Strictly increasing event time per user
            if state.last_t is not None and event.t <= state.last_t:
                raise NonMonotonicTime(event.user_id, state.last_t, event.t)

            codes = apply_event_and_collect_alerts(
                state, event.type, event.amount, event.t, self.settings
            )
            state.last_t = event.t

        out = EventOut(alert=bool(codes), alert_codes=codes, user_id=event.user_id)
        return out.model_dump()
