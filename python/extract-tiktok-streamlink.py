#!/usr/bin/env python3
# extract-tiktok-streamlink.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
import json
import subprocess
import re
from datetime import datetime
import os

def emit_json(success, method, username, url, quality, author, title, error, timestamp, status):
    payload = {
        "success": success.lower() == "true",
        "method": method,
        "username": username,
        "url": url,
        "quality": quality,
        "author": author,
        "title": title,
        "error": error,
        "timestamp": timestamp,
        "status": status
    }
    # Remove empty values
    payload = {k: v for k, v in payload.items() if v}
    print(json.dumps(payload, ensure_ascii=False))

def get_load_per_cpu():
    try:
        load_avg = os.getloadavg()[0]
        cpu_count = max(1, os.cpu_count() or 1)
        return load_avg / cpu_count
    except:
        return 0.0

def validate_username(username):
    pattern = r'^[A-Za-z0-9._]{1,24}$'
    return bool(re.match(pattern, username))

def validate_quality(quality):
    valid_qualities = ['best', 'worst', 'original', '1080p60', '720p60', '720p', '540p', '360p', 'auto']
    return quality in valid_qualities

def run_streamlink(args):
    try:
        result = subprocess.run(
            ['streamlink'] + args,
            capture_output=True,
            text=True
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, "", "streamlink not found"

def main():
    if len(sys.argv) < 2:
        print("Invalid TikTok username", file=sys.stderr)
        sys.exit(64)
    
    USERNAME = sys.argv[1].lstrip('@')
    QUALITY = sys.argv[2] if len(sys.argv) > 2 else 'best'
    JSON_FLAG = sys.argv[3] if len(sys.argv) > 3 else ''
    TIMESTAMP = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    if not validate_username(USERNAME):
        print("Invalid TikTok username", file=sys.stderr)
        sys.exit(64)
        
    if not validate_quality(QUALITY):
        print("Invalid stream quality", file=sys.stderr)
        sys.exit(64)
    
    LOAD_PER_CPU = get_load_per_cpu()
    MAX_LOAD = float(os.environ.get('TIKTOK_MAX_LOAD_PER_CPU', '1.5'))
    
    if LOAD_PER_CPU > MAX_LOAD:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                 "host overloaded", TIMESTAMP, "overloaded")
        sys.exit(75)
    
    returncode, _, _ = run_streamlink(['--help'])
    if returncode == -1:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                 "streamlink not installed", TIMESTAMP, "dependency_missing")
        sys.exit(2)
    
    LIVE_URL = f"https://www.tiktok.com/@{USERNAME}/live"
    
    quality_map = {
        "original": ["origin", "uhd_60", "hd_60", "hd", "sd", "ld", "best", "worst"],
        "auto": ["best", "origin", "uhd_60", "hd_60", "hd", "sd", "ld", "worst"],
        "1080p60": ["uhd_60", "hd_60", "hd", "sd", "ld", "worst"],
        "720p60": ["hd_60", "hd", "sd", "ld", "worst"],
        "720p": ["hd", "sd", "ld", "worst"],
        "540p": ["sd", "ld", "worst"],
        "360p": ["ld", "worst"]
    }
    
    if QUALITY in quality_map:
        SELECTOR = ",".join(quality_map[QUALITY])
    else:
        SELECTOR = QUALITY
    
    # Try with --json first
    exit_code, output, _ = run_streamlink(['--json', LIVE_URL, SELECTOR])
    
    if exit_code != 0 or not output.strip():
        # Fallback to --stream-url
        exit_code, url, _ = run_streamlink(['--stream-url', LIVE_URL, SELECTOR])
        if exit_code != 0 or not url.strip():
            emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                     "streamlink failed or no stream found", TIMESTAMP, "offline")
            sys.exit(1)
            
        url = url.strip()
        if JSON_FLAG == "--json":
            emit_json("true", "streamlink", USERNAME, url, QUALITY, "", "", "", TIMESTAMP, "live")
        else:
            print(url)
        sys.exit(0)
    
    try:
        data = json.loads(output)
        url = data.get("url", "")
        streams = data.get("streams", {})
        
        if not url and isinstance(streams, dict):
            for key in ["best", "worst"] + list(streams.keys()):
                value = streams.get(key)
                if isinstance(value, dict) and value.get("url"):
                    url = value["url"]
                    break
                    
        metadata = data.get("metadata", {})
        author = metadata.get("author", "")
        title = metadata.get("title", "")
        
        if not url:
            emit_json("false", "streamlink", USERNAME, "", QUALITY, author, title, 
                     "could not extract stream URL", TIMESTAMP, "offline")
            sys.exit(1)
            
        if JSON_FLAG == "--json":
            emit_json("true", "streamlink", USERNAME, url, QUALITY, author, title, "", TIMESTAMP, "live")
        else:
            print(url)
            
    except json.JSONDecodeError:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                 "invalid streamlink JSON", TIMESTAMP, "technical_error")
        sys.exit(2)

if __name__ == "__main__":
    main()
