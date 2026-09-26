from fastapi import APIRouter, Header, HTTPException, Query

from app.authentication import is_token_valid
from app.logging_config import read_recent_logs

router = APIRouter()


def require_auth(authorization: str):
    token = authorization.replace("Bearer ", "").strip()
    if not is_token_valid(token):
        raise HTTPException(status_code=401, detail={
            "success": False,
            "error": {"code": "UNAUTHORIZED", "message": "Invalid or missing token."}
        })


@router.get("/api/logs")
def get_logs(limit: int = Query(default=50), authorization: str = Header(default="")):
    require_auth(authorization)
    return {"success": True, "data": {"entries": read_recent_logs(limit)}}