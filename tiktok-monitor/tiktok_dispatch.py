#!/usr/bin/env python3
"""TikTok LIVE dispatcher with portable paths and agent-managed node routing.

The gateway remains a complete local executor. A calling OpenClaw agent may
run this same entry point on a paired node through ``exec host=node``. Results
are normalized to the live/offline/restricted/dependency_missing/
technical_error/overloaded contract; non-JSON URL mode keeps stdout URL-only.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import signal
import subprocess
import sys
import tempfile
import uuid
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

EXIT_OFFLINE = 1
EXIT_TECHNICAL = 2
EXIT_USAGE = 64
EXIT_OVERLOADED = 75
USERNAME_PATTERN = re.compile(r"^[A-Za-z0-9._]{1,24}$")
URL_PREFIXES = ("http://", "https://")
MAX_CAPTURE_BYTES = 1024 * 1024
NODE_STATUS_TIMEOUT_SECONDS = 30

def resolve_workspace() -> Path:
    configured = os.environ.get("OPENCLAW_WORKSPACE", "").strip()
    if configured:
        return Path(configured).expanduser().resolve()
    return Path(__file__).resolve().parent.parent


WORKSPACE = resolve_workspace()
PYTHON_MONITOR = WORKSPACE / "tiktok-monitor" / "tt-live.sh"
PLAYWRIGHT_MON = WORKSPACE / "skills" / "tiktok-live-mon" / "scripts"
PLAYWRIGHT_BASIC = WORKSPACE / "skills" / "tiktok-live" / "scripts"


@dataclass
class Attempt:
    method: str
    status: str
    exit_code: int | None
    detail: str
    url: str | None = None
    data: dict[str, Any] | None = None


def normalize_username(raw: str) -> str:
    username = raw.strip().lstrip("@")
    if not USERNAME_PATTERN.fullmatch(username):
        raise ValueError(
            "invalid TikTok username; expected 1-24 letters, digits, dots, or underscores"
        )
    return username


def load_state() -> tuple[float, float]:
    cpu_count = max(1, os.cpu_count() or 1)
    override = os.environ.get("TIKTOK_TEST_LOAD_PER_CPU")
    observed = float(override) if override is not None else os.getloadavg()[0] / cpu_count
    maximum = float(os.environ.get("TIKTOK_MAX_LOAD_PER_CPU", "1.5"))
    if observed < 0 or maximum <= 0:
        raise ValueError("invalid TikTok load configuration")
    return observed, maximum


def emit_log(value: Any) -> None:
    payload = asdict(value) if hasattr(value, "__dataclass_fields__") else value
    if isinstance(payload, dict):
        payload = dict(payload)
        payload.pop("url", None)
        data = payload.get("data")
        if isinstance(data, dict):
            payload["data"] = {
                key: ("<redacted-url>" if key in {"url", "streams", "allUrls"} else item)
                for key, item in data.items()
            }
    print(json.dumps(payload, ensure_ascii=False), file=sys.stderr)


def run_command(command: list[str], timeout: int) -> tuple[int | None, str, str]:
    with tempfile.TemporaryFile() as stdout_file, tempfile.TemporaryFile() as stderr_file:
        try:
            process = subprocess.Popen(
                command,
                stdout=stdout_file,
                stderr=stderr_file,
                start_new_session=True,
            )
        except FileNotFoundError as exc:
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
        stdout_file.seek(0)
        stderr_file.seek(0)
        stdout_raw = stdout_file.read(MAX_CAPTURE_BYTES + 1)
        stderr_raw = stderr_file.read(MAX_CAPTURE_BYTES + 1)
        truncated = len(stdout_raw) > MAX_CAPTURE_BYTES or len(stderr_raw) > MAX_CAPTURE_BYTES
        stdout = stdout_raw[:MAX_CAPTURE_BYTES].decode("utf-8", errors="replace").strip()
        stderr = stderr_raw[:MAX_CAPTURE_BYTES].decode("utf-8", errors="replace").strip()
        if truncated:
            stderr = f"{stderr}\noutput truncated at {MAX_CAPTURE_BYTES} bytes".strip()
        if timed_out:
            return None, stdout, f"timeout after {timeout}s; {stderr}".strip()
        return process.returncode, stdout, stderr


def positive_bounded_timeout(value: str) -> int:
    timeout = int(value)
    if not 1 <= timeout <= 120:
        raise argparse.ArgumentTypeError("timeout must be between 1 and 120 seconds")
    return timeout


def run_json_command(command: list[str], timeout: int = 10) -> Any | None:
    exit_code, stdout, _ = run_command(command, timeout)
    if exit_code != 0 or not stdout:
        return None
    try:
        return json.loads(stdout)
    except json.JSONDecodeError:
        return None


def validated_node_load(row: dict[str, Any]) -> float | None:
    raw = row.get("_validatedLoadPerCpu", row.get("loadPerCpu"))
    if raw is None:
        return None
    try:
        load = float(raw)
    except (TypeError, ValueError):
        return None
    return load if load >= 0 and math.isfinite(load) else None


def connected_system_run_nodes() -> list[dict[str, Any]]:
    payload = run_json_command(
        ["openclaw", "nodes", "status", "--connected", "--json"],
        timeout=NODE_STATUS_TIMEOUT_SECONDS,
    )
    if isinstance(payload, dict):
        rows = payload.get("nodes", payload.get("items", []))
    else:
        rows = payload
    if not isinstance(rows, list):
        return []
    candidates = []
    for row in rows:
        if not isinstance(row, dict) or row.get("connected") is False:
            continue
        commands = row.get("commands", [])
        if isinstance(commands, list) and "system.run" in commands:
            row = dict(row)
            row["_validatedLoadPerCpu"] = validated_node_load(row)
            candidates.append(row)
    return candidates


def select_node(requested: str | None = None) -> str | None:
    candidates = [dict(row) for row in connected_system_run_nodes()]
    for row in candidates:
        row["_validatedLoadPerCpu"] = validated_node_load(row)
    if requested:
        for row in candidates:
            aliases = {
                str(row.get("nodeId", "")),
                str(row.get("id", "")),
                str(row.get("name", "")),
                str(row.get("displayName", "")),
            }
            if requested in aliases:
                return str(
                    row.get("nodeId")
                    or row.get("id")
                    or row.get("name")
                    or row.get("displayName")
                )
        return None
    candidates.sort(
        key=lambda row: (
            row["_validatedLoadPerCpu"] is None,
            (
                row["_validatedLoadPerCpu"]
                if row["_validatedLoadPerCpu"] is not None
                else float("inf")
            ),
            str(row.get("nodeId", row.get("id", row.get("name", "")))),
        )
    )
    if not candidates:
        return None
    row = candidates[0]
    return str(row.get("nodeId", row.get("id", row.get("name", "")))) or None


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
    url = extract_url(stdout, data)
    if exit_code == EXIT_OVERLOADED:
        return Attempt(method, "overloaded", exit_code, stderr or "host overloaded", data=data)
    if exit_code is None and "timeout after" in stderr:
        return Attempt(method, "technical_error", None, stderr)
    if data:
        explicit_status = data.get("status")
        if explicit_status in {
            "live", "offline", "restricted", "overloaded",
            "dependency_missing", "technical_error",
        }:
            if explicit_status == "live" and exit_code != 0:
                return Attempt(method, "technical_error", exit_code, "live status conflicts with nonzero exit", data=data)
            if explicit_status != "live":
                url = None
            return Attempt(
                method, explicit_status, exit_code,
                str(data.get("message") or data.get("error") or explicit_status),
                url=url, data=data,
            )
        live = data.get("live", data.get("isLive"))
        if live is True:
            if exit_code != 0:
                return Attempt(method, "technical_error", exit_code, "live=true conflicts with nonzero exit", data=data)
            return Attempt(method, "live", exit_code, "live=true", url=url, data=data)
        if live is False:
            return Attempt(method, "offline", exit_code, "live=false", data=data)
    combined = stderr.lower()
    if any(marker in combined for marker in (
        "cannot find module", "executable doesn't exist", "not installed",
        "no such file or directory", "command not found",
    )):
        return Attempt(method, "dependency_missing", exit_code, stderr or stdout, data=data)
    if any(marker in combined for marker in (
        "age-restricted", "altersbeschränkt", "mature content",
        "login erforderlich", "stream restricted",
    )):
        return Attempt(method, "restricted", exit_code, stderr or stdout, data=data)
    if operation == "url" and url and exit_code == 0:
        return Attempt(method, "live", exit_code, "URL resolved", url=url, data=data)
    if exit_code == EXIT_OFFLINE:
        return Attempt(method, "offline", exit_code, stderr or "offline", data=data)
    return Attempt(method, "technical_error", exit_code, stderr or stdout or "empty result", data=data)


def commands(operation: str, username: str, quality: str) -> list[tuple[str, list[str]]]:
    if operation == "check":
        return [
            ("python_webcast", ["bash", str(PYTHON_MONITOR), "check", username]),
            ("playwright_enhanced", ["node", str(PLAYWRIGHT_MON / "tiktok-check-profile.js"), username]),
            ("playwright_basic", ["node", str(PLAYWRIGHT_BASIC / "tiktok-check-profile.js"), username]),
        ]
    return [
        ("python_api_fallbacks", ["bash", str(PYTHON_MONITOR), "url", username]),
        ("playwright_streamlink_ytdlp", [
            "node", str(PLAYWRIGHT_MON / "tiktok-get-stream.js"),
            username, quality, "--json",
        ]),
        ("playwright_network_basic", [
            "node", str(PLAYWRIGHT_BASIC / "tiktok-get-stream.js"), username, "--json",
        ]),
    ]


def result_payload(
    status: str,
    method: str,
    exit_code: int,
    attempts: list[Attempt],
    url: str | None = None,
) -> dict[str, Any]:
    context = os.environ.get("TIKTOK_EXECUTION_CONTEXT", "gateway")
    node = os.environ.get("TIKTOK_NODE_ID") if context == "node" else None
    result: dict[str, Any] = {
        "status": status,
        "execution": context,
        "node": node,
        "method": method,
        "exit_code": exit_code,
        "attempts": [asdict(attempt) for attempt in attempts],
    }
    if url:
        result["url"] = url
    return result


def resolve_url_for_live(
    args: argparse.Namespace,
    attempts: list[Attempt],
) -> tuple[str | None, str | None]:
    for method, command in commands("url", args.username, args.quality):
        attempt: Attempt | None = None
        for _ in range(args.retries + 1):
            exit_code, stdout, stderr = run_command(command, args.timeout)
            attempt = classify(method, exit_code, stdout, stderr, "url")
            emit_log(attempt)
            if attempt.status != "technical_error":
                break
        assert attempt is not None
        attempts.append(attempt)
        if attempt.status == "live" and attempt.url:
            return attempt.url, method
    return None, None


def dispatch_local(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    attempts: list[Attempt] = []
    tentative_python_live: Attempt | None = None
    for method, command in commands(args.operation, args.username, args.quality):
        attempt: Attempt | None = None
        for _ in range(args.retries + 1):
            exit_code, stdout, stderr = run_command(command, args.timeout)
            attempt = classify(method, exit_code, stdout, stderr, args.operation)
            emit_log(attempt)
            if attempt.status != "technical_error":
                break
        assert attempt is not None
        attempts.append(attempt)
        if args.operation == "url" and attempt.status == "live" and attempt.url:
            return result_payload("live", method, 0, attempts, attempt.url), 0
        if args.operation == "check" and attempt.status == "restricted":
            return result_payload("restricted", method, 1, attempts), 1
        if args.operation == "check" and attempt.status == "live":
            if method == "python_webcast":
                # The API can establish LIVE state, but it cannot identify
                # login/content restrictions visible only on the web page.
                tentative_python_live = attempt
                continue
            url, url_method = resolve_url_for_live(args, attempts)
            return result_payload(
                "live",
                f"{method}+{url_method}" if url_method else method,
                0,
                attempts,
                url,
            ), 0
    statuses = {attempt.status for attempt in attempts}
    if "overloaded" in statuses:
        return result_payload("overloaded", "all_available_methods", 75, attempts), 75
    if tentative_python_live is not None:
        url, url_method = resolve_url_for_live(args, attempts)
        return result_payload(
            "live",
            (
                f"{tentative_python_live.method}+{url_method}"
                if url_method else tentative_python_live.method
            ),
            0,
            attempts,
            url,
        ), 0
    if statuses == {"offline"}:
        return result_payload("offline", "all_available_methods", 1, attempts), 1
    status = "dependency_missing" if statuses == {"dependency_missing"} else "technical_error"
    return result_payload(status, "all_available_methods", 2, attempts), 2


def dispatch(args: argparse.Namespace) -> int:
    observed, maximum = load_state()
    if observed > maximum:
        payload = result_payload("overloaded", "preflight", 75, [])
        payload.update({"loadPerCpu": round(observed, 3), "maximum": maximum})
        emit_log(payload)
        if args.json:
            print(json.dumps(payload, ensure_ascii=False))
        return 75

    selected = None
    if args.execution in {"auto", "node"} and os.environ.get("TIKTOK_EXECUTION_CONTEXT") != "node":
        selected = select_node(args.node)
        if selected:
            emit_log({
                "status": "node_available",
                "node": selected,
                "idempotency_key": args.idempotency_key,
                "message": (
                    "Run this dispatcher on the selected node through the OpenClaw exec tool "
                    "with host=node; direct CLI system.run invocation is intentionally blocked."
                ),
            })
            if args.no_local_fallback:
                payload = result_payload("technical_error", "routing", 2, [])
                payload["node"] = selected
                payload["message"] = "node dispatch requires OpenClaw exec host=node"
                if args.json:
                    print(json.dumps(payload, ensure_ascii=False))
                return 2
        elif args.execution == "node" and args.no_local_fallback:
            payload = result_payload("technical_error", "routing", 2, [])
            payload["message"] = "no connected paired node supporting system.run"
            if args.json:
                print(json.dumps(payload, ensure_ascii=False))
            return 2

    payload, code = dispatch_local(args)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False))
    elif args.operation == "url" and payload.get("url"):
        print(payload["url"])
    elif args.operation == "check":
        print(json.dumps(payload, ensure_ascii=False))
    return code


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("check", "url"))
    parser.add_argument("username", type=normalize_username)
    parser.add_argument("--quality", default="ld", choices=("ld", "sd", "hd", "origin", "auto"))
    parser.add_argument("--timeout", type=positive_bounded_timeout, default=45)
    parser.add_argument("--retries", type=int, choices=(0, 1), default=1)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--execution", choices=("auto", "local", "node"), default="auto")
    parser.add_argument("--node")
    parser.add_argument("--no-local-fallback", action="store_true")
    parser.add_argument("--idempotency-key", default=None)
    return parser


if __name__ == "__main__":
    parsed = build_parser().parse_args()
    parsed.idempotency_key = parsed.idempotency_key or str(uuid.uuid4())
    raise SystemExit(dispatch(parsed))
