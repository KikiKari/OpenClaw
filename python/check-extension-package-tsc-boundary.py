#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "725d3da733506fe3e163ad21cad6232ff40def291413e1659896c29029fd4449", "source_sha256": "d3c03c21143a83c5721fdec0e2390424f9c499b86d0c2744a94c154b1be4b2bc", "target_language": "python"}
# check-extension-package-tsc-boundary.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-extension-package-tsc-boundary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import asyncio
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

repo_root = Path(__file__).parent.parent.resolve()
tsc_bin = Path(__file__).parent.parent / "node_modules/typescript/bin/tsc"
prepare_boundary_artifacts_bin = Path(__file__).parent.parent / "scripts/prepare-extension-package-boundary-artifacts.mjs"
extension_package_boundary_base_config = "../tsconfig.package-boundary.base.json"
FAILURE_OUTPUT_TAIL_LINES = 40
SLOW_COMPILE_SUMMARY_LIMIT = 10
COMPILE_INPUT_EXTENSIONS = {".ts", ".tsx", ".mts", ".cts", ".js", ".mjs", ".json"}
ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH = "../../src/plugins/contracts/rootdir-boundary-canary.ts"
ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT = "src/plugins/contracts/rootdir-boundary-canary.ts"

def parse_mode(argv):
    mode_arg = next((arg for arg in argv if arg.startswith("--mode=")), None)
    mode = mode_arg[len("--mode="):] if mode_arg else "all"
    if mode not in {"all", "compile", "canary"}:
        raise ValueError(f"Unknown mode: {mode}")
    return mode

