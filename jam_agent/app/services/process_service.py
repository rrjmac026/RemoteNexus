import psutil


def list_processes() -> list[dict]:
    processes = []
    for proc in psutil.process_iter(["pid", "name"]):
        try:
            processes.append({"pid": proc.info["pid"], "name": proc.info["name"] or "Unknown"})
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return sorted(processes, key=lambda p: p["pid"])