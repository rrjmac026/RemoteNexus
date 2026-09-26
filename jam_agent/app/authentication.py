import json
import os
import secrets
import string
import threading
import time
import uuid

from app.logging_config import log_event

DEVICES_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "shared", "devices.json")

_lock = threading.Lock()

# In-memory pending pairing requests: request_id -> dict
_pending = {}


def _load_devices() -> dict:
    if not os.path.exists(DEVICES_PATH):
        return {}
    with open(DEVICES_PATH, "r") as f:
        content = f.read().strip()
        if not content:
            return {}
        return json.loads(content)


def _save_devices(devices: dict):
    os.makedirs(os.path.dirname(DEVICES_PATH), exist_ok=True)
    with open(DEVICES_PATH, "w") as f:
        json.dump(devices, f, indent=2)


def _generate_code() -> str:
    return "".join(secrets.choice(string.digits) for _ in range(6))


def _generate_token() -> str:
    return secrets.token_hex(32)


def create_pairing_request(device_name: str, ip: str) -> dict:
    request_id = str(uuid.uuid4())
    code = _generate_code()
    with _lock:
        _pending[request_id] = {
            "device_name": device_name,
            "ip": ip,
            "code": code,
            "status": "pending",   # pending | approved | denied
            "token": None,
            "created_at": time.time(),
        }

    print()
    print("=" * 32)
    print("       NEW DEVICE REQUEST")
    print("=" * 32)
    print()
    print(f"Device:  {device_name}")
    print(f"IP:      {ip}")
    print(f"Code:    {code}")
    print()
    print(f"Approve with:  allow {request_id[:8]}")
    print(f"Deny with:     deny {request_id[:8]}")
    print("=" * 32)
    print()

    return {"request_id": request_id, "code": code}


def get_request_status(request_id: str) -> dict | None:
    with _lock:
        return _pending.get(request_id)


def resolve_by_short_id(short_id: str, approve: bool) -> str | None:
    with _lock:
        match = None
        for rid in _pending:
            if rid.startswith(short_id):
                match = rid
                break
        if not match:
            return None

        req = _pending[match]
        if approve:
            token = _generate_token()
            req["status"] = "approved"
            req["token"] = token

            devices = _load_devices()
            devices[token] = {
                "device_name": req["device_name"],
                "ip": req["ip"],
                "paired_at": time.time(),
            }
            _save_devices(devices)
            log_event(f"Android device connected: {req['device_name']} ({req['ip']})")
        else:
            req["status"] = "denied"

        return match


def is_token_valid(token: str) -> bool:
    devices = _load_devices()
    return token in devices


def revoke_device(token: str) -> bool:
    devices = _load_devices()
    if token in devices:
        del devices[token]
        _save_devices(devices)
        return True
    return False


def list_devices() -> dict:
    return _load_devices()


def console_listener():
    """Runs in a background thread. Type: allow <shortid> | deny <shortid> | devices | quit"""
    while True:
        try:
            cmd = input().strip()
        except EOFError:
            return
        if not cmd:
            continue
        parts = cmd.split()
        action = parts[0].lower()

        if action in ("allow", "deny") and len(parts) == 2:
            resolved = resolve_by_short_id(parts[1], approve=(action == "allow"))
            if resolved:
                print(f"[{'APPROVED' if action == 'allow' else 'DENIED'}] {resolved[:8]}")
            else:
                print(f"No pending request matching '{parts[1]}'")
        elif action == "devices":
            devices = list_devices()
            if not devices:
                print("No paired devices.")
            for token, info in devices.items():
                print(f"  {info['device_name']} ({info['ip']}) - token: {token[:8]}...")
        else:
            print("Commands: allow <id> | deny <id> | devices")