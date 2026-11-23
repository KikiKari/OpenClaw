#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "3df8bbe8a1fdb7d938b92372a4c7b8019c6bc24e83c411ca3d85e3813525c8f8", "source_sha256": "dc65d4759ce1efe8d0c6f037b64d65c1aa1f73b83a3cd928ceebdaf24ed53da6", "target_language": "python"}
# stage-bundled-plugin-runtime.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/stage-bundled-plugin-runtime.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import shutil
from pathlib import Path


def symlink_type():
    return "junction" if sys.platform == "win32" else "dir"


def relative_symlink_target(source_path, target_path):
    source_path_obj = Path(source_path)
    target_path_obj = Path(target_path)
    try:
        relative_target = os.path.relpath(source_path_obj, target_path_obj.parent)
    except ValueError:
        # Fallback to absolute path if relpath fails (different drives on Windows)
        relative_target = str(source_path_obj)
    return relative_target or "."


def should_fallback_to_copy(error):
    return (
        sys.platform == "win32"
        and isinstance(error, OSError)
        and error.errno in (1, 13, 22)  # EPERM, EINVAL, UNKNOWN
    )


def copy_path_fallback(source_path, target_path):
    remove_path_if_exists(target_path)
    source_path_obj = Path(source_path)
    target_path_obj = Path(target_path)
    
    target_path_obj.parent.mkdir(parents=True, exist_ok=True)
    
    if source_path_obj.is_dir():
        shutil.copytree(source_path, target_path, dirs_exist_ok=True, symlinks=False)
    else:
        shutil.copy2(source_path, target_path)


def remove_path_if_exists(path):
    path_obj = Path(path)
    if path_obj.is_symlink():
        path_obj.unlink()
    elif path_obj.is_file():
        path_obj.unlink()
    elif path_obj.is_dir():
        shutil.rmtree(path)


def ensure_symlink(target_value, target_path, link_type=None, fallback_source_path=None):
    target_path_obj = Path(target_path)
    try:
        if not target_path_obj.exists() and not target_path_obj.is_symlink():
            target_path_obj.symlink_to(target_value, target_is_directory=(link_type == "dir"))
        return
    except OSError as error:
        if fallback_source_path and should_fallback_to_copy(error):
            copy_path_fallback(fallback_source_path, target_path)
            return
        if getattr(error, 'errno', None) != 17:  # EEXIST
            raise error

    try:
        if target_path_obj.is_symlink() and str(target_path_obj.readlink()) == str(target_value):
            return
    except Exception:
        # Fall through and recreate the target when inspection fails.
        pass

    remove_path_if_exists(target_path)
    try:
        target_path_obj.symlink_to(target_value, target_is_directory=(link_type == "dir"))
    except OSError as error:
        if fallback_source_path and should_fallback_to_copy(error):
            copy_path_fallback(fallback_source_path, target_path)
            return
        raise error


def symlink_path(source_path, target_path, link_type=None):
    target_value = relative_symlink_target(source_path, target_path)
    ensure_symlink(target_value, target_path, link_type, source_path)


def should_wrap_runtime_js_file(source_path):
    return Path(source_path).suffix == ".js"


def should_copy_runtime_file(source_path):
    source_path_normalized = source_path.replace("\\", "/")
    return (
        source_path_normalized.endswith("/package.json") or
        source_path_normalized.endswith("/openclaw.plugin.json") or
        source_path_normalized.endswith("/.codex-plugin/plugin.json") or
        source_path_normalized.endswith("/.claude-plugin/plugin.json") or
        source_path_normalized.endswith("/.cursor-plugin/plugin.json") or
        source_path_normalized.endswith("/SKILL.md")
    )


def write_runtime_module_wrapper(source_path, target_path):
    specifier = relative_symlink_target(source_path, target_path).replace("\\", "/")
    normalized_specifier = f"./{specifier}" if not specifier.startswith(".") else specifier
    
    content = "\n".join([
        f'export * from {repr(normalized_specifier)};',
        f'import * as module from {repr(normalized_specifier)};',
        'export default module.default;',
        ''
    ])
    
    Path(target_path).write_text(content, encoding="utf-8")


def stage_plugin_runtime_overlay(source_dir, target_dir):
    Path(target_dir).mkdir(parents=True, exist_ok=True)
    
    for item in Path(source_dir).iterdir():
        if item.name == "node_modules":
            continue
            
        source_path = item
        target_path = Path(target_dir) / item.name
        
        if item.is_dir():
            stage_plugin_runtime_overlay(str(source_path), str(target_path))
            continue
            
        if item.is_symlink():
            link_target = os.readlink(source_path)
            ensure_symlink(link_target, str(target_path), None, str(source_path))
            continue
            
        if not item.is_file():
            continue
            
        if should_wrap_runtime_js_file(str(source_path)):
            write_runtime_module_wrapper(str(source_path), str(target_path))
            continue
            
        if should_copy_runtime_file(str(source_path)):
            shutil.copy2(source_path, target_path)
            continue
            
        symlink_path(str(source_path), str(target_path))


def link_plugin_node_modules(params):
    runtime_node_modules_dir = Path(params["runtime_plugin_dir"]) / "node_modules"
    remove_path_if_exists(str(runtime_node_modules_dir))
    
    source_plugin_node_modules_dir = Path(params["source_plugin_node_modules_dir"])
    if not source_plugin_node_modules_dir.exists():
        return
        
    ensure_symlink(
        str(source_plugin_node_modules_dir),
        str(runtime_node_modules_dir),
        symlink_type(),
        str(source_plugin_node_modules_dir)
    )


def stage_bundled_plugin_runtime(params=None):
    if params is None:
        params = {}
        
    repo_root = params.get("cwd") or params.get("repoRoot") or os.getcwd()
    repo_root_path = Path(repo_root)
    dist_root = repo_root_path / "dist"
    runtime_root = repo_root_path / "dist-runtime"
    dist_extensions_root = dist_root / "extensions"
    runtime_extensions_root = runtime_root / "extensions"
    
    if not dist_extensions_root.exists():
        remove_path_if_exists(str(runtime_root))
        return
        
    remove_path_if_exists(str(runtime_root))
    runtime_extensions_root.mkdir(parents=True, exist_ok=True)
    
    if dist_extensions_root.exists():
        for item in dist_extensions_root.iterdir():
            if not item.is_dir():
                continue
                
            dist_plugin_dir = dist_extensions_root / item.name
            runtime_plugin_dir = runtime_extensions_root / item.name
            dist_plugin_node_modules_dir = dist_plugin_dir / "node_modules"
            
            stage_plugin_runtime_overlay(str(dist_plugin_dir), str(runtime_plugin_dir))
            link_plugin_node_modules({
                "runtime_plugin_dir": str(runtime_plugin_dir),
                "source_plugin_node_modules_dir": str(dist_plugin_node_modules_dir)
            })


if __name__ == "__main__":
    stage_bundled_plugin_runtime()
