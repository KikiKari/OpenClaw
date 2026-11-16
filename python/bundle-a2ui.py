#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "01e80aa5a52733c10275be87da96fb884556a48b6b7ed15d57bb20750f1dbac9", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "python"}
# bundle-a2ui.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import hashlib
import os
import subprocess
import sys
from pathlib import Path

# Determine root directory
script_dir = Path(__file__).resolve().parent
root_dir = script_dir.parent
hash_file = root_dir / "src" / "canvas-host" / "a2ui" / ".bundle.hash"
output_file = root_dir / "src" / "canvas-host" / "a2ui" / "a2ui.bundle.js"
a2ui_renderer_dir = root_dir / "vendor" / "a2ui" / "renderers" / "lit"
a2ui_app_dir = root_dir / "apps" / "shared" / "OpenClawKit" / "Tools" / "CanvasA2UI"
input_paths = [
    root_dir / "package.json",
    root_dir / "pnpm-lock.yaml",
    a2ui_renderer_dir,
    a2ui_app_dir,
]
ignored_bundle_hash_input_prefixes = ["vendor/a2ui/renderers/lit/dist"]
relative_input_paths = [str(p.relative_to(root_dir)).replace(os.sep, "/") for p in input_paths]


def fail(message):
    print(message, file=sys.stderr)
    print("A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle", file=sys.stderr)
    print("If this persists, verify pnpm deps and try again.", file=sys.stderr)
    sys.exit(1)


def path_exists(target_path):
    return target_path.exists()


def normalize_path(file_path):
    return str(file_path).replace(os.sep, "/")


def is_bundle_hash_input_path(file_path, repo_root=root_dir):
    relative_path = normalize_path(Path(file_path).relative_to(repo_root))
    for ignored_path in ignored_bundle_hash_input_prefixes:
        if relative_path == ignored_path or relative_path.startswith(f"{ignored_path}/"):
            return False
    return True


def get_local_rolldown_cli_candidates(repo_root=root_dir):
    return [
        repo_root / "node_modules" / "rolldown" / "bin" / "cli.mjs",
        repo_root / "node_modules" / ".pnpm" / "node_modules" / "rolldown" / "bin" / "cli.mjs",
        repo_root / "node_modules" / ".pnpm" / "rolldown@1.0.0-rc.12" / "node_modules" / "rolldown" / "bin" / "cli.mjs",
    ]


def walk_files(entry_path, files):
    if not is_bundle_hash_input_path(entry_path):
        return
    if not entry_path.is_dir():
        files.append(entry_path)
        return
    for entry in entry_path.iterdir():
        walk_files(entry, files)


def list_tracked_input_files():
    try:
        result = subprocess.run(
            ["git", "ls-files", "--"] + relative_input_paths,
            cwd=root_dir,
            capture_output=True,
            text=True,
            check=True
        )
        files = []
        for line in result.stdout.strip().split("\n"):
            if line:
                full_path = root_dir / line
                if is_bundle_hash_input_path(full_path):
                    files.append(full_path)
        return files
    except subprocess.CalledProcessError:
        return None


def compute_hash():
    files = list_tracked_input_files()
    if files is None:
        files = []
        for input_path in input_paths:
            walk_files(input_path, files)
    
    files.sort(key=lambda f: normalize_path(f.relative_to(root_dir)))
    
    hasher = hashlib.sha256()
    for file_path in files:
        rel_path = normalize_path(file_path.relative_to(root_dir))
        hasher.update(rel_path.encode('utf-8'))
        hasher.update(b"\0")
        hasher.update(file_path.read_bytes())
        hasher.update(b"\0")
    return hasher.hexdigest()


def run_step(command, args, **kwargs):
    full_args = [command] + args
    result = subprocess.run(full_args, cwd=root_dir, **kwargs)
    if result.returncode != 0:
        sys.exit(result.returncode or 1)


def run_pnpm(pnpm_args):
    # Simplified pnpm runner resolution - adjust based on actual logic if needed
    run_step("pnpm", pnpm_args)


async def main():
    has_renderer_dir = path_exists(a2ui_renderer_dir)
    has_app_dir = path_exists(a2ui_app_dir)
    has_output_file = path_exists(output_file)
    
    if not has_renderer_dir or not has_app_dir:
        if has_output_file:
            print("A2UI sources missing; keeping prebuilt bundle.")
            return
        if os.environ.get("OPENCLAW_SPARSE_PROFILE") or os.environ.get("OPENCLAW_A2UI_SKIP_MISSING") == "1":
            print("A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set.")
            return
        fail(f"A2UI sources missing and no prebuilt bundle found at: {output_file}")
    
    current_hash = compute_hash()
    
    if path_exists(hash_file):
        previous_hash = hash_file.read_text(encoding="utf-8").strip()
        if previous_hash == current_hash and has_output_file:
            print("A2UI bundle up to date; skipping.")
            return
    
    run_pnpm(["-s", "exec", "tsc", "-p", str(a2ui_renderer_dir / "tsconfig.json")])
    
    local_rolldown_cli_candidates = get_local_rolldown_cli_candidates(root_dir)
    local_rolldown_cli = None
    for candidate in local_rolldown_cli_candidates:
        if path_exists(candidate):
            local_rolldown_cli = candidate
            break
    
    if local_rolldown_cli:
        run_step(sys.executable, [str(local_rolldown_cli), "-c", str(a2ui_app_dir / "rolldown.config.mjs")])
    else:
        run_pnpm(["-s", "exec", "rolldown", "-c", str(a2ui_app_dir / "rolldown.config.mjs")])
    
    hash_file.write_text(f"{current_hash}\n", encoding="utf-8")


if __name__ == "__main__":
    try:
        import asyncio
        asyncio.run(main())
    except Exception as e:
        fail(str(e) if not isinstance(e, Exception) else e.args[0] if e.args else "Unknown error")
