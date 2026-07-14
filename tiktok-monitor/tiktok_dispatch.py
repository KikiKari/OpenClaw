#!/usr/bin/env python3
"""Single public entry point for one-shot TikTok LIVE requests.

The cheap stateful Python resolver runs first. Bounded Playwright processes are
internal fallbacks only; callers must never invoke the Node scripts directly.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

EXIT_OFFLINE = 1
EXIT_TECHNICAL = 2
EXIT_USAGE = 64
EXIT_OVERLOADED = 75
HANDLE_RE = re.compile(r"^[A-Za-z0-9._]{1,24}$")
URL_RE = re.compile(r"https?://[^\s\"'<>]+")
MAX_CAPTURE = 1024 * 1024
DEFAULT_MAX_ACTIVE = 1
OFFLINE_RECHECK_DELAY_SECONDS = 8
STREAM_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)

ROOT = Path(__file__).resolve().parent.parent
MONITOR = ROOT / "tiktok-monitor" / "tt-live.sh"
PW_ENHANCED = ROOT / "skills" / "tiktok-live-mon"
PW_BASIC = ROOT / "skills" / "tiktok-live" / "scripts"

# Engine import (same directory). Used only for identity write-back and the
# webcast room-info supplement; a broken engine must never break dispatch.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import tt_live
except Exception:  # noqa: BLE001 - any engine defect disables extras only
    tt_live = None

QUALITY_LABELS = {
    "origin": "Original", "uhd_60": "1080p60", "hd_60": "720p60",
    "hd": "720p", "sd": "540p", "ld": "360p", "ao": "Audio",
}
QUALITY_ORDER = ("origin", "uhd_60", "hd_60", "hd", "sd", "ld")


@dataclass
class Result:
    status: str
    method: str
    exit_code: int
    url: str | None = None
    info: dict | None = None
    qualities: list | None = None
    room_id: str | None = None
    source_data: dict | None = None  # raw fallback JSON; never serialized


def max_active_dispatchers() -> int:
    raw = os.environ.get("TIKTOK_DISPATCH_MAX_ACTIVE", str(DEFAULT_MAX_ACTIVE))
    try:
        return max(1, min(int(raw), 32))
    except ValueError:
        return DEFAULT_MAX_ACTIVE


def acquire_dispatch_slot() -> Any | None:
    """Acquire one non-blocking, per-host dispatcher slot."""
    lock_root = Path(os.environ.get("TIKTOK_DISPATCH_LOCK_DIR", "/tmp"))
    lock_root.mkdir(parents=True, exist_ok=True)
    for slot in range(max_active_dispatchers()):
        lock_file = (lock_root / f"openclaw-tiktok-dispatch-{os.getuid()}-{slot}.lock").open("a+")
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return lock_file
        except BlockingIOError:
            lock_file.close()
    return None


def payload_for(result: Result) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "status": result.status,
        "query_session": os.environ.get("TIKTOK_QUERY_SESSION_ID"),
        "execution": os.environ.get("TIKTOK_EXECUTION_CONTEXT", "auto"),
        "node": os.environ.get("TIKTOK_NODE_ID"),
        "method": result.method,
        "exit_code": result.exit_code,
    }
    if result.url:
        payload["url"] = result.url
    if result.info:
        payload["info"] = result.info
    if result.qualities:
        payload["qualities"] = result.qualities
    if result.room_id:
        payload["room_id"] = result.room_id
    return payload


def normalize_handle(raw: str) -> str:
    value = raw.strip().lstrip("@").lower()
    if not HANDLE_RE.fullmatch(value):
        raise argparse.ArgumentTypeError(
            "invalid TikTok handle; expected 1-24 letters, digits, dots, or underscores"
        )
    return value


def run_bounded(command: list[str], timeout: int) -> tuple[int | None, str, str]:
    with tempfile.TemporaryFile() as out_file, tempfile.TemporaryFile() as err_file:
        try:
            process = subprocess.Popen(
                command,
                stdout=out_file,
                stderr=err_file,
                start_new_session=True,
            )
        except (FileNotFoundError, PermissionError) as exc:
            return None, "", str(exc)
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        out_file.seek(0)
        err_file.seek(0)
        stdout = out_file.read(MAX_CAPTURE + 1)
        stderr = err_file.read(MAX_CAPTURE + 1)
        truncated = len(stdout) > MAX_CAPTURE or len(stderr) > MAX_CAPTURE
        out_text = stdout[:MAX_CAPTURE].decode("utf-8", "replace").strip()
        err_text = stderr[:MAX_CAPTURE].decode("utf-8", "replace").strip()
        if truncated:
            err_text = f"{err_text}\noutput truncated".strip()
        if timed_out:
            return None, out_text, f"timeout after {timeout}s; {err_text}".strip()
        return process.returncode, out_text, err_text


def json_object(*texts: str) -> dict[str, Any] | None:
    candidates: list[str] = []
    for text in texts:
        candidates.append(text)
        candidates.extend(reversed(text.splitlines()))
    for candidate in candidates:
        candidate = candidate.strip()
        if not candidate.startswith("{"):
            continue
        try:
            value = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    return None


def find_url(stdout: str, data: dict[str, Any] | None) -> str | None:
    if data:
        for key in ("url", "streamUrl", "stream_url"):
            value = data.get(key)
            if isinstance(value, str) and URL_RE.fullmatch(value):
                return value
        streams = data.get("streams")
        if isinstance(streams, list):
            for stream in streams:
                if isinstance(stream, dict):
                    value = stream.get("url")
                    if isinstance(value, str) and URL_RE.fullmatch(value):
                        return value
    for line in reversed(stdout.splitlines()):
        value = line.strip()
        if URL_RE.fullmatch(value):
            return value
    return None


def stream_url_is_playable(url: str, timeout: int) -> bool:
    """Accept only media URLs that currently return playable content."""
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": STREAM_USER_AGENT,
            "Accept": "application/vnd.apple.mpegurl,application/x-mpegURL,*/*",
            "Referer": "https://www.tiktok.com/",
            "Range": "bytes=0-4095",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=max(1, min(timeout, 15))) as response:
            sample = response.read(4096)
            if response.status not in (200, 206) or not sample:
                return False
            return ".m3u8" not in url.lower() or b"#EXTM3U" in sample
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError):
        return False


def restriction_text(*texts: str) -> bool:
    combined = " ".join(texts).lower()
    return any(marker in combined for marker in (
        "restricted", "age-restricted", "altersbeschränkt", "mature content",
        "login erforderlich", "stream became restricted",
    ))


def dependency_text(*texts: str) -> bool:
    combined = " ".join(texts).lower()
    return any(marker in combined for marker in (
        "cannot find module", "not installed", "command not found",
        "no such file", "executable doesn't exist",
    ))


def offline_text(*texts: str) -> bool:
    combined = " ".join(texts).lower()
    return any(marker in combined for marker in (
        "not currently live", "is not live", "user is offline", '"islive":false',
    ))


def resolved_quality_from_url(url: str) -> str:
    """Mirror the Playwright extractor's suffix → quality-key matching."""
    for key in QUALITY_ORDER:
        if f"_{key}." in url:
            return key
    if "_uhd." in url or "_full_hd" in url:
        return "uhd_60"
    return "unknown"


