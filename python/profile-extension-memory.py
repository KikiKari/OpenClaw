#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "75138eb605fb18cd41ec1c35769df922b6de1558ab1ed124b7931d33e7193231", "source_sha256": "93ecf5d3490bf6c88b3f288ec409b9375009242d467e26772ba3a10251e1d9b7", "target_language": "python"}
# profile-extension-memory.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/profile-extension-memory.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import argparse
import asyncio
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_CONCURRENCY = 6
DEFAULT_TIMEOUT_MS = 90000
DEFAULT_COMBINED_TIMEOUT_MS = 180000
DEFAULT_TOP = 10
RSS_MARKER = "__OPENCLAW_MAX_RSS_KB__="

def print_help():
    print(f"""Usage: python profile-extension-memory.py [options]

Profiles peak RSS for built bundled plugin entrypoints.
Run pnpm build first if you want stats for the latest source changes.

Options:
  --extension, -e <id>     Limit profiling to one or more extension ids (repeatable)
  --concurrency <n>        Number of per-extension workers (default: {DEFAULT_CONCURRENCY})
  --timeout-ms <ms>        Per-extension timeout in milliseconds (default: {DEFAULT_TIMEOUT_MS})
  --combined-timeout-ms <ms>
                           Combined-import timeout in milliseconds (default: {DEFAULT_COMBINED_TIMEOUT_MS})
  --top <n>                Show top N entries by delta from baseline (default: {DEFAULT_TOP})
  --json <path>            Write full JSON report to this path
  --skip-combined          Skip the combined all-imports measurement
  --help                   Show this help

Examples:
  pnpm test:extensions:memory
  pnpm test:extensions:memory -- --extension discord
  pnpm test:extensions:memory -- --extension discord --extension telegram --skip-combined
""")

def parse_positive_int(raw, flag_name):
    try:
        parsed = int(raw)
        if parsed <= 0:
            raise ValueError()
        return parsed
    except ValueError:
        raise ValueError(f"{flag_name} must be a positive integer")

def parse_args(argv):
    parser = argparse.ArgumentParser(description="Profiles peak RSS for built bundled plugin entrypoints", add_help=False)
    
    parser.add_argument("--extension", "-e", action="append", dest="extensions", default=[])
    parser.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY)
    parser.add_argument("--timeout-ms", type=int, default=DEFAULT_TIMEOUT_MS)
    parser.add_argument("--combined-timeout-ms", type=int, default=DEFAULT_COMBINED_TIMEOUT_MS)
    parser.add_argument("--top", type=int, default=DEFAULT_TOP)
    parser.add_argument("--json", dest="json_path", default=None)
    parser.add_argument("--skip-combined", action="store_true", default=False)
    parser.add_argument("--help", "-h", action="store_true", default=False)
    
    args = parser.parse_args(argv)
    
    if args.help:
        print_help()
        sys.exit(0)
        
    # Validate positive integers
    if args.concurrency <= 0:
        raise ValueError("--concurrency must be a positive integer")
    if args.timeout_ms <= 0:
        raise ValueError("--timeout-ms must be a positive integer")
    if args.combined_timeout_ms <= 0:
        raise ValueError("--combined-timeout-ms must be a positive integer")
    if args.top <= 0:
        raise ValueError("--top must be a positive integer")
        
    if args.json_path:
        args.json_path = os.path.abspath(args.json_path)
        
    return args

def parse_max_rss_mb(stderr):
    pattern = f"^{RSS_MARKER}(\\d+)\\s*$"
    matches = re.findall(pattern, stderr, re.MULTILINE)
    if matches:
        return int(matches[-1]) / 1024
    return None

def summarize_stderr(stderr, lines=8):
    return "\n".join(stderr.strip().split("\n")[:lines])

async def run_case(repo_root, env, hook_path, name, body, timeout_ms):
    cmd = [
        sys.executable,
        "--import", hook_path,
        "--input-type=module",
        "--eval", body
    ]
    
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=repo_root,
            env=env,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout_ms/1000)
        stdout_str = stdout.decode('utf-8')
        stderr_str = stderr.decode('utf-8')
        
        return {
            "name": name,
            "code": proc.returncode,
            "signal": None,
            "timed_out": False,
            "stdout": stdout_str,
            "stderr": stderr_str,
            "max_rss_mb": parse_max_rss_mb(stderr_str),
        }
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        return {
            "name": name,
            "code": None,
            "signal": None,
            "timed_out": True,
            "stdout": "",
            "stderr": "",
            "max_rss_mb": None,
        }

def build_import_body(entry_files, label):
    imports = "\n".join([f'await import({json.dumps(file_path)});' for file_path in entry_files])
    return f"{imports}\nconsole.log({json.dumps(label)});\nprocess.exit(0);\n"

def find_extension_entries(repo_root):
    extensions_dir = os.path.join(repo_root, "dist", "extensions")
    if not os.path.exists(extensions_dir):
        raise FileNotFoundError("dist/extensions not found. Run pnpm build first.")
        
    entries = []
    for dir_name in sorted(os.listdir(extensions_dir)):
        file_path = os.path.join(extensions_dir, dir_name, "index.js")
        if os.path.exists(file_path):
            entries.append({"dir": dir_name, "file": file_path})
            
    if len(entries) == 0:
        raise FileNotFoundError("No built bundled plugin entrypoints found in the dist plugin tree")
        
    return entries

