#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "cb697131c6df28714440f04e8b78761cf0811c61cc0f1239445f4dc4ec636fc3", "source_sha256": "2516612af0a0435eb92af19fa6d322dbf03b3c95168e1f623ea14087f9e79413", "target_language": "python"}
# run-vitest.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import json
import subprocess
import signal
from pathlib import Path

TRUTHY_ENV_VALUES = {"1", "true", "yes", "on"}
SUPPRESSED_VITEST_STDERR_PATTERNS = ["[PLUGIN_TIMINGS] Warning:"]

def is_truthy_env_value(value):
    if value is None:
        return False
    return value.strip().lower() in TRUTHY_ENV_VALUES

def resolve_vitest_node_args(env=None):
    if env is None:
        env = os.environ
    
    if is_truthy_env_value(env.get("OPENCLAW_VITEST_ENABLE_MAGLEV")):
        return []
    
    return ["--no-maglev"]

def resolve_vitest_cli_entry():
    # Find vitest package.json and derive vitest.mjs path
    try:
        # This simulates require.resolve("vitest/package.json")
        # In a real scenario, you might need to find the actual path
        import vitest
        vitest_path = Path(vitest.__file__).parent / "package.json"
        if not vitest_path.exists():
            # Fallback to node_modules search
            current = Path(__file__).resolve()
            while current.parent != current:
                candidate = current / "node_modules" / "vitest" / "package.json"
                if candidate.exists():
                    vitest_path = candidate
                    break
                current = current.parent
            
        vitest_dir = vitest_path.parent
        vitest_cli = vitest_dir / "vitest.mjs"
        return str(vitest_cli)
    except ImportError:
        # If we can't import vitest, try to find it in node_modules manually
        current = Path(__file__).resolve()
        while current.parent != current:
            candidate = current / "node_modules" / "vitest" / "vitest.mjs"
            if candidate.exists():
                return str(candidate)
            current = current.parent
        raise RuntimeError("Could not find vitest installation")

def should_use_detached_vitest_process_group(platform=None):
    if platform is None:
        platform = sys.platform
    return platform != "win32"

def install_vitest_process_group_cleanup(child):
    def cleanup():
        try:
            if hasattr(child, 'pid') and child.poll() is None:
                if sys.platform == "win32":
                    subprocess.run(["taskkill", "/F", "/T", "/PID", str(child.pid)], 
                                 capture_output=True)
                else:
                    child.terminate()
        except Exception:
            pass
    
    return cleanup

def resolve_vitest_spawn_params(env=None, platform=None):
    if env is None:
        env = os.environ
    if platform is None:
        platform = sys.platform
        
    return {
        "env": env,
        "detached": should_use_detached_vitest_process_group(platform),
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE
    }

def should_suppress_vitest_stderr_line(line):
    return any(pattern in line for pattern in SUPPRESSED_VITEST_STDERR_PATTERNS)

def forward_vitest_output(stream, target, should_suppress_line=None):
    if should_suppress_line is None:
        should_suppress_line = lambda x: False
        
    if stream is None:
        return
        
    try:
        for line in iter(stream.readline, ''):
            if not should_suppress_line(line):
                target.write(line)
                target.flush()
    except Exception:
        pass

def main(argv=None, env=None):
    if argv is None:
        argv = sys.argv[1:]
    if env is None:
        env = os.environ
        
    if len(argv) == 0:
        print("usage: python run-vitest.py <vitest args...>", file=sys.stderr)
        sys.exit(1)
        
    spawn_params = resolve_vitest_spawn_params(env)
    
    # Build command
    vitest_args = [
        "node",
        *resolve_vitest_node_args(env),
        resolve_vitest_cli_entry(),
        *argv
    ]
    
    # Try to use pnpm first, fallback to direct execution
    try:
        cmd = ["pnpm", "exec"] + vitest_args
        child = subprocess.Popen(
            cmd,
            env=spawn_params["env"],
            stdout=spawn_params["stdout"],
            stderr=spawn_params["stderr"],
            preexec_fn=os.setsid if spawn_params["detached"] and hasattr(os, 'setsid') else None
        )
    except FileNotFoundError:
        # pnpm not found, try direct node execution
        cmd = vitest_args
        child = subprocess.Popen(
            cmd,
            env=spawn_params["env"],
            stdout=spawn_params["stdout"],
            stderr=spawn_params["stderr"],
            preexec_fn=os.setsid if spawn_params["detached"] and hasattr(os, 'setsid') else None
        )
    
    teardown_child_cleanup = install_vitest_process_group_cleanup(child)
    
    # Forward output streams
    stdout_thread = None
    stderr_thread = None
    
    if child.stdout:
        import threading
        stdout_thread = threading.Thread(
            target=forward_vitest_output,
            args=(child.stdout, sys.stdout)
        )
        stdout_thread.daemon = True
        stdout_thread.start()
        
    if child.stderr:
        import threading
        stderr_thread = threading.Thread(
            target=forward_vitest_output,
            args=(child.stderr, sys.stderr, should_suppress_vitest_stderr_line)
        )
        stderr_thread.daemon = True
        stderr_thread.start()
    
    def handle_exit(signum=None, frame=None):
        teardown_child_cleanup()
        if signum:
            os.kill(os.getpid(), signum)
        else:
            sys.exit(1)
            
    # Handle signals
    signal.signal(signal.SIGTERM, handle_exit)
    signal.signal(signal.SIGINT, handle_exit)
    
    try:
        exit_code = child.wait()
        teardown_child_cleanup()
        sys.exit(exit_code if exit_code is not None else 1)
    except KeyboardInterrupt:
        teardown_child_cleanup()
        sys.exit(1)
    except Exception as e:
        teardown_child_cleanup()
        print(e, file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
