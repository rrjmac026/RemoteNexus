from fastapi import APIRouter, Header, HTTPException, UploadFile, File, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.authentication import is_token_valid
from app.services import file_service
from app.logging_config import log_event

router = APIRouter()


def require_auth(authorization: str):
    token = authorization.replace("Bearer ", "").strip()
    if not is_token_valid(token):
        raise HTTPException(status_code=401, detail={
            "success": False,
            "error": {"code": "UNAUTHORIZED", "message": "Invalid or missing token."}
        })


def error_response(code: str, message: str, status: int = 400):
    raise HTTPException(status_code=status, detail={
        "success": False,
        "error": {"code": code, "message": message}
    })


class DirectoryRequest(BaseModel):
    path: str


class RenameRequest(BaseModel):
    path: str
    new_name: str


class DeleteRequest(BaseModel):
    path: str


@router.get("/api/files")
def list_files(path: str = Query(default=""), authorization: str = Header(default="")):
    require_auth(authorization)
    try:
        items = file_service.list_directory(path)
        return {"success": True, "data": {"path": path, "items": items}}
    except file_service.PathSecurityError:
        error_response("FORBIDDEN_PATH", "Path is outside the shared directory.", 403)
    except FileNotFoundError:
        error_response("NOT_FOUND", "Directory not found.", 404)
    except NotADirectoryError:
        error_response("NOT_A_DIRECTORY", "Path is not a directory.", 400)


@router.get("/api/files/download")
def download_file(path: str = Query(...), authorization: str = Header(default="")):
    require_auth(authorization)
    try:
        file_path = file_service.get_file_path_for_download(path)
        log_event(f"Downloaded:\n{path}")
        return FileResponse(file_path, filename=file_path.name)
    except file_service.PathSecurityError:
        error_response("FORBIDDEN_PATH", "Path is outside the shared directory.", 403)
    except FileNotFoundError:
        error_response("NOT_FOUND", "File not found.", 404)


@router.post("/api/files/upload")
async def upload_file(file: UploadFile = File(...), authorization: str = Header(default="")):
    require_auth(authorization)
    try:
        content = await file.read()
        saved_path = file_service.save_uploaded_file(file.filename, content)
        log_event(f"Uploaded:\n{file.filename}")
        return {"success": True, "data": {"saved_to": saved_path, "size": len(content)}}
    except file_service.PathSecurityError as e:
        error_response("INVALID_FILENAME", str(e), 400)


@router.post("/api/files/directory")
def create_directory(body: DirectoryRequest, authorization: str = Header(default="")):
    require_auth(authorization)
    try:
        file_service.create_directory(body.path)
        return {"success": True, "data": {"created": body.path}}
    except file_service.PathSecurityError:
        error_response("FORBIDDEN_PATH", "Path is outside the shared directory.", 403)
    except FileExistsError:
        error_response("ALREADY_EXISTS", "Directory already exists.", 409)


@router.post("/api/files/rename")
def rename_file(body: RenameRequest, authorization: str = Header(default="")):
    require_auth(authorization)
    try:
        file_service.rename_item(body.path, body.new_name)
        return {"success": True, "data": {"renamed": body.path, "new_name": body.new_name}}
    except file_service.PathSecurityError as e:
        error_response("FORBIDDEN_PATH", str(e), 403)
    except FileNotFoundError:
        error_response("NOT_FOUND", "Item not found.", 404)
    except FileExistsError:
        error_response("ALREADY_EXISTS", "An item with that name already exists.", 409)


@router.delete("/api/files")
def delete_file(body: DeleteRequest, authorization: str = Header(default="")):
    require_auth(authorization)
    try:
        file_service.delete_item(body.path)
        return {"success": True, "data": {"deleted": body.path}}
    except file_service.PathSecurityError:
        error_response("FORBIDDEN_PATH", "Path is outside the shared directory.", 403)
    except FileNotFoundError:
        error_response("NOT_FOUND", "Item not found.", 404)