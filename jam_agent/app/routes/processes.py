from fastapi import APIRouter, Header, HTTPException

from app.authentication import is_token_valid
from app.services.process_service import list_processes

router = APIRouter()


def require_auth(authorization: str):
    token = authorization.replace("Bearer ", "").strip()
    if not is_token_valid(token):
        raise HTTPException(status_code=401, detail={
            "success": False,
            "error": {"code": "UNAUTHORIZED", "message": "Invalid or missing token."}
        })


@router.get("/api/processes")
def get_processes(authorization: str = Header(default="")):
    require_auth(authorization)
    return {"success": True, "data": {"processes": list_processes()}}