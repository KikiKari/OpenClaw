#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "ef17bc126203021dee14e7bbfe9dc88f5e8fb524eb5a648c2df5fa1fcfb3a0b3", "source_sha256": "04f0268dc494793e85c15189558b4768a3e49a147b113ecc0fe3456b05d0eb20", "target_language": "python"}
# check-cli-startup-memory.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-cli-startup-memory.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import subprocess
import tempfile
import os
import sys
import shutil
import re

is_linux = sys.platform == "linux"
is_mac = sys.platform == "darwin"

if not is_linux and not is_mac:
    print(f"[startup-memory] Skipping on unsupported platform: {sys.platform}")
    sys.exit(0)

repo_root = os.getcwd()
tmp_home = tempfile.mkdtemp(prefix="openclaw-startup-memory-")
tmp_dir = os.environ.get("TMPDIR") or os.environ.get("TEMP") or os.environ.get("TMP") or tempfile.gettempdir()
rss_hook_path = os.path.join(tmp_home, "measure-rss.py")
MAX_RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__="

with open(rss_hook_path, "w", encoding="utf-8") as f:
    f.write(f"""import atexit
import resource

def report_max_rss():
    try:
        usage = resource.getrusage(resource.RUSAGE_SELF)
        max_rss_kb = usage.ru_maxrss
        print('{MAX_RSS_MARKER}' + str(max_rss_kb))
    except Exception:
        pass

atexit.register(report_max_rss)
""")

DEFAULT_LIMITS_MB = {
    "help": 100,
    "statusJson": 400,
    "gatewayStatus": 500,
}

cases = [
    {
        "id": "help",
        "label": "--help",
        "args": ["openclaw.py", "--help"],
        "limitMb": int(os.environ.get("OPENCLAW_STARTUP_MEMORY_HELP_MB", DEFAULT_LIMITS_MB["help"])),
    },
    {
        "id": "statusJson",
        "label": "status --json",
        "args": ["openclaw.py", "status", "--json"],
        "limitMb": int(os.environ.get("OPENCLAW_STARTUP_MEMORY_STATUS_JSON_MB", DEFAULT_LIMITS_MB["statusJson"])),
    },
    {
        "id": "gatewayStatus",
        "label": "gateway status",
        "args": ["openclaw.py", "gateway", "status"],
        "limitMb": int(os.environ.get("OPENCLAW_STARTUP_MEMORY_GATEWAY_STATUS_MB", DEFAULT_LIMITS_MB["gatewayStatus"])),
    },
]

def format_fix_guidance(test_case, details):
    command = f"python {' '.join(test_case['args'])}"
    guidance = [
        "[startup-memory] Fix guidance",
        f"Case: {test_case['label']}",
        f"Command: {command}",
        "Next steps:",
        f"1. Run `{command}` locally on the built tree.",
        "2. If this is an RSS overage, compare the startup import graph against the last passing commit and look for newly eager imports, bootstrap side effects, or plugin loading on the command path.",
        "3. If this is a non-zero exit, inspect the first transitive import/config error in stderr and fix that root cause before re-checking memory.",
        "LLM prompt:",
        f'"OpenClaw startup-memory CI failed for \'{test_case["label"]}\'. Analyze this failure, identify the first runtime/import side effect that makes startup heavier or broken, and propose the smallest safe patch. Failure output:\\n{details}"',
    ]
    return "\n".join(guidance) + "\n"

def format_failure(test_case, message, details=""):
    trimmed_details = details.strip()
    sections = [message]
    if trimmed_details:
        sections.append(trimmed_details)
    sections.append(format_fix_guidance(test_case, trimmed_details or message))
    return "\n\n".join(sections)

def parse_max_rss_mb(stderr_output):
    pattern = re.compile(f"^{re.escape(MAX_RSS_MARKER)}(\\d+)\\s*$", re.MULTILINE)
    matches = list(pattern.finditer(stderr_output))
    if not matches:
        return None
    last_match = matches[-1]
    return int(last_match.group(1)) / 1024

def build_bench_env():
    env = {
        "HOME": tmp_home,
        "USERPROFILE": tmp_home,
        "XDG_CONFIG_HOME": os.path.join(tmp_home, ".config"),
        "XDG_DATA_HOME": os.path.join(tmp_home, ".local", "share"),
        "XDG_CACHE_HOME": os.path.join(tmp_home, ".cache"),
        "PATH": os.environ.get("PATH", ""),
        "TMPDIR": tmp_dir,
        "TEMP": tmp_dir,
        "TMP": tmp_dir,
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "TERM": os.environ.get("TERM", "dumb"),
    }

    if "LC_ALL" in os.environ:
        env["LC_ALL"] = os.environ["LC_ALL"]
    if "CI" in os.environ:
        env["CI"] = os.environ["CI"]
    if "PYTHON_DISABLE_COMPILE_CACHE" in os.environ:
        env["PYTHON_DISABLE_COMPILE_CACHE"] = os.environ["PYTHON_DISABLE_COMPILE_CACHE"]
    else:
        # Keep the regression check focused on app/runtime startup, not Python's
        # one-shot compile cache overhead, which varies across runner builds.
        env["PYTHON_DISABLE_COMPILE_CACHE"] = "1"
    # Keep the benchmark on a single process so RSS reflects the actual command
    # path rather than the warning-suppression respawn wrapper.
    env["OPENCLAW_NO_RESPAWN"] = "1"

    return env

def run_case(test_case):
    env = build_bench_env()
    
    cmd = [sys.executable, "-u", "-c", f"import sys; sys.path.insert(0, '{rss_hook_path}'); exec(open('{rss_hook_path}').read())"] + test_case["args"][1:]
    
    try:
        result = subprocess.run(
            [sys.executable, "-u"] + test_case["args"],
            cwd=repo_root,
            env=env,
            capture_output=True,
            text=True,
            timeout=60
        )
    except subprocess.TimeoutExpired:
        raise Exception(format_failure(test_case, f"{test_case['label']} timed out"))
    
    stderr_output = result.stderr if result.stderr else ""
    stdout_output = result.stdout if result.stdout else ""
    max_rss_mb = parse_max_rss_mb(stderr_output)
    matrix_bootstrap_warning = re.search(r"matrix: crypto runtime bootstrap failed", stderr_output, re.IGNORECASE)

    if result.returncode != 0:
        error_details = stderr_output.strip() or stdout_output or ""
        raise Exception(format_failure(
            test_case,
            f"{test_case['label']} exited with {result.returncode}",
            error_details
        ))
    
    if max_rss_mb is None:
        raise Exception(format_failure(test_case, f"{test_case['label']} did not report max RSS", stderr_output))
    
    if matrix_bootstrap_warning:
        raise Exception(format_failure(test_case, f"{test_case['label']} triggered Matrix crypto bootstrap during startup"))
    
    if max_rss_mb > test_case["limitMb"]:
        raise Exception(format_failure(
            test_case,
            f"{test_case['label']} used {max_rss_mb:.1f} MB RSS (limit {test_case['limitMb']} MB)"
        ))

    print(f"[startup-memory] {test_case['label']}: {max_rss_mb:.1f} MB RSS (limit {test_case['limitMb']} MB)")

try:
    for test_case in cases:
        run_case(test_case)
finally:
    shutil.rmtree(tmp_home, ignore_errors=True)
