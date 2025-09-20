# FILE: midnight/__init__.py
from dotenv import load_dotenv
load_dotenv()

from flask import Flask
from .storage.memory_user_state_repository import MemoryUserStateRepository
from .services.alert_service import AlertService
from .api.events import bp as events_bp
from .config import load_settings

def create_app() -> Flask:
    app = Flask(__name__)
    # Load env with prefix MIDNIGHT_
    app.config.from_prefixed_env("MIDNIGHT_")

    # Load strongly-typed settings
    settings = load_settings()

    # Wire repository and service
    repo = MemoryUserStateRepository()
    alert_service = AlertService(repo, settings)
    app.extensions = getattr(app, "extensions", {})
    app.extensions["alert_service"] = alert_service

    # Routes
    app.register_blueprint(events_bp)
    return app