def qualities_from_streams(streams: Any) -> list:
    """Group captured Playwright stream URLs into the qualities payload shape."""
    merged: dict[str, dict] = {}
    seen: set[str] = set()
    for stream in streams if isinstance(streams, list) else []:
        if not isinstance(stream, dict):
            continue
        url = stream.get("url")
        if not isinstance(url, str) or not url:
            continue
        base = url.split("?", 1)[0]
        if base in seen:
            continue
        seen.add(base)
        key = stream.get("resolvedQuality") or resolved_quality_from_url(url)
        container = stream.get("container") or ("hls" if ".m3u8" in url else "flv")
        entry = merged.setdefault(key, {
            "key": key,
            "label": QUALITY_LABELS.get(key, key),
            "height": 0,
            "hls": None,
            "flv": None,
            "source": "playwright",
        })
        if container in ("hls", "flv") and not entry[container]:
            entry[container] = url
    order = {key: index for index, key in enumerate(QUALITY_ORDER)}

    def sort_key(entry: dict) -> tuple[int, int, str]:
        key = entry["key"]
        if key == "ao":
            return (2, 0, key)
        if key in order:
            return (0, order[key], "")
        return (1, 0, key)

    return sorted(merged.values(), key=sort_key)


def merge_qualities(primary: list, secondary: list) -> list:
    """Primary entries win; secondary entries fill missing keys/containers."""
    by_key: dict[str, dict] = {}
    ordered_keys: list[str] = []
    for entry in list(primary or []) + list(secondary or []):
        if not isinstance(entry, dict) or not entry.get("key"):
            continue
        key = entry["key"]
        if key not in by_key:
            by_key[key] = dict(entry)
            ordered_keys.append(key)
            continue
        for container in ("hls", "flv"):
            if not by_key[key].get(container) and entry.get(container):
                by_key[key][container] = entry[container]
    return [by_key[key] for key in ordered_keys]


