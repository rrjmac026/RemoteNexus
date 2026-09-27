import os
import shutil
from pathlib import Path

from app.config import load_config


class PathSecurityError(Exception):
    pass


def _get_drives() -> dict[str, Path]:
    config = load_config()
    return {label: Path(root).resolve() for label, root in config["shared_drives"].items()}


def resolve_safe_path(relative_path: str) -> Path:
    """
    A relative_path looks like 'C', 'C/Users/Jam', 'F/JAM-Server', or '' (virtual root).
    The first segment must be a known drive label. Guarantees the result stays
    inside that drive's real root.
    """
    relative_path = (relative_path or "").strip().strip("/\\")
    drives = _get_drives()

    if relative_path == "":
        # Virtual root — not a real filesystem path, handled specially by callers.
        raise IsADirectoryError("ROOT")

    parts = relative_path.replace("\\", "/").split("/")
    label = parts[0]

    if label not in drives:
        raise PathSecurityError(f"Unknown drive: {label}")

    drive_root = drives[label]
    sub_path = "/".join(parts[1:])

    candidate = (drive_root / sub_path).resolve() if sub_path else drive_root

    try:
        candidate.relative_to(drive_root)
    except ValueError:
        raise PathSecurityError(f"Path escapes drive {label}: {relative_path}")

    return candidate


def list_directory(relative_path: str) -> list[dict]:
    relative_path = (relative_path or "").strip().strip("/\\")

    if relative_path == "":
        # Virtual root: list the configured drives themselves as folders.
        drives = _get_drives()
        return [
            {"name": label, "is_directory": True, "size": None, "modified": 0}
            for label in sorted(drives.keys())
        ]

    target = resolve_safe_path(relative_path)

    if not target.exists():
        raise FileNotFoundError(f"Directory not found: {relative_path}")
    if not target.is_dir():
        raise NotADirectoryError(f"Not a directory: {relative_path}")

    items = []
    for entry in sorted(target.iterdir(), key=lambda e: (not e.is_dir(), e.name.lower())):
        try:
            stat = entry.stat()
            items.append({
                "name": entry.name,
                "is_directory": entry.is_dir(),
                "size": stat.st_size if entry.is_file() else None,
                "modified": stat.st_mtime,
            })
        except (PermissionError, OSError):
            continue  # skip files/folders we can't read (system-protected, etc.)
    return items


def create_directory(relative_path: str):
    target = resolve_safe_path(relative_path)
    if target.exists():
        raise FileExistsError(f"Already exists: {relative_path}")
    target.mkdir(parents=True, exist_ok=False)


def rename_item(relative_path: str, new_name: str):
    if "/" in new_name or "\\" in new_name:
        raise PathSecurityError("New name must not contain path separators.")

    target = resolve_safe_path(relative_path)
    if not target.exists():
        raise FileNotFoundError(f"Not found: {relative_path}")

    destination = target.parent / new_name
    if destination.exists():
        raise FileExistsError(f"Already exists: {new_name}")

    target.rename(destination)


def delete_item(relative_path: str):
    target = resolve_safe_path(relative_path)
    if not target.exists():
        raise FileNotFoundError(f"Not found: {relative_path}")

    if target.is_dir():
        shutil.rmtree(target)
    else:
        target.unlink()


def get_file_path_for_download(relative_path: str) -> Path:
    target = resolve_safe_path(relative_path)
    if not target.exists() or not target.is_file():
        raise FileNotFoundError(f"File not found: {relative_path}")
    return target


def save_uploaded_file(relative_dir: str, filename: str, content: bytes) -> str:
    if "/" in filename or "\\" in filename:
        raise PathSecurityError("Filename must not contain path separators.")

    target_dir = resolve_safe_path(relative_dir)
    if not target_dir.exists():
        raise FileNotFoundError(f"Target directory not found: {relative_dir}")
    if not target_dir.is_dir():
        raise NotADirectoryError(f"Not a directory: {relative_dir}")

    destination = target_dir / filename
    with open(destination, "wb") as f:
        f.write(content)

    return str(destination)