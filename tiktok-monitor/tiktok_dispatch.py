#!/usr/bin/env python3
"""Gemeinsamer TikTok-LIVE-Dispatcher ohne Einschränkung bestehender Methoden."""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

WORKSPACE = Path(__file__).resolve().parent.parent
PYTHON_MONITOR = WORKSPACE / "tiktok-monitor" / "tt-live.sh"
PLAYWRIGHT_MON = WORKSPACE / "skills" / "tiktok-live-mon" / "scripts"
PLAYWRIGHT_BASIC = WORKSPACE / "skills" / "tiktok-live" / "scripts"
URL_PREFIXES = ("http://", "https://")


@dataclass
class Attempt:
    method: str
    status: str
    exit_code: int | None
    detail: str
    url: str | None = None
    data: dict[str, Any] | None = None


def emit_log(attempt: Attempt) -> None:
    print(json.dumps(asdict(attempt), ensure_ascii=False), file=sys.stderr)


def run_command(command: list[str], timeout: int) -> tuple[int | None, str, str]:
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
    except FileNotFoundError as exc:
        return None, "", str(exc)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        return process.returncode, stdout.strip(), stderr.strip()
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            stdout, stderr = process.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            stdout, stderr = process.communicate()
        return None, stdout.strip(), f"timeout after {timeout}s; {stderr.strip()}".strip()


def parse_json_output(*outputs: str) -> dict[str, Any] | None:
    candidates: list[str] = []
    for output in outputs:
        candidates.append(output)
        candidates.extend(
            reversed([line for line in output.splitlines() if line.lstrip().startswith("{")])
        )
    for candidate in candidates:
        try:
            value = json.loads(candidate)
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(value, dict):
            return value
    return None


def extract_url(stdout: str, data: dict[str, Any] | None) -> str | None:
    if data:
        direct = data.get("url")
        if isinstance(direct, str) and direct.startswith(URL_PREFIXES):
            return direct
        streams = data.get("streams")
        if isinstance(streams, list):
            for stream in streams:
                if isinstance(stream, dict):
                    value = stream.get("url")
                    if isinstance(value, str) and value.startswith(URL_PREFIXES):
                        return value
    for line in reversed(stdout.splitlines()):
        value = line.strip()
        if value.startswith(URL_PREFIXES):
            return value
    return None


def classify(
    method: str,
    exit_code: int | None,
    stdout: str,
    stderr: str,
    operation: str,
) -> Attempt:
    data = parse_json_output(stdout, stderr)
    combined = f"{stdout}\n{stderr}".lower()
    url = extract_url(stdout, data)

    if exit_code is None and "timeout after" in stderr:
        return Attempt(method, "technical_error", None, stderr)
    dependency_markers = (
        "cannot find module",
        "executable doesn't exist",
        "not installed",
        "no such file or directory",
        "command not found",
    )
    if any(marker in combined for marker in dependency_markers):
        return Attempt(method, "dependency_missing", exit_code, stderr or stdout, data=data)
    restriction_markers = (
        "age-restricted",
        "altersbeschränkt",
        "mature content",
        "login erforderlich",
        "stream restricted",
    )
    if any(marker in combined for marker in restriction_markers):
        return Attempt(method, "restricted", exit_code, stderr or stdout, data=data)
    if data:
        explicit_status = data.get("status")
        if explicit_status in {
            "live",
            "offline",
            "restricted",
            "dependency_missing",
            "technical_error",
        }:
            return Attempt(
                method,
                explicit_status,
                exit_code,
                str(data.get("message") or data.get("error") or explicit_status),
                url=url,
                data=data,
            )
    if operation == "url" and url:
        return Attempt(method, "live", exit_code, "URL resolved", url=url, data=data)
    if data:
        live = data.get("live", data.get("isLive"))
        if live is True:
            return Attempt(method, "live", exit_code, "live=true", data=data)
        if live is False:
            return Attempt(method, "offline", exit_code, "live=false", data=data)
        if data.get("restricted") is True or data.get("isAgeRestricted") is True:
            return Attempt(method, "restricted", exit_code, "restriction reported", data=data)
    offline_markers = ("offline", "not live", "no stream", "user may not be live")
    if exit_code == 1 and any(marker in combined for marker in offline_markers):
        return Attempt(method, "offline", exit_code, stderr or stdout, data=data)
    return Attempt(
        method,
        "technical_error",
        exit_code,
        stderr or stdout or "empty result",
        data=data,
    )


def commands(operation: str, username: str, quality: str) -> list[tuple[str, list[str]]]:
    if operation == "check":
        return [
            ("python_webcast", ["bash", str(PYTHON_MONITOR), "check", username]),
            (
                "playwright_enhanced",
                ["node", str(PLAYWRIGHT_MON / "tiktok-check-profile.js"), username],
            ),
            (
                "playwright_basic",
                ["node", str(PLAYWRIGHT_BASIC / "tiktok-check-profile.js"), username],
            ),
        ]
    return [
        ("python_api_fallbacks", ["bash", str(PYTHON_MONITOR), "url", username]),
        (
            "playwright_streamlink_ytdlp",
            [
                "node",
                str(PLAYWRIGHT_MON / "tiktok-get-stream.js"),
                username,
                quality,
                "--json",
            ],
        ),
        (
            "playwright_network_basic",
            ["node", str(PLAYWRIGHT_BASIC / "tiktok-get-stream.js"), username],
        ),
    ]


def dispatch(args: argparse.Namespace) -> int:
    attempts: list[Attempt] = []
    for method, command in commands(args.operation, args.username, args.quality):
        attempt: Attempt | None = None
        for _ in range(args.retries + 1):
            exit_code, stdout, stderr = run_command(command, args.timeout)
            attempt = classify(method, exit_code, stdout, stderr, args.operation)
            emit_log(attempt)
            if attempt.status not in {"technical_error"}:
                break
        assert attempt is not None
        attempts.append(attempt)
        if args.operation == "url" and attempt.url:
            if args.json:
                print(json.dumps({"status": "live", "url": attempt.url,
                                  "method": method, "attempts": [asdict(a) for a in attempts]},
                                 ensure_ascii=False))
            else:
                print(attempt.url)
            return 0
        if args.operation == "check" and attempt.status in {"live", "restricted"}:
            print(json.dumps({"status": attempt.status, "method": method,
                              "result": attempt.data, "attempts": [asdict(a) for a in attempts]},
                             ensure_ascii=False))
            return 0 if attempt.status == "live" else 1

    statuses = {attempt.status for attempt in attempts}
    if args.operation == "check" and "offline" in statuses:
        print(json.dumps({
            "status": "offline",
            "method": "all_available_methods",
            "result": None,
            "attempts": [asdict(a) for a in attempts],
        }, ensure_ascii=False))
        return 1
    status = "dependency_missing" if statuses == {"dependency_missing"} else "technical_error"
    print(json.dumps({"status": status, "attempts": [asdict(a) for a in attempts]},
                     ensure_ascii=False))
    return 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("check", "url"))
    parser.add_argument("username")
    parser.add_argument("--quality", default="ld")
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--retries", type=int, choices=(0, 1), default=1)
    parser.add_argument("--json", action="store_true")
    return parser


if __name__ == "__main__":
    raise SystemExit(dispatch(build_parser().parse_args()))
