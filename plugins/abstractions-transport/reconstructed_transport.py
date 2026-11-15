"""Reconstructed JSON/stdin transport for a node-bound translation launcher.

Launchers must be supplied by the operator and bound to the stated node by an
authorized execution service. This adapter does not establish node identity.
"""
from __future__ import annotations

import json
import subprocess
from collections.abc import Mapping, Sequence

MAX_REQUEST_BYTES = 2_000_000
MAX_RESPONSE_BYTES = 4_000_000
IDENTITY = ("job_id", "selected_node", "target_language")
INPUTS = ("source_text", "source_language", "source_name", "target_description", "system_prompt")


class TransportError(RuntimeError):
    pass


class TranslationTransport:
    def __init__(self, launchers: Mapping[str, Sequence[str]], timeout: float = 3900):
        self.launchers = {node: tuple(argv) for node, argv in launchers.items()}
        self.timeout = timeout
        if timeout <= 0 or any(not argv or any(not isinstance(s, str) or not s for s in argv)
                               for argv in self.launchers.values()):
            raise ValueError("invalid launcher or timeout")

    def __call__(self, job: dict) -> dict:
        if not isinstance(job, dict) or any(not isinstance(job.get(k), str) or not job[k].strip()
                                            for k in IDENTITY + INPUTS):
            raise TransportError("invalid translation job")
        argv = self.launchers.get(job["selected_node"])
        if not argv:
            raise TransportError("no authorized launcher for selected node")
        request = json.dumps(job, ensure_ascii=False).encode("utf-8")
        if len(request) > MAX_REQUEST_BYTES:
            raise TransportError("translation job exceeds worker limit")
        try:
            result = subprocess.run(argv, input=request, capture_output=True,
                                    timeout=self.timeout, check=False)
        except (OSError, subprocess.SubprocessError) as error:
            raise TransportError("worker could not complete") from error
        if result.returncode != 0:
            raise TransportError("worker exited unsuccessfully")
        if len(result.stdout) > MAX_RESPONSE_BYTES:
            raise TransportError("worker response too large")
        try:
            response = json.loads(result.stdout)
        except (ValueError, UnicodeDecodeError) as error:
            raise TransportError("worker returned invalid JSON") from error
        if not isinstance(response, dict) or any(response.get(k) != job[k] for k in IDENTITY):
            raise TransportError("worker response does not match job identity")
        if response.get("status") != "ok" or not isinstance(response.get("code"), str) or not response["code"].strip():
            raise TransportError("worker did not return a translation")
        return response
