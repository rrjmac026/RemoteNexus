from fastapi import APIRouter, Header
from pydantic import BaseModel
from app.authentication import create_pairing_request, get_request_status, is_token_valid

router = APIRouter()


class PairRequest(BaseModel):
    device_name: str
    ip: str


@router.post("/api/auth/pair")
def request_pairing(body: PairRequest):
    result = create_pairing_request(body.device_name, body.ip)
    return {"success": True, "data": result}


@router.get("/api/auth/pair/status/{request_id}")
def pairing_status(request_id: str):
    req = get_request_status(request_id)
    if not req:
        return {"success": False, "error": {"code": "NOT_FOUND", "message": "Unknown request."}}

    data = {"status": req["status"]}
    if req["status"] == "approved":
        data["token"] = req["token"]

    return {"success": True, "data": data}


@router.get("/api/auth/check")
def check_token(authorization: str = Header(default="")):
    token = authorization.replace("Bearer ", "").strip()
    valid = is_token_valid(token)
    return {"success": True, "data": {"valid": valid}}