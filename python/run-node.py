#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "2cf5edf0a82d43d6c7bb13c37f35c0e1c025a4e4d87c4c07247db3234d667a54", "source_sha256": "a06acfb1e69451fcfc8e5635f9059bac455efbbaca76e0edae285b866e7f8409", "target_language": "python"}
# run-node.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-node.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Callable, Union

# Import modules that would be in separate files
# For this translation, we'll include their functionality inline

# Constants from build-stamp.mjs
def resolve_git_head(cwd: str) -> Optional[str]:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=cwd,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    return None

def write_dist_build_stamp(cwd: str, fs_module=None):
    dist_root = Path(cwd) / "dist"
    build_stamp_path = dist_root / ".buildstamp"
    
    head = resolve_git_head(cwd)
    content = {"head": head} if head else {}
    
    try:
        build_stamp_path.write_text(json.dumps(content))
    except:
        pass

# Constants from bundled-plugin-paths.mjs
BUNDLED_PLUGIN_PATH_PREFIX = "bundled-plugins/"
BUNDLED_PLUGIN_ROOT_DIR = "bundled-plugins"

# Runtime postbuild functionality
def run_runtime_post_build(cwd: str):
    # Placeholder - implement actual runtime postbuild logic here
    pass

# Constants from original file
build_script = "scripts/tsdown-build.mjs"
compiler_args = [build_script, "--no-clean"]

run_node_source_roots = ["src", BUNDLED_PLUGIN_ROOT_DIR]
run_node_config_files = ["tsconfig.json", "package.json", "tsdown.config.ts"]
run_node_watched_paths = run_node_source_roots + run_node_config_files
extension_source_file_pattern = r'.*\.(?:[cm]?[jt]sx?)$'
extension_restart_metadata_files = {"openclaw.plugin.json", "package.json"}

def normalize_path(file_path: Optional[str]) -> str:
    if file_path is None:
        return ""
    return str(file_path).replace("\\", "/")

def is_ignored_source_path(relative_path: str) -> bool:
    normalized_path = normalize_path(relative_path)
    return (
        normalized_path.endswith(".test.ts") or
        normalized_path.endswith(".test.tsx") or
        normalized_path.endswith("test-helpers.ts")
    )

def is_build_relevant_source_path(relative_path: str) -> bool:
    import re
    normalized_path = normalize_path(relative_path)
    return bool(re.match(extension_source_file_pattern, normalized_path)) and not is_ignored_source_path(normalized_path)

def is_build_relevant_run_node_path(repo_path: str) -> bool:
    normalized_path = normalize_path(repo_path).lstrip("./")
    if normalized_path in run_node_config_files:
        return True
    if normalized_path.startswith("src/"):
        return not is_ignored_source_path(normalized_path[len("src/"):])
    if normalized_path.startswith(BUNDLED_PLUGIN_PATH_PREFIX):
        return is_build_relevant_source_path(normalized_path[len(BUNDLED_PLUGIN_PATH_PREFIX):])
    return False

def is_restart_relevant_extension_path(relative_path: str) -> bool:
    import posixpath
    normalized_path = normalize_path(relative_path)
    basename = posixpath.basename(normalized_path)
    if basename in extension_restart_metadata_files:
        return True
    return is_build_relevant_source_path(normalized_path)

def is_restart_relevant_run_node_path(repo_path: str) -> bool:
    normalized_path = normalize_path(repo_path).lstrip("./")
    if normalized_path in run_node_config_files:
        return True
    if normalized_path.startswith("src/"):
        return not is_ignored_source_path(normalized_path[len("src/"):])
    if normalized_path.startswith(BUNDLED_PLUGIN_PATH_PREFIX):
        return is_restart_relevant_extension_path(normalized_path[len(BUNDLED_PLUGIN_PATH_PREFIX):])
    return False

def stat_mtime(file_path: str, fs_impl=None) -> Optional[float]:
    try:
        if fs_impl:
            # Custom filesystem implementation
            return fs_impl.stat(file_path).st_mtime * 1000
        else:
            return Path(file_path).stat().st_mtime * 1000
    except:
        return None

