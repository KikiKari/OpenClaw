#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "8ee21ccb4b2395cdab294c55f78edb38f8180a01cb17a852bf2b7964977a69b6", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "python"}
# extract-tiktok-yt-dlp.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime


def emit_json(success, method, username, url, fmt, error, timestamp, status):
    """Emit JSON response"""
    payload = {
        "success": success,
        "method": method,
        "username": username,
        "url": url,
        "format": fmt,
        "error": error,
        "timestamp": timestamp,
        "status": status
    }
    # Remove empty values
    payload = {k: v for k, v in payload.items() if v != ""}
    if "success" in payload:
        payload["success"] = payload["success"] in [True, "true"]
    print(json.dumps(payload, ensure_ascii=False))


def validate_username(username):
    """Validate TikTok username"""
    if not re.match(r'^[A-Za-z0-9._]{1,24}$', username):
        print("Invalid TikTok username", file=sys.stderr)
        sys.exit(64)


def validate_format(fmt):
    """Validate yt-dlp format"""
    valid_formats = [
        "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
        "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
        "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
        "hls-sd/hls-ld/flv-sd/flv-ld",
        "hls-ld/flv-ld",
        "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
    ]
    if fmt not in valid_formats:
        print("Invalid yt-dlp format", file=sys.stderr)
        sys.exit(64)


def get_load_per_cpu():
    """Get load per CPU"""
    try:
        with open("/proc/loadavg", "r") as f:
            load_avg = f.read().split()[0]
        cpu_count = os.cpu_count() or 1
        return float(load_avg) / max(1, cpu_count)
    except Exception:
        return 0.0


def check_dependencies():
    """Check if required dependencies are installed"""
    try:
        subprocess.run(["yt-dlp", "--version"], 
                      stdout=subprocess.DEVNULL, 
                      stderr=subprocess.DEVNULL, 
                      check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def run_yt_dlp(username, fmt, tmp_dir):
    """Run yt-dlp to get stream information"""
    live_url = f"https://www.tiktok.com/@{username}/live"
    
    try:
        result = subprocess.run([
            "yt-dlp",
            "--no-warnings",
            "--dump-single-json",
            "--skip-download",
            "--format", fmt,
            live_url
        ], capture_output=True, text=True, cwd=tmp_dir)
        
        stdout_file = os.path.join(tmp_dir, "stdout.json")
        stderr_file = os.path.join(tmp_dir, "stderr.log")
        
        with open(stdout_file, "w") as f:
            f.write(result.stdout)
        with open(stderr_file, "w") as f:
            f.write(result.stderr)
            
        return result.returncode, stdout_file, stderr_file
    except Exception as e:
        stderr_file = os.path.join(tmp_dir, "stderr.log")
        with open(stderr_file, "w") as f:
            f.write(str(e))
        return 1, None, stderr_file


def extract_url_from_json(json_file):
    """Extract valid URL from yt-dlp JSON output"""
    try:
        with open(json_file, "r") as f:
            data = json.load(f)
        
        candidates = []
        
        # Check direct URL
        if isinstance(data.get("url"), str):
            candidates.append(data["url"])
            
        # Check formats array
        for item in data.get("formats", []) or []:
            if isinstance(item, dict) and isinstance(item.get("url"), str):
                candidates.append(item["url"])
                
        # Find valid stream URL
        for value in candidates:
            low = value.lower()
            if (value.startswith("https://") and 
                (".m3u8" in low or ".flv" in low) and 
                "only_audio=1" not in low):
                return value
                
        return ""
    except Exception:
        return ""


def main():
    parser = argparse.ArgumentParser(description='Extract TikTok live stream URL using yt-dlp')
    parser.add_argument('username', help='TikTok username')
    parser.add_argument('format', nargs='?', default='best', help='Format selection')
    parser.add_argument('--json', action='store_true', help='Output JSON format')
    args = parser.parse_args()
    
    username = args.username.lstrip('@')
    fmt = args.format
    json_flag = args.json
    
    # Validate inputs
    validate_username(username)
    validate_format(fmt)
    
    # Get current timestamp
    timestamp = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    # Create temporary directory
    with tempfile.TemporaryDirectory(prefix='tiktok-yt-dlp.') as tmp_dir:
        # Check system load
        load_per_cpu = get_load_per_cpu()
        max_load = float(os.environ.get('TIKTOK_MAX_LOAD_PER_CPU', '1.5'))
        
        if load_per_cpu > max_load:
            emit_json(False, "yt-dlp", username, "", fmt, "host overloaded", timestamp, "overloaded")
            sys.exit(75)
            
        # Check dependencies
        if not check_dependencies():
            emit_json(False, "yt-dlp", username, "", fmt, "yt-dlp not installed", timestamp, "dependency_missing")
            sys.exit(2)
            
        # Run yt-dlp
        exit_code, stdout_file, stderr_file = run_yt_dlp(username, fmt, tmp_dir)
        
        if exit_code != 0:
            try:
                with open(stderr_file, "r") as f:
                    stderr_content = f.read()[:1000]
                    
                if any(keyword in stderr_content.lower() for keyword in 
                       ['not currently live', 'no live cdn found', 'not available', 'private video']):
                    status = "offline"
                    code = 1
                else:
                    status = "technical_error"
                    code = 2
                    
                emit_json(False, "yt-dlp", username, "", fmt, stderr_content, timestamp, status)
                sys.exit(code)
            except Exception as e:
                emit_json(False, "yt-dlp", username, "", fmt, str(e), timestamp, "technical_error")
                sys.exit(2)
                
        # Extract URL
        url = extract_url_from_json(stdout_file)
        if not url:
            emit_json(False, "yt-dlp", username, "", fmt, "could not extract HTTPS video URL", timestamp, "offline")
            sys.exit(1)
            
        # Output result
        if json_flag:
            emit_json(True, "yt-dlp", username, url, fmt, "", timestamp, "live")
        else:
            print(url)


if __name__ == "__main__":
    main()
