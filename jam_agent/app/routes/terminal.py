from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

from app.authentication import is_token_valid
from app.config import load_config, get_local_ip
from app.services.system_service import get_system_info, get_network_info

router = APIRouter()

KNOWN_COMMANDS = ["help", "clear", "system", "network", "server", "files", "download", "upload", "exit"]
AVAILABLE_NOW = ["help", "clear", "system", "network", "server", "exit"]


class CommandRequest(BaseModel):
    command: str


def require_auth(authorization: str):
    token = authorization.replace("Bearer ", "").strip()
    if not is_token_valid(token):
        raise HTTPException(status_code=401, detail={
            "success": False,
            "error": {"code": "UNAUTHORIZED", "message": "Invalid or missing token."}
        })


def _format_kv(title: str, data: dict) -> str:
    lines = [title, ""]
    for k, v in data.items():
        label = k.replace("_", " ").title()
        lines.append(f"{label}: {v}")
    return "\n".join(lines)


@router.post("/api/terminal")
def run_command(body: CommandRequest, authorization: str = Header(default="")):
    require_auth(authorization)

    raw = body.command.strip()
    parts = raw.split()
    cmd = parts[0].lower() if parts else ""

    if cmd == "":
        return {"success": True, "data": {"output": ""}}

    if cmd == "help":
        lines = ["Available Commands", ""]
        lines.append("system       System information")
        lines.append("network      Network information")
        lines.append("server       Server information")
        lines.append("files        File manager (coming in Phase 5)")
        lines.append("download     Download file (coming in Phase 5)")
        lines.append("upload       Upload file (coming in Phase 5)")
        lines.append("clear        Clear terminal")
        lines.append("help         Show help")
        lines.append("exit         Disconnect")
        return {"success": True, "data": {"output": "\n".join(lines)}}

    if cmd == "system":
        config = load_config()
        info = get_system_info(config["computer_name"])
        return {"success": True, "data": {"output": _format_kv("SYSTEM", info)}}

    if cmd == "network":
        config = load_config()
        info = get_network_info(config["computer_name"], get_local_ip())
        return {"success": True, "data": {"output": _format_kv("NETWORK", info)}}

    if cmd == "server":
        config = load_config()
        info = {
            "computer_name": config["computer_name"],
            "port": config["port"],
            "authentication_enabled": config["authentication_enabled"],
            "status": "ONLINE",
        }
        return {"success": True, "data": {"output": _format_kv("SERVER", info)}}

    if cmd == "files":
        from app.services import file_service
        try:
            target_path = parts[1] if len(parts) > 1 else ""
            items = file_service.list_directory(target_path)
            if not items:
                return {"success": True, "data": {"output": "(empty)"}}
            lines = []
            for item in items:
                suffix = "/" if item["is_directory"] else ""
                lines.append(f"{item['name']}{suffix}")
            return {"success": True, "data": {"output": "\n".join(lines)}}
        except Exception as e:
            return {"success": True, "data": {"output": f"Error: {e}"}}

    if cmd in ("download", "upload"):
        return {"success": True, "data": {"output": f"Use the graphical File Manager for '{cmd}'."}}

    if cmd == "exit":
        return {"success": True, "data": {"output": "Disconnecting...", "action": "exit"}}

    if cmd in KNOWN_COMMANDS:
        return {"success": True, "data": {"output": f"'{cmd}' recognized but not yet implemented."}}

    return {
        "success": False,
        "error": {"code": "UNKNOWN_COMMAND", "message": f"'{cmd}' is not a recognized command. Type 'help'."}
    }