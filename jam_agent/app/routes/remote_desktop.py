import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.authentication import is_token_valid
from app.services import remote_desktop_service as rds

router = APIRouter()


@router.websocket("/ws/remote-desktop")
async def remote_desktop_socket(websocket: WebSocket):
    await websocket.accept()

    # First message must be an auth token
    try:
        auth_msg = await asyncio.wait_for(websocket.receive_text(), timeout=5)
        auth_data = json.loads(auth_msg)
        token = auth_data.get("token", "")
    except Exception:
        await websocket.close(code=4001)
        return

    if not is_token_valid(token):
        await websocket.close(code=4003)
        return

    quality = "medium"
    frame_delay = 1 / 15  # default 15 FPS
    monitor_index = 1
    running = True

    async def send_frames():
        nonlocal quality, frame_delay, monitor_index, running
        while running:
            try:
                frame = rds.capture_frame(quality=quality, monitor_index=monitor_index)
                await websocket.send_json({"type": "frame", "data": frame})
            except Exception:
                pass
            await asyncio.sleep(frame_delay)

    async def receive_input():
        nonlocal quality, frame_delay, monitor_index, running
        while running:
            try:
                message = await websocket.receive_text()
            except WebSocketDisconnect:
                running = False
                break
            except Exception:
                running = False
                break

            try:
                event = json.loads(message)
            except json.JSONDecodeError:
                continue

            event_type = event.get("type")

            if event_type == "move":
                rds.move_mouse(event["x"], event["y"])
            elif event_type == "click":
                rds.click_mouse(event["x"], event["y"], event.get("button", "left"))
            elif event_type == "drag":
                rds.drag_mouse(event["x"], event["y"])
            elif event_type == "scroll":
                rds.scroll_mouse(event.get("amount", -3))
            elif event_type == "key":
                rds.send_key(event["key"])
            elif event_type == "text":
                rds.send_text(event["text"])
            elif event_type == "set_quality":
                quality = event.get("quality", "medium")
            elif event_type == "set_fps":
                fps = event.get("fps", 15)
                frame_delay = 1 / max(fps, 1)
            elif event_type == "set_monitor":
                monitor_index = event.get("index", 1)

    frame_task = asyncio.create_task(send_frames())
    input_task = asyncio.create_task(receive_input())

    await asyncio.wait([frame_task, input_task], return_when=asyncio.FIRST_COMPLETED)

    running = False
    frame_task.cancel()
    input_task.cancel()


@router.get("/api/remote-desktop/info")
def remote_desktop_info(authorization: str = ""):
    from app.authentication import is_token_valid as valid
    token = authorization.replace("Bearer ", "").strip()
    if not valid(token):
        return {"success": False, "error": {"code": "UNAUTHORIZED", "message": "Invalid token."}}

    width, height = rds.get_screen_size()
    monitors = rds.get_monitor_count()
    return {"success": True, "data": {"width": width, "height": height, "monitor_count": monitors}}