def record_identity(data: dict | None) -> bool:
    """Persist an embedded fallback identity; never affects the dispatch result."""
    if tt_live is None or not isinstance(data, dict):
        return False
    identity = data.get("identity")
    if not isinstance(identity, dict):
        return False
    sec_uid = identity.get("secUid")
    unique_id = identity.get("uniqueId")
    if not sec_uid or not unique_id:
        return False
    try:
        store = tt_live.IdentityStore(tt_live.resolve_workspace())
        recorded, _ = store.update_from_scrape({
            "sec_uid": sec_uid,
            "unique_id": unique_id,
            "nickname": identity.get("nickname"),
            "user_id": identity.get("userId"),
        })
        return bool(recorded)
    except Exception as exc:  # noqa: BLE001 - observability only
        sys.stderr.write(f"# identity record failed: {exc}\n")
        return False


def enrich_live_result(result: Result) -> None:
    """Best-effort webcast room-info supplement for non-python live results."""
    if tt_live is None or result.info:
        return
    data = result.source_data or {}
    identity = data.get("identity") if isinstance(data, dict) else None
    room_id = str((identity or {}).get("roomId") or "").strip()
    if not room_id or room_id == "0":
        return
    result.room_id = room_id
    try:
        room_info = tt_live.fetch_room_info(room_id)
        if not room_info:
            return
        info = tt_live.summarize_room_info(room_info)
        if info:
            result.info = info
        api_qualities = tt_live.extract_all_qualities(room_info)
        if api_qualities:
            result.qualities = merge_qualities(api_qualities, result.qualities or [])
        owner = room_info.get("owner")
        if isinstance(owner, dict):
            tt_live.IdentityStore(tt_live.resolve_workspace()).update_from_owner(owner)
    except Exception as exc:  # noqa: BLE001 - supplement must never break dispatch
        sys.stderr.write(f"# room-info supplement failed: {exc}\n")