def resolve_compile_concurrency():
    raw = os.environ.get("OPENCLAW_EXTENSION_BOUNDARY_CONCURRENCY")
    try:
        parsed = int(raw) if raw else None
        if isinstance(parsed, int) and parsed > 0:
            return parsed
    except ValueError:
        pass
    
    try:
        # For Python < 3.13, we'll use a default value
        available_parallelism = getattr(os, 'process_cpu_count', lambda: 4)()
        return max(1, min(6, available_parallelism // 2))
    except AttributeError:
        return 2  # fallback default

def read_json_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)

def summarize_output_section(name, output):
    trimmed = output.strip()
    if not trimmed:
        return ""
    
    lines = trimmed.split("\n")
    if len(lines) <= FAILURE_OUTPUT_TAIL_LINES:
        return f"{name}:\n{trimmed}"
    
    omitted_line_count = len(lines) - FAILURE_OUTPUT_TAIL_LINES
    tail = "\n".join(lines[-FAILURE_OUTPUT_TAIL_LINES:])
    return f"{name}:\n[... {omitted_line_count} earlier lines omitted ...]\n{tail}"

def format_failure_footer(params=None):
    if params is None:
        params = {}
    
    footer_lines = []
    if params.get("kind"):
        footer_lines.append(f"kind: {params['kind']}")
    if "elapsedMs" in params and isinstance(params["elapsedMs"], (int, float)):
        footer_lines.append(f"elapsed: {params['elapsedMs']}ms")
    if params.get("note"):
        footer_lines.append(params["note"])
    return "\n".join(footer_lines)

def format_boundary_check_success_summary(params=None):
    if params is None:
        params = {}
    
    lines = ["extension package boundary check passed"]
    if params.get("mode"):
        lines.append(f"mode: {params['mode']}")
    if "compileCount" in params and isinstance(params["compileCount"], int):
        lines.append(f"compiled plugins: {params['compileCount']}")
    if params.get("skippedCompileCount", 0) > 0:
        lines.append(f"skipped plugins: {params['skippedCompileCount']}")
    if "canaryCount" in params and isinstance(params["canaryCount"], int):
        lines.append(f"canary plugins: {params['canaryCount']}")
    if params.get("prepElapsedMs", 0) > 0:
        lines.append(f"prep elapsed: {params['prepElapsedMs']}ms")
    if params.get("compileElapsedMs", 0) > 0:
        lines.append(f"compile elapsed: {params['compileElapsedMs']}ms")
    if params.get("canaryElapsedMs", 0) > 0:
        lines.append(f"canary elapsed: {params['canaryElapsedMs']}ms")
    if "elapsedMs" in params:
        lines.append(f"elapsed: {params['elapsedMs']}ms")
    return "\n".join(lines) + "\n"

def format_skipped_compile_progress(params=None):
    if params is None:
        params = {}
    
    skipped_count = params.get("skippedCount", 0)
    total_count = params.get("totalCount", 0)
    
    if not isinstance(skipped_count, int) or skipped_count <= 0:
        return ""
    
    stale_count = max(0, total_count - skipped_count)
    if stale_count > 0:
        return f"skipped {skipped_count} fresh plugin compiles before running {stale_count} stale plugin checks\n"
    return f"skipped {skipped_count} fresh plugin compiles\n"

def format_slow_compile_summary(params=None):
    if params is None:
        params = {}
    
    compile_timings = params.get("compileTimings", [])
    if not compile_timings:
        return ""
    
    limit = params.get("limit", SLOW_COMPILE_SUMMARY_LIMIT)
    if not isinstance(limit, int) or limit <= 0:
        limit = SLOW_COMPILE_SUMMARY_LIMIT
    
    sorted_timings = sorted(compile_timings, key=lambda x: x["elapsedMs"], reverse=True)[:limit]
    lines = ["slowest plugin compiles:"]
    for timing in sorted_timings:
        lines.append(f"- {timing['extensionId']}: {timing['elapsedMs']}ms")
    return "\n".join(lines) + "\n"

def format_step_failure(label, params=None):
    if params is None:
        params = {}
    
    stdout_section = summarize_output_section("stdout", params.get("stdout", ""))
    stderr_section = summarize_output_section("stderr", params.get("stderr", ""))
    footer = format_failure_footer(params)
    return "\n\n".join(filter(None, [label, stdout_section, stderr_section, footer]))

def attach_step_failure_metadata(error, label, params=None):
    if params is None:
        params = {}
    
    error.step_label = label
    error.kind = params.get("kind", "unknown")
    error.elapsed_ms = params.get("elapsedMs", None)
    error.full_output = "\n".join(filter(None, [
        label,
        params.get("stdout", ""),
        params.get("stderr", ""),
        format_failure_footer(params)
    ])).strip()
    return error

def collect_bundled_extension_ids():
    extensions_dir = repo_root / "extensions"
    if not extensions_dir.exists():
        return []
    
    entries = [entry for entry in extensions_dir.iterdir() if entry.is_dir()]
    return sorted([entry.name for entry in entries])

def resolve_extension_tsconfig_path(extension_id):
    return repo_root / "extensions" / extension_id / "tsconfig.json"

def read_extension_tsconfig(extension_id):
    return read_json_file(resolve_extension_tsconfig_path(extension_id))

def collect_opt_in_extension_ids():
    bundled_ids = collect_bundled_extension_ids()
    result = []
    
    for extension_id in bundled_ids:
        tsconfig_path = resolve_extension_tsconfig_path(extension_id)
        if not tsconfig_path.exists():
            continue
        
        try:
            config = read_extension_tsconfig(extension_id)
            if config.get("extends") == extension_package_boundary_base_config:
                result.append(extension_id)
        except (json.JSONDecodeError, KeyError):
            continue
    
    return result

def collect_canary_extension_ids(extension_ids):
    unique_configs = {}
    for extension_id in extension_ids:
        try:
            config = read_extension_tsconfig(extension_id)
            config_key = json.dumps(config, sort_keys=True)
            unique_configs[config_key] = extension_id
        except Exception:
            continue
    
    return list(unique_configs.values())

def is_relevant_compile_input(file_path):
    basename = os.path.basename(file_path)
    if basename in ("__rootdir_boundary_canary__.ts", "tsconfig.rootdir-canary.json"):
        return False
    if basename.endswith(".tsbuildinfo"):
        return False
    return os.path.splitext(file_path)[1] in COMPILE_INPUT_EXTENSIONS

def collect_newest_mtime(entry_path, params=None):
    if params is None:
        params = {}
    
    include_file = params.get("includeFile", lambda _: True)
    skip_dist_directories = params.get("skipDistDirectories", True)
    newest_mtime_ms = 0
    
    def visit(current_path):
        nonlocal newest_mtime_ms
        path_obj = Path(current_path)
        if not path_obj.exists():
            return
        
        stats = path_obj.stat()
        if path_obj.is_dir():
            basename = path_obj.name
            if (skip_dist_directories and basename == "dist") or basename == "node_modules":
                return
            
            for child in path_obj.iterdir():
                visit(child)
            return
        
        if not include_file(str(current_path)):
            return
        
        newest_mtime_ms = max(newest_mtime_ms, stats.st_mtime * 1000)
    
    visit(entry_path)
    return newest_mtime_ms

def collect_oldest_mtime(paths):
    oldest_mtime_ms = float('inf')
    
    for entry_path in paths:
        path_obj = Path(entry_path)
        if not path_obj.exists():
            return None
        
        oldest_mtime_ms = min(oldest_mtime_ms, path_obj.stat().st_mtime * 1000)
    
    return oldest_mtime_ms if oldest_mtime_ms != float('inf') else None

def is_boundary_compile_fresh(extension_id, params=None):
    if params is None:
        params = {}
    
    root_dir = params.get("rootDir", repo_root)
    extension_root = root_dir / "extensions" / extension_id
    extension_newest_input_mtime_ms = params.get("extensionNewestInputMtimeMs")
    
    if extension_newest_input_mtime_ms is None:
        extension_newest_input_mtime_ms = collect_newest_mtime(
            extension_root, 
            {"includeFile": is_relevant_compile_input}
        )
    
    shared_newest_input_mtime_ms = params.get("sharedNewestInputMtimeMs")
    if shared_newest_input_mtime_ms is None:
        sdk_path1 = root_dir / "dist/plugin-sdk"
        sdk_path2 = root_dir / "packages/plugin-sdk/dist"
        
        mtime1 = collect_newest_mtime(sdk_path1, {"skipDistDirectories": False})
        mtime2 = collect_newest_mtime(sdk_path2, {"skipDistDirectories": False})
        shared_newest_input_mtime_ms = max(mtime1 or 0, mtime2 or 0)
    
    newest_input_mtime_ms = max(extension_newest_input_mtime_ms, shared_newest_input_mtime_ms)
    oldest_output_mtime_ms = collect_oldest_mtime([
        resolve_boundary_ts_stamp_path(extension_id, root_dir)
    ])
    
    return (
        oldest_output_mtime_ms is not None and 
        oldest_output_mtime_ms >= newest_input_mtime_ms
    )

def write_stamp_file(file_path):
    file_path = Path(file_path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S.%fZ', time.gmtime())}\n")

def run_node_step(label, args, timeout_ms):
    started_at = time.time()
    try:
        result = subprocess.run(
            [sys.executable] + args,
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=timeout_ms/1000,
            encoding="utf-8"
        )
        
        if result.returncode == 0:
            return result
        
        elapsed_ms = (time.time() - started_at) * 1000
        kind = "nonzero-exit"
        note = ""
        
        if result.returncode == -signal.SIGTERM:
            kind = "timeout"
            note = f"{label} timed out after {timeout_ms}ms"
        
        failure = attach_step_failure_metadata(
            Exception(format_step_failure(label, {
                "stdout": result.stdout,
                "stderr": result.stderr,
                "kind": kind,
                "elapsedMs": elapsed_ms,
                "note": note
            })),
            label,
            {
                "stdout": result.stdout,
                "stderr": result.stderr,
                "kind": kind,
                "elapsedMs": elapsed_ms,
                "note": note
            }
        )
        failure.status = result.returncode or 1
        raise failure
        
    except subprocess.TimeoutExpired as e:
        elapsed_ms = (time.time() - started_at) * 1000
        failure = attach_step_failure_metadata(
            Exception(format_step_failure(label, {
                "stdout": e.stdout.decode() if e.stdout else "",
                "stderr": e.stderr.decode() if e.stderr else "",
                "kind": "timeout",
                "elapsedMs": elapsed_ms,
                "note": f"{label} timed out after {timeout_ms}ms"
            })),
            label,
            {
                "stdout": e.stdout.decode() if e.stdout else "",
                "stderr": e.stderr.decode() if e.stderr else "",
                "kind": "timeout",
                "elapsedMs": elapsed_ms,
                "note": f"{label} timed out after {timeout_ms}ms"
            }
        )
        raise failure

async def run_node_step_async(label, args, timeout_ms, params=None):
    if params is None:
        params = {}
    
    abort_controller = params.get("abortController")
    on_failure = params.get("onFailure")
    started_at = time.time()
    
    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable,
            *args,
            cwd=str(repo_root),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout_data = []
        stderr_data = []
        
        async def read_stdout():
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                stdout_data.append(line.decode('utf-8'))
        
        async def read_stderr():
            while True:
                line = await proc.stderr.readline()
                if not line:
                    break
                stderr_data.append(line.decode('utf-8'))
        
        # Start reading output
        await asyncio.gather(read_stdout(), read_stderr())
        
        # Wait for completion with timeout
        try:
            await asyncio.wait_for(proc.wait(), timeout=timeout_ms/1000)
        except asyncio.TimeoutError:
            proc.terminate()
            await proc.wait()
            raise subprocess.TimeoutExpired(
                cmd=[sys.executable] + args,
                timeout=timeout_ms/1000
            )
        
        elapsed_ms = (time.time() - started_at) * 1000
        
        if proc.returncode == 0:
            return {
                "stdout": "".join(stdout_data),
                "stderr": "".join(stderr_data),
                "elapsedMs": elapsed_ms
            }
        
        # Handle non-zero exit
        error = attach_step_failure_metadata(
            Exception(format_step_failure(label, {
                "stdout": "".join(stdout_data),
                "stderr": "".join(stderr_data),
                "kind": "nonzero-exit",
                "elapsedMs": elapsed_ms
            })),
            label,
            {
                "stdout": "".join(stdout_data),
                "stderr": "".join(stderr_data),
                "kind": "nonzero-exit",
                "elapsedMs": elapsed_ms
            }
        )
        if on_failure:
            on_failure(error)
        raise error
        
    except subprocess.TimeoutExpired:
        elapsed_ms = (time.time() - started_at) * 1000
        error = attach_step_failure_metadata(
            Exception(format_step_failure(label, {
                "stdout": "",
                "stderr": "",
                "kind": "timeout",
                "elapsedMs": elapsed_ms,
                "note": f"{label} timed out after {timeout_ms}ms"
            })),
            label,
            {
                "stdout": "",
                "stderr": "",
                "kind": "timeout",
                "elapsedMs": elapsed_ms,
                "note": f"{label} timed out after {timeout_ms}ms"
            }
        )
        if on_failure:
            on_failure(error)
        raise error

async def run_node_steps_with_concurrency(steps, concurrency):
    abort_controller = None  # Simplified - no abort controller in Python
    first_failure = None
    next_index = 0
    
    async def worker():
        nonlocal next_index, first_failure
        while True:
            index = next_index
            next_index += 1
            
            if index >= len(steps):
                return
            
            step = steps[index]
            if step.get("onStart"):
                step["onStart"]()
            
            try:
                result = await run_node_step_async(
                    step["label"], 
                    step["args"], 
                    step["timeoutMs"]
                )
                if step.get("onSuccess"):
                    step["onSuccess"](result)
            except Exception as e:
                if first_failure is None:
                    first_failure = e
                raise
    
    workers = [worker() for _ in range(min(concurrency, len(steps)))]
    await asyncio.gather(*workers, return_exceptions=True)
    
    if first_failure:
        raise first_failure

def resolve_canary_artifact_paths(extension_id, root_dir=None):
    if root_dir is None:
        root_dir = repo_root
    
    extension_root = root_dir / "extensions" / extension_id
    return {
        "extensionRoot": extension_root,
        "canaryPath": extension_root / "__rootdir_boundary_canary__.ts",
        "tsconfigPath": extension_root / "tsconfig.rootdir-canary.json"
    }

def cleanup_canary_artifacts(extension_id, root_dir=None):
    if root_dir is None:
        root_dir = repo_root
    
    paths = resolve_canary_artifact_paths(extension_id, root_dir)
    paths["canaryPath"].unlink(missing_ok=True)
    paths["tsconfigPath"].unlink(missing_ok=True)

def cleanup_canary_artifacts_for_extensions(extension_ids, root_dir=None):
    for extension_id in extension_ids:
        cleanup_canary_artifacts(extension_id, root_dir)

def install_canary_artifact_cleanup(extension_ids, params=None):
    if params is None:
        params = {}
    
    root_dir = params.get("rootDir", repo_root)
    process_object = params.get("processObject", None)  # Not used in Python
    
    def exit_handler():
        cleanup_canary_artifacts_for_extensions(extension_ids, root_dir)
    
    # Register cleanup function
    import atexit
    atexit.register(exit_handler)
    
    return lambda: atexit.unregister(exit_handler)

def resolve_boundary_ts_build_info_path(extension_id):
    return repo_root / "extensions" / extension_id / "dist" / ".boundary-tsc.tsbuildinfo"

def resolve_boundary_ts_stamp_path(extension_id, root_dir=None):
    if root_dir is None:
        root_dir = repo_root
    return root_dir / "extensions" / extension_id / "dist" / ".boundary-tsc.stamp"

def resolve_boundary_check_lock_path(root_dir=None):
    if root_dir is None:
        root_dir = repo_root
    return root_dir / "dist" / ".extension-package-boundary.lock"

def resolve_boundary_check_lock_owner_path(lock_path):
    return Path(lock_path) / "owner.json"

def is_process_alive(pid):
    if not isinstance(pid, int) or pid <= 0:
        return False
    
    try:
        os.kill(pid, 0)
        return True
    except OSError as e:
        return e.errno == 1  # EPERM

def remove_stale_boundary_check_lock(lock_path):
    owner_path = resolve_boundary_check_lock_owner_path(lock_path)
    try:
        with open(owner_path, "r", encoding="utf-8") as f:
            owner = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        shutil.rmtree(lock_path, ignore_errors=True)
        return True
    
    if isinstance(owner, dict) and is_process_alive(owner.get("pid")):
        return False
    
    shutil.rmtree(lock_path, ignore_errors=True)
    return True

def acquire_boundary_check_lock(params=None):
    if params is None:
        params = {}
    
    root_dir = params.get("rootDir", repo_root)
    process_object = params.get("processObject", None)  # Not used in Python
    lock_path = resolve_boundary_check_lock_path(root_dir)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        lock_path.mkdir(exist_ok=False)
    except FileExistsError:
        if remove_stale_boundary_check_lock(lock_path):
            lock_path.mkdir()
        else:
            error = attach_step_failure_metadata(
                Exception("\n\n".join([
                    "extension package boundary check",
                    "kind: lock-contention",
                    f"lock: {lock_path}",
                    "another extension package boundary check is already running in this checkout"
                ])),
                "extension package boundary check",
                {
                    "kind": "lock-contention",
                    "note": f"lock: {lock_path}\nanother extension package boundary check is already running in this checkout"
                }
            )
            raise error
    
    owner_data = {
        "pid": os.getpid(),
        "startedAt": time.strftime('%Y-%m-%dT%H:%M:%S.%fZ', time.gmtime())
    }
    
    with open(resolve_boundary_check_lock_owner_path(lock_path), "w", encoding="utf-8") as f:
        json.dump(owner_data, f, indent=2)
        f.write("\n")
    
    def release():
        shutil.rmtree(lock_path, ignore_errors=True)
    
    import atexit
    atexit.register(release)
    
    return lambda: atexit.unregister(release)

async def run_compile_check(extension_ids):
    prep_started_at = time.time()
    print(f"preparing plugin-sdk boundary artifacts for {len(extension_ids)} plugins")
    
    run_node_step("plugin-sdk boundary prep", [str(prepare_boundary_artifacts_bin)], 420000)
    prep_elapsed_ms = (time.time() - prep_started_at) * 1000
    
    concurrency = resolve_compile_concurrency()
    verbose_fresh_logs = os.environ.get("OPENCLAW_EXTENSION_BOUNDARY_VERBOSE_FRESH") == "1"
    
    sdk_path1 = repo_root / "dist/plugin-sdk"
    sdk_path2 = repo_root / "packages/plugin-sdk/dist"
    
    mtime1 = collect_newest_mtime(sdk_path1, {"skipDistDirectories": False})
    mtime2 = collect_newest_mtime(sdk_path2, {"skipDistDirectories": False})
    shared_newest_input_mtime_ms = max(mtime1 or 0, mtime2 or 0)
    
    print(f"compile concurrency {concurrency}")
    compile_started_at = time.time()
    skipped_compile_count = 0
    compile_timings = []
    
    steps = []
    for i, extension_id in enumerate(extension_ids):
        ts_build_info_path = resolve_boundary_ts_build_info_path(extension_id)
        ts_build_info_path.parent.mkdir(parents=True, exist_ok=True)
        
        extension_newest_input_mtime_ms = collect_newest_mtime(
            repo_root / "extensions" / extension_id,
            {"includeFile": is_relevant_compile_input}
        )
        
        if is_boundary_compile_fresh(extension_id, {
            "extensionNewestInputMtimeMs": extension_newest_input_mtime_ms,
            "sharedNewestInputMtimeMs": shared_newest_input_mtime_ms
        }):
            skipped_compile_count += 1
            if verbose_fresh_logs:
                print(f"[{i+1}/{len(extension_ids)}] {extension_id} (fresh; skipping)")
            continue
        
        def make_on_success(ext_id):
            def on_success(result):
                write_stamp_file(resolve_boundary_ts_stamp_path(ext_id))
                compile_timings.append({
                    "extensionId": ext_id,
                    "elapsedMs": result["elapsedMs"]
                })
            return on_success
        
        steps.append({
            "label": extension_id,
            "onStart": lambda idx=i, eid=extension_id: print(f"[{idx+1}/{len(extension_ids)}] {eid}"),
            "onSuccess": make_on_success(extension_id),
            "args": [
                str(tsc_bin),
                "-p",
                str(repo_root / "extensions" / extension_id / "tsconfig.json"),
                "--noEmit",
                "--incremental",
                "--tsBuildInfoFile",
                str(ts_build_info_path)
            ],
            "timeoutMs": 120000
        })
    
    if not verbose_fresh_logs and skipped_compile_count > 0:
        print(format_skipped_compile_progress({
            "skippedCount": skipped_compile_count,
            "totalCount": len(extension_ids)
        }))
    
    if steps:
        await run_node_steps_with_concurrency(steps, concurrency)
    
    return {
        "prepElapsedMs": prep_elapsed_ms,
        "compileCount": len(steps),
        "skippedCompileCount": skipped_compile_count,
        "compileElapsedMs": (time.time() - compile_started_at) * 1000,
        "compileTimings": compile_timings
    }

async def run_canary_check(extension_ids):
    started_at = time.time()
    
    async def check_extension(extension_id, index):
        paths = resolve_canary_artifact_paths(extension_id)
        cleanup_canary_artifacts(extension_id)
        print(f"[{index+1}/{len(extension_ids)}] {extension_id} canary")
        
        try:
            # Write canary file
            with open(paths["canaryPath"], "w", encoding="utf-8") as f:
                f.write(f'import {{ ROOTDIR_BOUNDARY_CANARY }} from "{ROOTDIR_BOUNDARY_CANARY_IMPORT_PATH}";\n')
                f.write("void ROOTDIR_BOUNDARY_CANARY;\n")
                f.write("export {};\n\n")
            
            # Write tsconfig
            tsconfig_content = {
                "extends": "./tsconfig.json",
                "include": ["./__rootdir_boundary_canary__.ts"],
                "exclude": []
            }
            with open(paths["tsconfigPath"], "w", encoding="utf-8") as f:
                json.dump(tsconfig_content, f, indent=2)
                f.write("\n")
            
            # Run check
            result = await run_node_step_async(
                f"{extension_id} canary",
                [str(tsc_bin), "-p", str(paths["tsconfigPath"]), "--noEmit"],
                120000
            )
            
            raise Exception(f"{extension_id} canary unexpectedly passed\n{result['stdout']}{result['stderr']}")
            
        except Exception as e:
            output = getattr(e, 'full_output', str(e)) if isinstance(e, Exception) else str(e)
            if "TS6059" not in output or ROOTDIR_BOUNDARY_CANARY_OUTPUT_HINT not in output:
                raise
        finally:
            cleanup_canary_artifacts(extension_id)
    
    tasks = [check_extension(extension_id, i) for i, extension_id in enumerate(extension_ids)]
    await asyncio.gather(*tasks)
    
    return {
        "canaryElapsedMs": (time.time() - started_at) * 1000
    }

async def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    
    started_at = time.time()
    mode = parse_mode(argv)
    opt_in_extension_ids = collect_opt_in_extension_ids()
    canary_extension_ids = collect_canary_extension_ids(opt_in_extension_ids)
    cleanup_extension_ids = opt_in_extension_ids
    should_run_canary = mode in ("all", "canary")
    
    release_boundary_lock = acquire_boundary_check_lock()
    teardown_canary_cleanup = install_canary_artifact_cleanup(cleanup_extension_ids)
    
    prep_elapsed_ms = None
    compile_count = 0
    skipped_compile_count = 0
    compile_elapsed_ms = None
    compile_timings = []
    canary_elapsed_ms = None
    
    try:
        cleanup_canary_artifacts_for_extensions(cleanup_extension_ids)
        
        if mode in ("all", "compile"):
            result = await run_compile_check(opt_in_extension_ids)
            prep_elapsed_ms = result["prepElapsedMs"]
            compile_count = result["compileCount"]
            skipped_compile_count = result["skippedCompileCount"]
            compile_elapsed_ms = result["compileElapsedMs"]
            compile_timings = result["compileTimings"]
        
        if should_run_canary:
            result = await run_canary_check(canary_extension_ids)
            canary_elapsed_ms = result["canaryElapsedMs"]
        
        success_summary = format_boundary_check_success_summary({
            "mode": mode,
            "compileCount": compile_count,
            "skippedCompileCount": skipped_compile_count,
            "canaryCount": len(canary_extension_ids) if should_run_canary else 0,
            "prepElapsedMs": prep_elapsed_ms,
            "compileElapsedMs": compile_elapsed_ms,
            "canaryElapsedMs": canary_elapsed_ms,
            "elapsedMs": (time.time() - started_at) * 1000
        })
        print(success_summary)
        
        slow_compile_summary = format_slow_compile_summary({
            "compileTimings": compile_timings
        })
        print(slow_compile_summary)
        
    finally:
        if release_boundary_lock:
            release_boundary_lock()
        if teardown_canary_cleanup:
            teardown_canary_cleanup()
        cleanup_canary_artifacts_for_extensions(cleanup_extension_ids)

if __name__ == "__main__":
    asyncio.run(main())
