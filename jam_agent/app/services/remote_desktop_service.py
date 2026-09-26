import base64
import io
import time

import mss
import pyautogui
from PIL import Image

pyautogui.FAILSAFE = False  # moving mouse to corner shouldn't abort remote control


def capture_frame(quality: str = "medium", monitor_index: int = 1) -> str:
    """Captures the screen and returns a base64-encoded JPEG string."""
    quality_map = {
        "low": (0.5, 40),
        "medium": (0.75, 60),
        "high": (1.0, 80),
    }
    scale, jpeg_quality = quality_map.get(quality, quality_map["medium"])

    with mss.mss() as sct:
        monitor = sct.monitors[monitor_index]
        raw = sct.grab(monitor)
        img = Image.frombytes("RGB", raw.size, raw.rgb)

        if scale != 1.0:
            new_size = (int(img.width * scale), int(img.height * scale))
            img = img.resize(new_size, Image.BILINEAR)

        buffer = io.BytesIO()
        img.save(buffer, format="JPEG", quality=jpeg_quality)
        return base64.b64encode(buffer.getvalue()).decode("ascii")


def get_screen_size() -> tuple[int, int]:
    with mss.mss() as sct:
        monitor = sct.monitors[1]
        return monitor["width"], monitor["height"]


def get_monitor_count() -> int:
    with mss.mss() as sct:
        return len(sct.monitors) - 1  # index 0 is "all monitors combined"


def move_mouse(x: int, y: int):
    pyautogui.moveTo(x, y, _pause=False)


def click_mouse(x: int, y: int, button: str = "left"):
    pyautogui.click(x=x, y=y, button=button, _pause=False)


def drag_mouse(x: int, y: int):
    pyautogui.dragTo(x, y, button="left", _pause=False)


def scroll_mouse(amount: int):
    pyautogui.scroll(amount, _pause=False)


_KEY_MAP = {
    "ENTER": "enter",
    "BACKSPACE": "backspace",
    "SHIFT": "shift",
    "CTRL": "ctrl",
    "ALT": "alt",
    "WIN": "win",
    "TAB": "tab",
    "ESC": "esc",
    "UP": "up",
    "DOWN": "down",
    "LEFT": "left",
    "RIGHT": "right",
    "SPACE": "space",
}


def send_key(key: str):
    mapped = _KEY_MAP.get(key.upper())
    if mapped:
        pyautogui.press(mapped, _pause=False)
    elif len(key) == 1:
        pyautogui.typewrite(key, _pause=False)


def send_text(text: str):
    pyautogui.typewrite(text, _pause=False)