def python_first(operation: str, handle: str, timeout: int) -> Result:
    command = ["bash", str(MONITOR), operation, handle]
    if operation == "url":
        command.extend(["--verbose", "--json"])
    code, stdout, stderr = run_bounded(command, timeout)
    data = json_object(stdout, stderr)
    url = find_url(stdout, data)
    source = "python_api"
    match = re.search(r"# source:\s*([A-Za-z0-9_-]+)", stderr)
    if match:
        source = f"python_{match.group(1).replace('-', '_')}"
    elif isinstance(data, dict) and isinstance(data.get("source"), str):
        source = f"python_{data['source'].replace('-', '_')}"
    if operation == "url" and code == 0 and url:
        info = data.get("info") if isinstance(data, dict) else None
        qualities = data.get("qualities") if isinstance(data, dict) else None
        room_id = data.get("room_id") if isinstance(data, dict) else None
        return Result(
            "live", source, 0, url,
            info=info if isinstance(info, dict) and info else None,
            qualities=qualities if isinstance(qualities, list) and qualities else None,
            room_id=str(room_id) if room_id else None,
        )
    if operation == "check" and data:
        live = data.get("live")
        if live is True and code == 0:
            return Result("live", "python_webcast", 0)
        if live is False and code == EXIT_OFFLINE:
            return Result("offline", "python_webcast", EXIT_OFFLINE)
    if code == EXIT_OFFLINE:
        return Result("offline", source, EXIT_OFFLINE)
    status = "dependency_missing" if dependency_text(stdout, stderr) else "technical_error"
    return Result(status, source, EXIT_TECHNICAL)


def direct_media_fallback(handle: str, timeout: int) -> Result:
    """Resolve media without trusting TikTok's lagging profile live flag."""
    candidates = [
        (
            "direct_streamlink",
            [
                "streamlink", "--stream-url",
                f"https://www.tiktok.com/@{handle}/live",
                "720p,best,480p,360p,worst",
            ],
        ),
        (
            "direct_yt_dlp",
            [
                "yt-dlp", "-g", "-f", "best[height<=720]/best",
                f"https://www.tiktok.com/@{handle}/live",
            ],
        ),
    ]
    available = False
    for method, command in candidates:
        code, stdout, stderr = run_bounded(command, min(timeout, 45))
        if code is None and dependency_text(stderr):
            continue
        available = True
        url = find_url(stdout, json_object(stdout, stderr))
        if code == 0 and url and stream_url_is_playable(url, timeout):
            return Result("live", method, 0, url)
    return Result(
        "technical_error" if available else "dependency_missing",
        "direct_media_fallbacks",
        EXIT_TECHNICAL,
    )


def node_fallback(operation: str, handle: str, quality: str, timeout: int) -> Result:
    if operation == "check":
        candidates = [
            ("playwright_enhanced", PW_ENHANCED / "tiktok-check-profile.js", [handle]),
            ("playwright_basic", PW_BASIC / "tiktok-check-profile.js", [handle]),
        ]
    else:
        candidates = [
            ("playwright_streamlink_ytdlp", PW_ENHANCED / "tiktok-get-stream.js", [handle, quality, "--json"]),
            ("playwright_network_basic", PW_BASIC / "tiktok-get-stream.js", [handle, "--json"]),
        ]
    statuses: list[str] = []
    for method, script, extra in candidates:
        code, stdout, stderr = run_bounded(["node", str(script), *extra], timeout)
        data = json_object(stdout, stderr)
        url = find_url(stdout, data)
        if restriction_text(stdout, stderr, json.dumps(data or {}, ensure_ascii=False)):
            return Result("restricted", method, EXIT_OFFLINE, source_data=data)
        if code == 0 and operation == "url" and url:
            if stream_url_is_playable(url, timeout):
                qualities = qualities_from_streams(data.get("streams")) if data else []
                return Result(
                    "live", method, 0, url,
                    qualities=qualities or None,
                    source_data=data,
                )
            statuses.append("technical_error")
            continue
        if data and data.get("live", data.get("isLive")) is False:
            record_identity(data)
            statuses.append("offline")
            continue
        if code == 0 and operation == "check" and data:
            live = data.get("live", data.get("isLive"))
            if live is True:
                return Result("live", method, 0, source_data=data)
        if offline_text(stdout, stderr, json.dumps(data or {}, ensure_ascii=False)):
            statuses.append("offline")
            continue
        statuses.append("dependency_missing" if dependency_text(stdout, stderr) else "technical_error")
    if statuses and all(item == "offline" for item in statuses):
        return Result("offline", "all_node_fallbacks", EXIT_OFFLINE)
    if statuses and all(item == "dependency_missing" for item in statuses):
        return Result("dependency_missing", "all_node_fallbacks", EXIT_TECHNICAL)
    return Result("technical_error", "all_available_methods", EXIT_TECHNICAL)


