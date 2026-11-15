"""Publish queued, provenance-checked artifacts without staging unrelated files."""
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request


def queue_artifact(state, root, path):
    root = Path(root).resolve()
    path = Path(path)
    if path.is_symlink():
        raise ValueError("artifact must not be a symlink")
    relative = path.resolve(strict=True).relative_to(root)
    if not relative.parts or relative.parts[0] not in {
        "perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"
    }:
        raise ValueError("artifact is outside a language directory")
    state.setdefault("ausstehende_veroeffentlichungen", {})[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()


def publish_pending(root, state, save, token, *, opener=urllib.request.urlopen):
    pending = state.get("ausstehende_veroeffentlichungen", {})
    if not isinstance(pending, dict):
        raise ValueError("invalid publication queue")
    if not pending:
        return True
    if not token or not token.strip():
        return False
    root = Path(root).resolve()
    headers = {"Authorization": "Bearer " + token.strip(), "Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "abstractions-manager"}
    success = True
    for name, expected in list(pending.items()):
        try:
            path = root / name
            if path.is_symlink() or path.resolve(strict=True).relative_to(root).as_posix() != name:
                raise ValueError("invalid queued path")
            data = path.read_bytes()
            if hashlib.sha256(data).hexdigest() != expected:
                raise ValueError("queued artifact changed")
            def lookup(remote_name):
                endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/" + urllib.parse.quote(remote_name, safe="/")
                request = urllib.request.Request(endpoint + "?ref=gateway1-abstractions", headers=headers)
                try:
                    with opener(request, timeout=60) as response:
                        return endpoint, json.load(response)
                except urllib.error.HTTPError as error:
                    if error.code != 404:
                        raise
                    error.close()
                    return endpoint, None

            def same(existing):
                return (isinstance(existing, dict) and existing.get("encoding") == "base64" and
                        base64.b64decode(existing.get("content", "")) == data)

            endpoint, existing = lookup(name)
            if existing is not None and not same(existing):
                # Independent managers can derive different results for one
                # source. Preserve both without overwriting the remote file.
                candidate = Path(name)
                alternate = (candidate.parent / (candidate.stem + "_" + expected[:12] + candidate.suffix)).as_posix()
                endpoint, existing = lookup(alternate)
                if existing is not None and not same(existing):
                    raise ValueError("remote artifact conflict")
            if existing is None:
                body = json.dumps({"message": "Publish script abstraction", "branch": "gateway1-abstractions",
                                   "content": base64.b64encode(data).decode("ascii")}).encode()
                request = urllib.request.Request(endpoint, data=body, headers=headers, method="PUT")
                with opener(request, timeout=60) as response:
                    json.load(response)
            del pending[name]
            save(state)
        except (OSError, ValueError, TypeError, KeyError, urllib.error.URLError):
            success = False
    return success
