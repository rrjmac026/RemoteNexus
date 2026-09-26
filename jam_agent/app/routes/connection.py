from fastapi import APIRouter

router = APIRouter()


@router.get("/api/health")
def health_check():
    return {
        "success": True,
        "data": {
            "status": "ONLINE",
            "message": "JAM Agent is running"
        }
    }