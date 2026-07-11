#!/usr/bin/env python3
"""Single public entry point for one-shot TikTok LIVE requests.

The cheap stateful Python resolver runs first. Bounded Playwright processes are
internal fallbacks only; callers must never invoke the Node scripts directly.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
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

ROOT = Path(__file__).resolve().parent.parent
MONITOR = ROOT / "tiktok-monitor" / "tt-live.sh"
PW_ENHANCED = ROOT / "skills" / "tiktok-live-mon"
PW_BASIC = ROOT / "skills" / "tiktok-live" / "scripts"


@dataclass
class Result:
    status: str
    method: str
    exit_code: int
    url: str | None = None


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


def python_first(operation: str, handle: str, timeout: int) -> Result:
    command = ["bash", str(MONITOR), operation, handle]
    if operation == "url":
        command.append("--verbose")
    code, stdout, stderr = run_bounded(command, timeout)
    data = json_object(stdout, stderr)
    url = find_url(stdout, data)
    source = "python_api"
    match = re.search(r"# source:\s*([A-Za-z0-9_-]+)", stderr)
    if match:
        source = f"python_{match.group(1).replace('-', '_')}"
    if operation == "url" and code == 0 and url:
        return Result("live", source, 0, url)
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
            return Result("restricted", method, EXIT_OFFLINE)
        if code == 0 and operation == "url" and url:
            return Result("live", method, 0, url)
        if code == 0 and operation == "check" and data:
            live = data.get("live", data.get("isLive"))
            if live is True:
                return Result("live", method, 0)
            if live is False:
                return Result("offline", method, EXIT_OFFLINE)
        if offline_text(stdout, stderr, json.dumps(data or {}, ensure_ascii=False)):
            return Result("offline", method, EXIT_OFFLINE)
        statuses.append("dependency_missing" if dependency_text(stdout, stderr) else "technical_error")
    if statuses and all(item == "offline" for item in statuses):
        return Result("offline", "all_node_fallbacks", EXIT_OFFLINE)
    if statuses and all(item == "dependency_missing" for item in statuses):
        return Result("dependency_missing", "all_node_fallbacks", EXIT_TECHNICAL)
    return Result("technical_error", "all_available_methods", EXIT_TECHNICAL)


def identity_sync(handle: str, timeout: int) -> None:
    run_bounded(["bash", str(MONITOR), "check", handle], timeout)


def dispatch(args: argparse.Namespace) -> int:
    first = python_first(args.operation, args.handle, args.timeout)
    if args.operation == "url" and first.status == "live" and first.url:
        final = first
    else:
        fallback = node_fallback(args.operation, args.handle, args.quality, args.timeout)
        if fallback.status in {"live", "offline", "restricted"}:
            final = fallback
            if not fallback.method.startswith("python_"):
                identity_sync(args.handle, min(args.timeout, 20))
        elif first.status == "live":
            final = first
        else:
            final = fallback
    payload: dict[str, Any] = {
        "status": final.status,
        "execution": os.environ.get("TIKTOK_EXECUTION_CONTEXT", "auto"),
        "node": os.environ.get("TIKTOK_NODE_ID"),
        "method": final.method,
        "exit_code": final.exit_code,
    }
    if final.url:
        payload["url"] = final.url
    if args.json or args.operation == "check":
        print(json.dumps(payload, ensure_ascii=False))
    elif final.url:
        print(final.url)
    return final.exit_code


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("operation", choices=("check", "url"))
    value.add_argument("handle", type=normalize_handle)
    value.add_argument("--json", action="store_true")
    value.add_argument("--quality", choices=("ld", "sd", "hd", "origin", "auto"), default="ld")
    value.add_argument("--timeout", type=int, choices=range(1, 121), default=45)
    return value


if __name__ == "__main__":
    raise SystemExit(dispatch(parser().parse_args()))
