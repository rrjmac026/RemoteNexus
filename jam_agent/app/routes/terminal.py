from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

from app.authentication import is_token_valid
from app.config import load_config, get_local_ip
from app.services.system_service import get_system_info, get_network_info
from app.services import file_service

router = APIRouter()

# Tracks each authenticated token's "current directory" between terminal commands.
_session_cwd: dict[str, str] = {}


class CommandRequest(BaseModel):
    command: str


def require_auth(authorization: str) -> str:
    token = authorization.replace("Bearer ", "").strip()
    if not is_token_valid(token):
        raise HTTPException(status_code=401, detail={
            "success": False,
            "error": {"code": "UNAUTHORIZED", "message": "Invalid or missing token."}
        })
    return token


def _format_kv(title: str, data: dict) -> str:
    lines = [title, ""]
    for k, v in data.items():
        label = k.replace("_", " ").title()
        lines.append(f"{label}: {v}")
    return "\n".join(lines)


def _join_path(cwd: str, arg: str) -> str:
    """Resolves an arg ('..', 'sub', '/abs/from/root', '') against the session cwd."""
    if arg in ("", "."):
        return cwd
    if arg == "..":
        parts = cwd.split("/") if cwd else []
        return "/".join(parts[:-1])
    if arg.startswith("/"):
        return arg.strip("/")
    return f"{cwd}/{arg}" if cwd else arg


@router.post("/api/terminal")
def run_command(body: CommandRequest, authorization: str = Header(default="")):
    token = require_auth(authorization)
    cwd = _session_cwd.get(token, "")

    raw = body.command.strip()
    parts = raw.split()
    cmd = parts[0].lower() if parts else ""
    arg = parts[1] if len(parts) > 1 else ""

    if cmd == "":
        return {"success": True, "data": {"output": "", "cwd": cwd}}

    if cmd == "help":
        lines = [
            "Available Commands", "",
            "system       System information",
            "network      Network information",
            "server       Server information",
            "dir / ls     List current directory",
            "cd <name>    Change directory ('..' goes up, 'cd' alone goes to root)",
            "pwd          Show current path",
            "mkdir <name> Create a folder here",
            "download     Use the graphical File Manager",
            "upload       Use the graphical File Manager",
            "clear        Clear terminal",
            "help         Show help",
            "exit         Disconnect",
        ]
        return {"success": True, "data": {"output": "\n".join(lines), "cwd": cwd}}

    if cmd == "system":
        config = load_config()
        info = get_system_info(config["computer_name"])
        return {"success": True, "data": {"output": _format_kv("SYSTEM", info), "cwd": cwd}}

    if cmd == "network":
        config = load_config()
        info = get_network_info(config["computer_name"], get_local_ip())
        return {"success": True, "data": {"output": _format_kv("NETWORK", info), "cwd": cwd}}

    if cmd == "server":
        config = load_config()
        info = {
            "computer_name": config["computer_name"],
            "port": config["port"],
            "authentication_enabled": config["authentication_enabled"],
            "status": "ONLINE",
        }
        return {"success": True, "data": {"output": _format_kv("SERVER", info), "cwd": cwd}}

    if cmd == "pwd":
        return {"success": True, "data": {"output": f"/{cwd}" if cwd else "/", "cwd": cwd}}

    if cmd in ("dir", "ls", "files"):
        target = _join_path(cwd, arg) if arg else cwd
        try:
            items = file_service.list_directory(target)
            if not items:
                return {"success": True, "data": {"output": "(empty)", "cwd": cwd}}
            lines = [f"{item['name']}{'/' if item['is_directory'] else ''}" for item in items]
            return {"success": True, "data": {"output": "\n".join(lines), "cwd": cwd}}
        except Exception as e:
            return {"success": True, "data": {"output": f"Error: {e}", "cwd": cwd}}

    if cmd == "cd":
        target = _join_path(cwd, arg)
        if target == "":
            # cd with no args, or cd .. from a drive root → virtual root (drive picker)
            _session_cwd[token] = ""
            return {"success": True, "data": {"output": "", "cwd": ""}}
        try:
            resolved = file_service.resolve_safe_path(target)
            if not resolved.exists() or not resolved.is_dir():
                return {"success": True, "data": {"output": f"No such directory: {arg}", "cwd": cwd}}
            _session_cwd[token] = target
            return {"success": True, "data": {"output": "", "cwd": target}}
        except file_service.PathSecurityError:
            return {"success": True, "data": {"output": "Access denied: unknown or forbidden drive.", "cwd": cwd}}

    if cmd == "mkdir":
        if not arg:
            return {"success": True, "data": {"output": "Usage: mkdir <name>", "cwd": cwd}}
        target = _join_path(cwd, arg)
        try:
            file_service.create_directory(target)
            return {"success": True, "data": {"output": f"Created: {arg}", "cwd": cwd}}
        except Exception as e:
            return {"success": True, "data": {"output": f"Error: {e}", "cwd": cwd}}

    if cmd in ("download", "upload"):
        return {"success": True, "data": {"output": f"Use the graphical File Manager for '{cmd}'.", "cwd": cwd}}

    if cmd == "exit":
        _session_cwd.pop(token, None)
        return {"success": True, "data": {"output": "Disconnecting...", "action": "exit", "cwd": cwd}}

    return {
        "success": False,
        "error": {"code": "UNKNOWN_COMMAND", "message": f"'{cmd}' is not a recognized command. Type 'help'."}
    }