import threading

import uvicorn
from fastapi import FastAPI

from app.config import load_config, get_local_ip
from app.authentication import console_listener
from app.routes.connection import router as connection_router
from app.routes.authentication import router as auth_router
from app.routes.system import router as system_router
from app.routes.terminal import router as terminal_router
from app.routes.files import router as files_router
from app.routes.processes import router as processes_router
from app.routes.services import router as services_router
from app.routes.logs import router as logs_router
from app.routes.remote_desktop import router as remote_desktop_router


app = FastAPI(title="JAM Remote Agent")
app.include_router(connection_router)
app.include_router(auth_router)
app.include_router(system_router)
app.include_router(terminal_router)
app.include_router(files_router)
app.include_router(processes_router)
app.include_router(services_router)
app.include_router(logs_router)
app.include_router(remote_desktop_router)



def print_banner(config: dict, local_ip: str):
    print("=" * 40)
    print("          JAM REMOTE AGENT")
    print("=" * 40)
    print()
    print("Computer:")
    print(config["computer_name"])
    print()
    print("Local IP:")
    print(local_ip)
    print()
    print("Port:")
    print(config["port"])
    print()
    print("Mode:")
    print("LAN")
    print()
    print("Authentication:")
    print("ENABLED" if config["authentication_enabled"] else "DISABLED")
    print()
    print("Status:")
    print("ONLINE")
    print()
    print("=" * 40)
    print()
    print("Waiting for authorized devices...")
    print("(type 'devices' to list paired devices)")
    print()


if __name__ == "__main__":
    config = load_config()
    local_ip = get_local_ip()
    print_banner(config, local_ip)

    listener_thread = threading.Thread(target=console_listener, daemon=True)
    listener_thread.start()

    uvicorn.run(app, host=config["host"], port=config["port"], log_level="warning")