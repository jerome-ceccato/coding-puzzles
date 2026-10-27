#!/usr/bin/env python3

# Puzzle files named `input` or `input.txt` are gitignored and mirrored at the
# same relative path in the `private` submodule.

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
NAMES = {"input", "input.txt", "problem.md", "sample"}

def validate_repository(root):
    private = root / "private"
    if private.is_symlink() or not (private / ".git").is_file():
        raise ValueError("Initialize the private submodule before syncing.")

def discover(base, exclude_private=False):
    found = set()
    for folder, dirs, files in os.walk(base, followlinks=False):
        current = Path(folder)
        dirs[:] = [name for name in dirs if name != ".git"
                   and not (exclude_private and current == base and name == "private")]
        for name in dirs + files:
            path = current / name
        for name in files:
            if name in NAMES:
                path = current / name
                if not path.is_file():
                    raise ValueError(f"Expected a regular file: {path}")
                found.add(path.relative_to(base))
    return found


def safe_path(base, relative):
    path = base
    for part in relative.parts:
        path = path / part
    if path.exists() and not path.is_file():
        raise ValueError(f"Expected a regular file: {path}")
    return path


def sync(root, dry_run=False):
    validate_repository(root)
    private = root / "private"
    paths = discover(root, exclude_private=True) | discover(private)
    actions = []
    conflicts = []

    for relative in sorted(paths):
        local = safe_path(root, relative)
        stored = safe_path(private, relative)
        if local.exists() and stored.exists():
            if local.read_bytes() == stored.read_bytes():
                continue
            
            conflicts.append(relative)
            continue
        elif local.exists():
            source, destination = local, stored
        else:
            source, destination = stored, local
        actions.append((source, destination, relative))

    for relative in conflicts:
        print(f"Conflict: {relative}")
    if conflicts:
        print("No files copied; resolve conflicts first.")
        return 1

    for source, destination, relative in actions:
        direction = "Import" if source.is_relative_to(private) else "Export"
        print(f"{'Would ' if dry_run else ''}{direction}: {relative}")
        if not dry_run:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    print(f"{len(actions)} file(s) {'to copy' if dry_run else 'copied'}.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="preview without copying")
    args = parser.parse_args()

    try:
        return sync(ROOT, args.dry_run)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
