from fastapi import APIRouter, Header, HTTPException

from app.authentication import is_token_valid
from app.config import load_config, get_local_ip
from app.services.system_service import get_system_info, get_network_info

router = APIRouter()


def require_auth(authorization: str):
    token = authorization.replace("Bearer ", "").strip()
    if not is_token_valid(token):
        raise HTTPException(status_code=401, detail={
            "success": False,
            "error": {"code": "UNAUTHORIZED", "message": "Invalid or missing token."}
        })


@router.get("/api/system")
def system_info(authorization: str = Header(default="")):
    require_auth(authorization)
    config = load_config()
    return {"success": True, "data": get_system_info(config["computer_name"])}


@router.get("/api/network")
def network_info(authorization: str = Header(default="")):
    require_auth(authorization)
    config = load_config()
    return {"success": True, "data": get_network_info(config["computer_name"], get_local_ip())}


@router.get("/api/server")
def server_info(authorization: str = Header(default="")):
    require_auth(authorization)
    config = load_config()
    return {
        "success": True,
        "data": {
            "computer_name": config["computer_name"],
            "port": config["port"],
            "authentication_enabled": config["authentication_enabled"],
            "status": "ONLINE",
        },
    }