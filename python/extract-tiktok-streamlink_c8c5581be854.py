#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d0e0f885103a7f6b9870cd1dff8f8f97bd91671346a08104785f7ca502ae1c84", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "python"}
# extract-tiktok-streamlink.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
    payload = {k: v for k, v in payload.items() if v != ""}
    print(json.dumps(payload, ensure_ascii=False))

def get_load_per_cpu():
    try:
        with open("/proc/loadavg", "r") as f:
            load_avg = f.read().split()[0]
        cpu_count = os.cpu_count() or 1
        return float(load_avg) / max(1, cpu_count)
    except:
        return 0.0

def validate_username(username):
    return bool(re.match(r'^[A-Za-z0-9._]{1,24}$', username))

def validate_quality(quality):
    valid_qualities = ["best", "worst", "original", "1080p60", "720p60", "720p", "540p", "360p", "auto"]
    return quality in valid_qualities

def get_stream_selector(quality):
    selectors = {
        "original": "origin,uhd_60,hd_60,hd,sd,ld,best,worst",
        "auto": "best,origin,uhd_60,hd_60,hd,sd,ld,worst",
        "1080p60": "uhd_60,hd_60,hd,sd,ld,worst",
        "720p60": "hd_60,hd,sd,ld,worst",
        "720p": "hd,sd,ld,worst",
        "540p": "sd,ld,worst",
        "360p": "ld,worst"
    }
    return selectors.get(quality, quality)

def run_streamlink_command(args):
    try:
        result = subprocess.run(
            ["streamlink"] + args,
            capture_output=True,
            text=True
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, "", "streamlink not found"

def parse_streamlink_json(output):
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
        
        return {"url": url, "author": author, "title": title}
    except:
        return None

def main():
    if len(sys.argv) < 2:
        print("Invalid TikTok username", file=sys.stderr)
        sys.exit(64)
    
    USERNAME = sys.argv[1].lstrip('@')
    QUALITY = sys.argv[2] if len(sys.argv) > 2 else "best"
    JSON_FLAG = sys.argv[3] if len(sys.argv) > 3 else ""
    TIMESTAMP = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    if not validate_username(USERNAME):
        print("Invalid TikTok username", file=sys.stderr)
        sys.exit(64)
    
    if not validate_quality(QUALITY):
        print("Invalid stream quality", file=sys.stderr)
        sys.exit(64)
    
    LOAD_PER_CPU = get_load_per_cpu()
    MAX_LOAD = float(os.environ.get("TIKTOK_MAX_LOAD_PER_CPU", "1.5"))
    
    if LOAD_PER_CPU > MAX_LOAD:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                 "host overloaded", TIMESTAMP, "overloaded")
        sys.exit(75)
    
    returncode, _, _ = run_streamlink_command(["--version"])
    if returncode == -1:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                 "streamlink not installed", TIMESTAMP, "dependency_missing")
        sys.exit(2)
    
    LIVE_URL = f"https://www.tiktok.com/@{USERNAME}/live"
    SELECTOR = get_stream_selector(QUALITY)
    
    returncode, output, _ = run_streamlink_command(["--json", LIVE_URL, SELECTOR])
    
    if returncode != 0 or not output:
        returncode, url, _ = run_streamlink_command(["--stream-url", LIVE_URL, SELECTOR])
        if returncode != 0 or not url:
            emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                     "streamlink failed or no stream found", TIMESTAMP, "offline")
            sys.exit(1)
        
        if JSON_FLAG == "--json":
            emit_json("true", "streamlink", USERNAME, url.strip(), QUALITY, "", "", 
                     "", TIMESTAMP, "live")
        else:
            print(url.strip())
        sys.exit(0)
    
    parsed_data = parse_streamlink_json(output)
    if parsed_data is None:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, "", "", 
                 "invalid streamlink JSON", TIMESTAMP, "technical_error")
        sys.exit(2)
    
    URL = parsed_data["url"]
    AUTHOR = parsed_data["author"]
    TITLE = parsed_data["title"]
    
    if not URL:
        emit_json("false", "streamlink", USERNAME, "", QUALITY, AUTHOR, TITLE, 
                 "could not extract stream URL", TIMESTAMP, "offline")
        sys.exit(1)
    
    if JSON_FLAG == "--json":
        emit_json("true", "streamlink", USERNAME, URL, QUALITY, AUTHOR, TITLE, 
                 "", TIMESTAMP, "live")
    else:
        print(URL)

if __name__ == "__main__":
    main()
