import os
import shutil
from pathlib import Path

from app.config import load_config


class PathSecurityError(Exception):
    pass


def _get_shared_root() -> Path:
    config = load_config()
    return Path(config["shared_directory"]).resolve()


def resolve_safe_path(relative_path: str) -> Path:
    """
    Resolves a client-supplied relative path against the shared root,
    and guarantees the result stays inside it. Raises PathSecurityError
    if the path attempts to escape the shared directory.
    """
    root = _get_shared_root()
    relative_path = (relative_path or "").strip().lstrip("/\\")

    candidate = (root / relative_path).resolve()

    try:
        candidate.relative_to(root)
    except ValueError:
        raise PathSecurityError(f"Path escapes shared directory: {relative_path}")

    return candidate


def list_directory(relative_path: str) -> list[dict]:
    target = resolve_safe_path(relative_path)

    if not target.exists():
        raise FileNotFoundError(f"Directory not found: {relative_path}")
    if not target.is_dir():
        raise NotADirectoryError(f"Not a directory: {relative_path}")

    items = []
    for entry in sorted(target.iterdir(), key=lambda e: (not e.is_dir(), e.name.lower())):
        stat = entry.stat()
        items.append({
            "name": entry.name,
            "is_directory": entry.is_dir(),
            "size": stat.st_size if entry.is_file() else None,
            "modified": stat.st_mtime,
        })
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
    resolve_safe_path(str(destination.relative_to(_get_shared_root())))

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