def is_excluded_source(file_path: str, source_root: str, source_root_name: str) -> bool:
    from pathlib import Path
    relative_path = normalize_path(str(Path(file_path).relative_to(source_root)))
    if relative_path.startswith(".."):
        return False
    import posixpath
    return not is_build_relevant_run_node_path(posixpath.join(source_root_name, relative_path))

def find_latest_mtime(dir_path: str, should_skip: Optional[Callable[[str], bool]], deps: Dict) -> Optional[float]:
    import os
    latest = None
    queue = [dir_path]
    
    while queue:
        current = queue.pop()
        if not current:
            continue
            
        try:
            entries = []
            if 'fs' in deps:
                entries = deps['fs'].listdir(current)
            else:
                entries = os.listdir(current)
                
            for entry in entries:
                full_path = os.path.join(current, entry)
                if os.path.isdir(full_path):
                    queue.append(full_path)
                    continue
                if not os.path.isfile(full_path):
                    continue
                if should_skip and should_skip(full_path):
                    continue
                    
                mtime = stat_mtime(full_path, deps.get('fs'))
                if mtime is None:
                    continue
                if latest is None or mtime > latest:
                    latest = mtime
        except:
            continue
            
    return latest

def read_git_status(deps: Dict) -> Optional[str]:
    try:
        cmd = ["git", "status", "--porcelain", "--untracked-files=normal", "--"] + run_node_watched_paths
        result = subprocess.run(
            cmd,
            cwd=deps['cwd'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return result.stdout or ""
    except:
        pass
    return None

def parse_git_status_paths(output: str) -> List[str]:
    paths = []
    for line in output.split("\n"):
        parts = line[3:].split(" -> ")
        for entry in parts:
            normalized = normalize_path(entry.strip())
            if normalized:
                paths.append(normalized)
    return paths

def has_dirty_source_tree(deps: Dict) -> Optional[bool]:
    output = read_git_status(deps)
    if output is None:
        return None
        
    paths = parse_git_status_paths(output)
    for repo_path in paths:
        if is_build_relevant_run_node_path(repo_path):
            return True
    return False

def read_build_stamp(deps: Dict) -> Dict[str, Optional[Union[float, str]]]:
    mtime = stat_mtime(deps['build_stamp_path'], deps.get('fs'))
    if mtime is None:
        return {"mtime": None, "head": None}
        
    try:
        if 'fs' in deps:
            raw = deps['fs'].read_text(deps['build_stamp_path']).strip()
        else:
            raw = Path(deps['build_stamp_path']).read_text().strip()
            
        if not raw.startswith("{"):
            return {"mtime": mtime, "head": None}
            
        parsed = json.loads(raw)
        head = parsed.get('head', '') if isinstance(parsed.get('head'), str) else ''
        head = head.strip() if head else None
        return {"mtime": mtime, "head": head}
    except:
        return {"mtime": mtime, "head": None}

def has_source_mtime_changed(stamp_mtime: float, deps: Dict) -> bool:
    latest_source_mtime = None
    
    for source_root in deps['source_roots']:
        def skip_func(candidate):
            return is_excluded_source(candidate, source_root['path'], source_root['name'])
            
        source_mtime = find_latest_mtime(source_root['path'], skip_func, deps)
        if source_mtime is not None and (latest_source_mtime is None or source_mtime > latest_source_mtime):
            latest_source_mtime = source_mtime
            
    return latest_source_mtime is not None and latest_source_mtime > stamp_mtime

def resolve_build_requirement(deps: Dict) -> Dict[str, Union[bool, str]]:
    if deps['env'].get('OPENCLAW_FORCE_BUILD') == '1':
        return {"shouldBuild": True, "reason": "force_build"}
        
    stamp = read_build_stamp(deps)
    if stamp["mtime"] is None:
        return {"shouldBuild": True, "reason": "missing_build_stamp"}
        
    if stat_mtime(deps['dist_entry'], deps.get('fs')) is None:
        return {"shouldBuild": True, "reason": "missing_dist_entry"}
        
    for file_path in deps['config_files']:
        mtime = stat_mtime(file_path, deps.get('fs'))
        if mtime is not None and mtime > stamp["mtime"]:
            return {"shouldBuild": True, "reason": "config_newer"}
            
    current_head = resolve_git_head(deps['cwd'])
    if current_head and not stamp["head"]:
        return {"shouldBuild": True, "reason": "build_stamp_missing_head"}
    if current_head and stamp["head"] and current_head != stamp["head"]:
        return {"shouldBuild": True, "reason": "git_head_changed"}
    if current_head:
        dirty = has_dirty_source_tree(deps)
        if dirty is True:
            return {"shouldBuild": True, "reason": "dirty_watched_tree"}
        if dirty is False:
            return {"shouldBuild": False, "reason": "clean"}
            
    if has_source_mtime_changed(stamp["mtime"], deps):
        return {"shouldBuild": True, "reason": "source_mtime_newer"}
        
    return {"shouldBuild": False, "reason": "clean"}

BUILD_REASON_LABELS = {
    "force_build": "forced by OPENCLAW_FORCE_BUILD",
    "missing_build_stamp": "build stamp missing",
    "missing_dist_entry": "dist entry missing",
    "config_newer": "config newer than build stamp",
    "build_stamp_missing_head": "build stamp missing git head",
    "git_head_changed": "git head changed",
    "dirty_watched_tree": "dirty watched source tree",
    "source_mtime_newer": "source mtime newer than build stamp",
    "clean": "clean",
}

def format_build_reason(reason: str) -> str:
    return BUILD_REASON_LABELS.get(reason, reason)

SIGNAL_EXIT_CODES = {
    "SIGINT": 130,
    "SIGTERM": 143,
}

def is_signal_key(signal: str) -> bool:
    return signal in SIGNAL_EXIT_CODES

def get_signal_exit_code(signal: str) -> int:
    return SIGNAL_EXIT_CODES.get(signal, 1) if is_signal_key(signal) else 1

def log_runner(message: str, deps: Dict):
    if deps['env'].get('OPENCLAW_RUNNER_LOG') == '0':
        return
    deps['stderr'].write(f"[openclaw] {message}\n")
    deps['stderr'].flush()

def wait_for_spawned_process(child_process, deps: Dict):
    import signal
    
    forwarded_signal = None
    sigint_handler = None
    sigterm_handler = None
    
    def cleanup_signals():
        if sigint_handler:
            signal.signal(signal.SIGINT, sigint_handler)
        if sigterm_handler:
            signal.signal(signal.SIGTERM, sigterm_handler)
    
    def forward_signal(sig, frame=None):
        nonlocal forwarded_signal
        if forwarded_signal:
            return
        forwarded_signal = sig
        try:
            child_process.terminate() if sig == signal.SIGTERM else child_process.send_signal(sig)
        except:
            pass
    
    def handle_sigint(sig, frame):
        forward_signal(signal.SIGINT)
        
    def handle_sigterm(sig, frame):
        forward_signal(signal.SIGTERM)
    
    # Store original handlers
    sigint_handler = signal.signal(signal.SIGINT, handle_sigint)
    sigterm_handler = signal.signal(signal.SIGTERM, handle_sigterm)
    
    try:
        exit_code = child_process.wait()
        cleanup_signals()
        return {"exitCode": exit_code, "exitSignal": None, "forwardedSignal": forwarded_signal}
    except KeyboardInterrupt:
        cleanup_signals()
        return {"exitCode": None, "exitSignal": "SIGINT", "forwardedSignal": forwarded_signal}

def run_open_claw(deps: Dict) -> int:
    cmd = [deps['exec_path'], "openclaw.mjs"] + deps['args']
    try:
        child_process = subprocess.Popen(
            cmd,
            cwd=deps['cwd'],
            env=deps['env'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.PIPE
        )
        res = wait_for_spawned_process(child_process, deps)
        
        if res["exitSignal"]:
            return get_signal_exit_code(res["exitSignal"])
        if res["forwardedSignal"]:
            return get_signal_exit_code(res["forwardedSignal"])
        return res["exitCode"] if res["exitCode"] is not None else 1
    except Exception as e:
        log_runner(f"Failed to start openclaw: {str(e)}", deps)
        return 1

def sync_runtime_artifacts(deps: Dict) -> bool:
    try:
        deps['run_runtime_post_build'](deps['cwd'])
        return True
    except Exception as error:
        log_runner(f"Failed to write runtime build artifacts: {getattr(error, 'message', str(error))}", deps)
        return False

def write_build_stamp(deps: Dict):
    try:
        write_dist_build_stamp(deps['cwd'])
    except Exception as error:
        log_runner(f"Failed to write build stamp: {getattr(error, 'message', str(error))}", deps)

def should_skip_clean_watch_runtime_sync(deps: Dict) -> bool:
    return deps['env'].get('OPENCLAW_WATCH_MODE') == '1'

async def run_node_main(params: Dict = None) -> int:
    if params is None:
        params = {}
        
    deps = {
        'spawn': params.get('spawn', subprocess.Popen),
        'spawn_sync': params.get('spawn_sync', subprocess.run),
        'fs': params.get('fs'),
        'stderr': params.get('stderr', sys.stderr),
        'process': params.get('process', {}),
        'exec_path': params.get('exec_path', sys.executable),
        'cwd': params.get('cwd', os.getcwd()),
        'args': params.get('args', sys.argv[2:]),
        'env': dict(params.get('env', os.environ)) if params.get('env') else dict(os.environ),
        'run_runtime_post_build': params.get('run_runtime_post_build', run_runtime_post_build),
    }
    
    deps['dist_root'] = os.path.join(deps['cwd'], "dist")
    deps['dist_entry'] = os.path.join(deps['dist_root'], "entry.js")
    deps['build_stamp_path'] = os.path.join(deps['dist_root'], ".buildstamp")
    deps['source_roots'] = [
        {"name": source_root, "path": os.path.join(deps['cwd'], source_root)}
        for source_root in run_node_source_roots
    ]
    deps['config_files'] = [
        os.path.join(deps['cwd'], file_path)
        for file_path in run_node_config_files
    ]
    
    build_requirement = resolve_build_requirement(deps)
    if not build_requirement["shouldBuild"]:
        if not should_skip_clean_watch_runtime_sync(deps) and not sync_runtime_artifacts(deps):
            return 1
        return await run_open_claw(deps)
        
    log_runner(
        f"Building TypeScript (dist is stale: {build_requirement['reason']} - {format_build_reason(build_requirement['reason'])}).",
        deps
    )
    
    build_cmd = deps['exec_path']
    build_args = [sys.executable, build_script] + compiler_args[1:]  # Adjust for Python execution
    
    try:
        build_process = subprocess.Popen(
            build_args,
            cwd=deps['cwd'],
            env=deps['env'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.PIPE
        )
        build_res = wait_for_spawned_process(build_process, deps)
        
        if build_res["exitSignal"]:
            return get_signal_exit_code(build_res["exitSignal"])
        if build_res["forwardedSignal"]:
            return get_signal_exit_code(build_res["forwardedSignal"])
        if build_res["exitCode"] is not None and build_res["exitCode"] != 0:
            return build_res["exitCode"]
            
        if not sync_runtime_artifacts(deps):
            return 1
            
        write_build_stamp(deps)
        return await run_open_claw(deps)
    except Exception as e:
        log_runner(f"Build failed: {str(e)}", deps)
        return 1

if __name__ == "__main__":
    import asyncio
    try:
        code = asyncio.run(run_node_main())
        sys.exit(code)
    except Exception as err:
        print(err, file=sys.stderr)
        sys.exit(1)
