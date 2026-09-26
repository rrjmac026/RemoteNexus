import platform
import socket
import time

import psutil


def get_system_info(computer_name: str) -> dict:
    boot_time = psutil.boot_time()
    uptime_seconds = int(time.time() - boot_time)
    days, remainder = divmod(uptime_seconds, 86400)
    hours, _ = divmod(remainder, 3600)

    return {
        "computer_name": computer_name,
        "os": f"{platform.system()} {platform.release()}",
        "cpu_percent": psutil.cpu_percent(interval=0.3),
        "ram_percent": psutil.virtual_memory().percent,
        "storage_percent": _get_overall_storage_percent(),
        "uptime": f"{days} days {hours} hours",
    }


def _get_overall_storage_percent() -> float:
    total_bytes = 0
    used_bytes = 0

    for partition in psutil.disk_partitions(all=False):
        try:
            usage = psutil.disk_usage(partition.mountpoint)
            total_bytes += usage.total
            used_bytes += usage.used
        except (PermissionError, OSError):
            # Some mounts (e.g. removable/optical drives with no media) can't be read — skip them
            continue

    if total_bytes == 0:
        return 0.0

    return round((used_bytes / total_bytes) * 100, 1)


def get_network_info(computer_name: str, local_ip: str) -> dict:
    return {
        "hostname": computer_name,
        "local_ip": local_ip,
        "interface": _detect_interface(),
        "status": "Connected",
    }


def _detect_interface() -> str:
    stats = psutil.net_if_stats()
    for name, info in stats.items():
        if info.isup and name.lower() not in ("loopback", "lo"):
            return name
    return "Unknown"