def identity_sync(handle: str, timeout: int) -> bool:
    """Re-run the Python check to refresh the identity store; True on success."""
    code, _stdout, _stderr = run_bounded(["bash", str(MONITOR), "check", handle], timeout)
    return code in (0, EXIT_OFFLINE)


def dispatch(args: argparse.Namespace) -> int:
    slot = acquire_dispatch_slot()
    if slot is None:
        final = Result("overloaded", "concurrency_preflight", EXIT_OVERLOADED)
    else:
        try:
            first = python_first(args.operation, args.handle, args.timeout)
            if args.operation == "url" and first.status == "live" and first.url:
                final = first
            else:
                direct = (
                    direct_media_fallback(args.handle, args.timeout)
                    if args.operation == "url" and first.status == "offline"
                    else None
                )
                fallback = (
                    direct
                    if direct is not None and direct.status == "live"
                    else node_fallback(args.operation, args.handle, args.quality, args.timeout)
                )
                if first.status == "offline" and fallback.status == "offline":
                    # TikTok profile and webcast state can briefly lag a newly
                    # started stream. Require a delayed fresh resolution before
                    # publishing a terminal offline result.
                    time.sleep(OFFLINE_RECHECK_DELAY_SECONDS)
                    recheck = python_first(args.operation, args.handle, args.timeout)
                    if recheck.status == "live":
                        fallback = recheck
                    elif recheck.status != "offline":
                        fallback = Result(
                            "technical_error", "offline_recheck_inconclusive", EXIT_TECHNICAL
                        )
                    elif args.operation == "url":
                        direct_recheck = direct_media_fallback(args.handle, args.timeout)
                        if direct_recheck.status == "live":
                            fallback = direct_recheck
                if fallback.status == "offline" and first.status != "offline":
                    # A negative fallback cannot turn an unavailable or
                    # contradictory primary source into a terminal offline
                    # result. Publish uncertainty instead of a false negative.
                    final = Result("technical_error", "source_disagreement", EXIT_TECHNICAL)
                elif fallback.status in {"live", "offline", "restricted"}:
                    final = fallback
                    if not fallback.method.startswith("python_"):
                        recorded = record_identity(fallback.source_data)
                        if not recorded:
                            recorded = identity_sync(args.handle, min(args.timeout, 20))
                        if not recorded:
                            sys.stderr.write(
                                f"# identity not recorded for @{args.handle}: "
                                "no embedded identity and python check failed\n"
                            )
                        if fallback.status == "live":
                            enrich_live_result(fallback)
                elif first.status == "live":
                    final = first
                else:
                    final = fallback
        finally:
            fcntl.flock(slot.fileno(), fcntl.LOCK_UN)
            slot.close()
    payload = payload_for(final)
    if args.json or args.operation == "check" or final.status == "overloaded":
        print(json.dumps(payload, ensure_ascii=False))
    elif final.url:
        print(final.url)
    # Offline/restricted are successful domain results for structured tool
    # callers. Preserve the traditional semantic code inside the JSON payload,
    # but do not make OpenClaw render an expected result as a tool failure.
    if args.json and final.status in {"offline", "restricted"}:
        return 0
    return final.exit_code


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("operation", choices=("check", "url"))
    value.add_argument("handle", type=normalize_handle)
    value.add_argument("--json", action="store_true")
    value.add_argument(
        "--quality",
        choices=(
            "ld", "sd", "hd", "hd_60", "uhd_60", "origin", "auto",
            "360p", "540p", "720p", "720p60", "1080p60", "original",
        ),
        default="hd",
    )
    value.add_argument("--timeout", type=int, choices=range(1, 121), default=45)
    return value


if __name__ == "__main__":
    raise SystemExit(dispatch(parser().parse_args()))
