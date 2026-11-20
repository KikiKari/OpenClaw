"""Publish queued, provenance-checked artifacts without staging unrelated files."""
from __future__ import annotations

import base64
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

LANGUAGES = frozenset({"perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"})


def synchronize_checkout(root, *, remote="https://github.com/KikiKari/OpenClaw.git",
                         branch="gateway1-abstractions"):
    """Reconcile a remote snapshot into the checkout without changing its Git history."""
    root = Path(root).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="abstractions-snapshot-") as tmp:
        snapshot = Path(tmp) / "repo"
        subprocess.run(["git", "clone", "--quiet", "--depth=1", "--single-branch",
                        "--branch", branch, "--", remote, str(snapshot)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300)
        revision = subprocess.check_output(["git", "-C", str(snapshot), "rev-parse", "HEAD"],
                                           text=True, timeout=30).strip()
        counts = {}
        for language in sorted(LANGUAGES):
            source = snapshot / language
            target = root / language
            if source.is_symlink() or target.is_symlink():
                raise ValueError("language directory is a symlink")
            if source.exists() and not source.is_dir():
                raise ValueError("invalid remote language directory")
            target.mkdir(exist_ok=True)
            known = {hashlib.sha256(p.read_bytes()).hexdigest() for p in target.iterdir()
                     if p.is_file() and not p.is_symlink()}
            files = sorted(source.iterdir()) if source.exists() else []
            if any(p.is_symlink() or not p.is_file() for p in files):
                raise ValueError("invalid remote abstraction")
            counts[language] = len(files)
            for item in files:
                data = item.read_bytes()
                digest = hashlib.sha256(data).hexdigest()
                if digest in known:
                    continue
                destination = target / item.name
                if destination.exists() or destination.is_symlink():
                    destination = target / (item.stem + "__pool_" + digest + item.suffix)
                try:
                    with destination.open("xb") as output:
                        output.write(data)
                except FileExistsError:
                    if destination.is_symlink() or not destination.is_file() or destination.read_bytes() != data:
                        raise ValueError("local abstraction conflict")
                known.add(digest)
        return revision, counts


def update_status_counts(path, revision, counts):
    text = path.read_text(encoding="utf-8")
    rows = ["## Bestand", "", f"GitHub-Stand: `{revision}`", "",
            "| Zielsprache | Dateien |", "|---|---:|"]
    rows.extend(f"| {language} | {counts[language]} |" for language in sorted(LANGUAGES))
    rows.extend([f"| **gesamt** | **{sum(counts.values())}** |", "", ""])
    updated, count = re.subn(r"(?ms)^## Bestand\n.*?(?=^## Quellen\n)",
                             lambda _: "\n".join(rows), text, count=1)
    if count != 1:
        raise ValueError("status inventory section missing")
    path.write_text(updated, encoding="utf-8")


def queue_artifact(state, root, path):
    root = Path(root).resolve()
    path = Path(path)
    if path.is_symlink():
        raise ValueError("artifact must not be a symlink")
    relative = path.resolve(strict=True).relative_to(root)
    if relative.as_posix() != 'STATUS.md' and (not relative.parts or relative.parts[0] not in {
        "perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"
    }):
        raise ValueError("artifact is outside a language directory")
    state.setdefault("ausstehende_veroeffentlichungen", {})[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()


def publish_pending(root, state, save, token, *, opener=urllib.request.urlopen, sync=None):
    pending = state.get("ausstehende_veroeffentlichungen", {})
    if not isinstance(pending, dict):
        raise ValueError("invalid publication queue")
    if not pending and sync is None:
        return True
    if not token or not token.strip():
        return False
    root = Path(root).resolve()
    headers = {"Authorization": "Bearer " + token.strip(), "Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "abstractions-manager"}
    success = True
    entries = sorted(list(pending.items()), key=lambda item: item[0] == 'STATUS.md')
    synced = False
    for name, expected in entries:
        try:
            path = root / name
            if path.is_symlink() or path.resolve(strict=True).relative_to(root).as_posix() != name:
                raise ValueError("invalid queued path")
            data = path.read_bytes()
            if hashlib.sha256(data).hexdigest() != expected:
                raise ValueError("queued artifact changed")
            if name == 'STATUS.md' and sync is not None:
                if not success:
                    raise ValueError("artifact publication incomplete")
                revision, counts = sync(root)
                synced = True
                update_status_counts(path, revision, counts)
                data = path.read_bytes()
                expected = hashlib.sha256(data).hexdigest()
                pending[name] = expected
                save(state)
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
            if name == 'STATUS.md' and existing is not None and not same(existing):
                sha = existing.get('sha') if isinstance(existing, dict) else None
                if not isinstance(sha, str) or not sha:
                    raise ValueError('missing remote status version')
                body = json.dumps({'message': 'Update abstraction status', 'branch': 'gateway1-abstractions',
                                   'content': base64.b64encode(data).decode('ascii'), 'sha': sha}).encode()
                request = urllib.request.Request(endpoint, data=body, headers=headers, method='PUT')
                with opener(request, timeout=60) as response:
                    json.load(response)
            elif existing is not None and not same(existing):
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
        except (OSError, ValueError, TypeError, KeyError, urllib.error.URLError, subprocess.SubprocessError):
            success = False
    if sync is not None and not synced:
        try:
            sync(root)
        except (OSError, ValueError, subprocess.SubprocessError):
            success = False
    return success
