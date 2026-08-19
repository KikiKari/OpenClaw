#!/usr/bin/env python3
# extract-tiktok-yt-dlp.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
import json
import subprocess
import tempfile
import os
import re
import shutil

def emit_json(*args):
    keys = ("success", "method", "username", "url", "format", "error", "timestamp", "status")
    payload = {k: v for k, v in zip(keys, args) if v != ""}
    if "success" in payload:
        payload["success"] = payload["success"].lower() == "true"
    print(json.dumps(payload, ensure_ascii=False))

def get_load_per_cpu():
    try:
        load_avg = os.getloadavg()[0]
        cpu_count = os.cpu_count() or 1
        return load_avg / max(1, cpu_count)
    except Exception:
        return 0.0

def validate_username(username):
    pattern = r'^[A-Za-z0-9._]{1,24}$'
    return bool(re.match(pattern, username))

def validate_format(fmt):
    valid_formats = [
        "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
        "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
        "hls-sd/hls-ld/flv-sd/flv-ld",
        "hls-ld/flv-ld",
        "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
    ]
    return fmt in valid_formats

def main():
    if len(sys.argv) < 2:
        print("Usage: {} <username> [format] [--json]".format(sys.argv[0]), file=sys.stderr)
        sys.exit(64)

    username = sys.argv[1].lstrip('@')
    fmt = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "--json" else "best"
    json_flag = "--json" if "--json" in sys.argv else ""
    
    timestamp = subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], text=True).strip()
    
    tmp_dir = tempfile.mkdtemp(prefix="tiktok-yt-dlp.", dir="/tmp")
    
    def cleanup():
        shutil.rmtree(tmp_dir, ignore_errors=True)
    
    import atexit
    atexit.register(cleanup)

    # Bounded fallback used by the enhanced extractor. Temporary files are cleaned
    # on every exit and output is normalized again by tiktok-get-stream.js.
    # Standalone overload exits 75 before yt-dlp starts.

    if not validate_username(username):
        print("Invalid TikTok username", file=sys.stderr)
        sys.exit(64)

    if not validate_format(fmt):
        print("Invalid yt-dlp format", file=sys.stderr)
        sys.exit(64)

    load_per_cpu = get_load_per_cpu()
    max_load = float(os.environ.get("TIKTOK_MAX_LOAD_PER_CPU", "1.5"))
    
    if load_per_cpu > max_load:
        emit_json("false", "yt-dlp", username, "", fmt, "host overloaded", timestamp, "overloaded")
        sys.exit(75)

    try:
        subprocess.run(["yt-dlp", "--version"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        emit_json("false", "yt-dlp", username, "", fmt, "yt-dlp not installed", timestamp, "dependency_missing")
        sys.exit(2)

    live_url = f"https://www.tiktok.com/@{username}/live"
    stdout_file = os.path.join(tmp_dir, "stdout.json")
    stderr_file = os.path.join(tmp_dir, "stderr.log")

    try:
        with open(stdout_file, "w") as stdout_f, open(stderr_file, "w") as stderr_f:
            result = subprocess.run([
                "yt-dlp",
                "--no-warnings",
                "--dump-single-json",
                "--skip-download",
                "--format", fmt,
                live_url
            ], stdout=stdout_f, stderr=stderr_f)
            
        exit_code = result.returncode
        
        if exit_code != 0:
            with open(stderr_file, "r") as f:
                stderr_content = f.read()
                
            if any(term in stderr_content.lower() for term in ["not currently live", "no live cdn found", "not available", "private video"]):
                status = "offline"
                code = 1
            else:
                status = "technical_error"
                code = 2
                
            emit_json("false", "yt-dlp", username, "", fmt, stderr_content[:1000], timestamp, status)
            sys.exit(code)

        with open(stdout_file, "r") as f:
            data = json.load(f)
            
        candidates = []
        if isinstance(data.get("url"), str):
            candidates.append(data["url"])
            
        for item in data.get("formats", []) or []:
            if isinstance(item, dict) and isinstance(item.get("url"), str):
                candidates.append(item["url"])
                
        url = ""
        for value in candidates:
            low = value.lower()
            if value.startswith("https://") and (".m3u8" in low or ".flv" in low) and "only_audio=1" not in low:
                url = value
                break

        if not url:
            emit_json("false", "yt-dlp", username, "", fmt, "could not extract HTTPS video URL", timestamp, "offline")
            sys.exit(1)

        if json_flag == "--json":
            emit_json("true", "yt-dlp", username, url, fmt, "", timestamp, "live")
        else:
            print(url)

    except Exception as e:
        emit_json("false", "yt-dlp", username, "", fmt, str(e), timestamp, "technical_error")
        sys.exit(2)

if __name__ == "__main__":
    main()
