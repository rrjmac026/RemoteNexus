import os
import time

LOG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logs", "jam.log")

_SENSITIVE_KEYWORDS = ("password", "token", "authorization", "auth")


def log_event(message: str):
    """Append a timestamped event to jam.log. Never logs passwords or tokens."""
    lowered = message.lower()
    if any(keyword in lowered for keyword in _SENSITIVE_KEYWORDS):
        message = "[event redacted: contains sensitive keyword]"

    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    timestamp = time.strftime("%Y-%m-%d %H:%M")

    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"{timestamp}\n{message}\n\n")


def read_recent_logs(limit: int = 50) -> list[str]:
    if not os.path.exists(LOG_PATH):
        return []

    with open(LOG_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    entries = [e.strip() for e in content.split("\n\n") if e.strip()]
    return entries[-limit:][::-1]  # most recent first