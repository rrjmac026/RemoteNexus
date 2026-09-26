import subprocess

# Only these services are exposed, matching the spec's example list.
# Read-only for now — no start/stop/restart actions.
MONITORED_SERVICES = ["Spooler", "W32Time", "WinDefend"]


def list_services() -> list[dict]:
    results = []
    for service_name in MONITORED_SERVICES:
        status = _query_service_status(service_name)
        results.append({"name": service_name, "status": status})
    return results


def _query_service_status(service_name: str) -> str:
    try:
        output = subprocess.run(
            ["sc", "query", service_name],
            capture_output=True, text=True, timeout=5
        )
        if "RUNNING" in output.stdout:
            return "Running"
        if "STOPPED" in output.stdout:
            return "Stopped"
        return "Unknown"
    except Exception:
        return "Unknown"