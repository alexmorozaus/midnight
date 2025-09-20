# FILE: midnight/api/events.py
from flask import Blueprint, current_app, request, jsonify
from pydantic import ValidationError
from midnight.schemas.event import EventIn
from midnight.domain.exceptions import NonMonotonicTime

bp = Blueprint("events", __name__)

@bp.post("/event")
def post_event():
    # Parse JSON with explicit error response on invalid payload
    try:
        data = request.get_json(force=True, silent=False)
    except Exception:
        return jsonify({"error": "invalid_json"}), 400

    # Validate with Pydantic
    try:
        event = EventIn.model_validate(data)
    except ValidationError as ve:
        return jsonify({"error": "validation_error", "details": ve.errors()}), 400

    # Handle via application service
    service = current_app.extensions["alert_service"]
    try:
        resp = service.handle_event(event)
    except NonMonotonicTime as e:
        return (
            jsonify(
                {
                    "error": "non_monotonic_time",
                    "details": {
                        "user_id": e.user_id,
                        "last_t": e.last_t,
                        "new_t": e.new_t,
                        "message": str(e),
                    },
                }
            ),
            400,
        )

    return jsonify(resp), 200