async def main():
    options = parse_args(sys.argv[1:])
    repo_root = os.getcwd()
    all_entries = find_extension_entries(repo_root)
    
    if options.extensions:
        selected_entries = [entry for entry in all_entries if entry["dir"] in options.extensions]
        missing = [ext_id for ext_id in options.extensions if not any(entry["dir"] == ext_id for entry in all_entries)]
        if missing:
            raise ValueError(f"Unknown built extension ids: {', '.join(missing)}")
    else:
        selected_entries = all_entries
        
    if not selected_entries:
        raise ValueError("No extensions selected for profiling")
        
    with tempfile.TemporaryDirectory(prefix="openclaw-extension-memory-") as tmp_home:
        hook_path = os.path.join(tmp_home, "measure-rss.mjs")
        json_path = options.json_path or os.path.join(tempfile.gettempdir(), "openclaw-extension-memory.json")
        
        hook_content = """process.on('exit', () => {
  const usage = typeof process.resourceUsage === 'function' ? process.resourceUsage() : null;
  if (usage && typeof usage.maxRSS === 'number') console.error('__OPENCLAW_MAX_RSS_KB__' + String(usage.maxRSS));
});
"""
        with open(hook_path, "w") as f:
            f.write(hook_content)
            
        env = os.environ.copy()
        env.update({
            "HOME": tmp_home,
            "USERPROFILE": tmp_home,
            "XDG_CONFIG_HOME": os.path.join(tmp_home, ".config"),
            "XDG_DATA_HOME": os.path.join(tmp_home, ".local", "share"),
            "XDG_CACHE_HOME": os.path.join(tmp_home, ".cache"),
            "NODE_DISABLE_COMPILE_CACHE": "1",
            "OPENCLAW_NO_RESPAWN": "1",
            "TERM": env.get("TERM", "dumb"),
            "LANG": env.get("LANG", "C.UTF-8"),
        })
        
        baseline = await run_case(
            repo_root,
            env,
            hook_path,
            "baseline",
            "process.exit(0)",
            options.timeout_ms
        )
        
        if options.skip_combined:
            combined = None
        else:
            combined = await run_case(
                repo_root,
                env,
                hook_path,
                "combined",
                build_import_body([entry["file"] for entry in selected_entries], "IMPORTED_ALL"),
                options.combined_timeout_ms
            )
            
        pending = selected_entries[:]
        results = []
        
        async def worker():
            while pending:
                next_entry = pending.pop(0)
                result = await run_case(
                    repo_root,
                    env,
                    hook_path,
                    next_entry["dir"],
                    build_import_body([next_entry["file"]], "IMPORTED"),
                    options.timeout_ms
                )
                
                delta_from_baseline_mb = None
                if result["max_rss_mb"] is not None and baseline["max_rss_mb"] is not None:
                    delta_from_baseline_mb = result["max_rss_mb"] - baseline["max_rss_mb"]
                    
                result_entry = {
                    "dir": next_entry["dir"],
                    "file": next_entry["file"],
                    "status": "timeout" if result["timed_out"] else ("ok" if result["code"] == 0 else "fail"),
                    "max_rss_mb": result["max_rss_mb"],
                    "delta_from_baseline_mb": delta_from_baseline_mb,
                    "stderr_preview": summarize_stderr(result["stderr"]),
                }
                
                results.append(result_entry)
                
                status = "timeout" if result["timed_out"] else ("ok" if result["code"] == 0 else "fail")
                rss = "n/a" if result["max_rss_mb"] is None else f"{result['max_rss_mb']:.1f} MB"
                print(f"[extension-memory] {next_entry['dir']}: {status} {rss}")
                
        # Run workers
        workers_count = min(options.concurrency, len(selected_entries))
        await asyncio.gather(*[worker() for _ in range(workers_count)])
        
        # Sort results
        results.sort(key=lambda x: x["dir"])
        
        # Get top entries
        top = [r for r in results if r["status"] == "ok" and r["delta_from_baseline_mb"] is not None]
        top.sort(key=lambda x: x["delta_from_baseline_mb"] or 0, reverse=True)
        top = top[:options.top]
        
        # Build report
        report = {
            "generated_at": __import__('datetime').datetime.now().isoformat(),
            "repo_root": repo_root,
            "selected_extensions": [entry["dir"] for entry in selected_entries],
            "baseline": {
                "status": "timeout" if baseline["timed_out"] else ("ok" if baseline["code"] == 0 else "fail"),
                "max_rss_mb": baseline["max_rss_mb"],
            },
            "combined": None if combined is None else {
                "status": "timeout" if combined["timed_out"] else ("ok" if combined["code"] == 0 else "fail"),
                "max_rss_mb": combined["max_rss_mb"],
                "stderr_preview": summarize_stderr(combined["stderr"], 12),
            },
            "counts": {
                "total_entries": len(selected_entries),
                "ok": len([r for r in results if r["status"] == "ok"]),
                "fail": len([r for r in results if r["status"] == "fail"]),
                "timeout": len([r for r in results if r["status"] == "timeout"]),
            },
            "options": {
                "concurrency": options.concurrency,
                "timeout_ms": options.timeout_ms,
                "combined_timeout_ms": options.combined_timeout_ms,
                "skip_combined": options.skip_combined,
            },
            "top_by_delta_mb": top,
            "results": results,
        }
        
        with open(json_path, "w") as f:
            json.dump(report, f, indent=2)
            
        print(f"[extension-memory] report: {json_path}")
        summary = {
            "baseline_mb": report["baseline"]["max_rss_mb"],
            "combined_mb": report["combined"]["max_rss_mb"] if report["combined"] else None,
            "counts": report["counts"],
            "top_by_delta_mb": report["top_by_delta_mb"],
        }
        print(json.dumps(summary, indent=2))

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"[extension-memory] {str(e)}")
        sys.exit(1)
