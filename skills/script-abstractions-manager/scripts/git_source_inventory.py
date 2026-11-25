"""Git tree inventory and batched selected-blob loading."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess


def write_private(path, data):
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "wb") as file:
        file.write(data)


def snapshot(manager, run_id, run_attempt, workflow_sha):
    def repository_index(source):
        name = str(source['repo'])
        mirror = manager.QUELLEN_DIR / (name + '.git')

        def git(*args):
            return subprocess.run(['git', '-C', str(mirror), *args], check=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=1800).stdout

        refs = git('for-each-ref', '--format=%(refname:strip=2)%00%(objectname)', 'refs/heads').splitlines()
        selected = []
        for line in refs:
            branch_bytes, commit = line.split(b'\0', 1)
            branch = os.fsdecode(branch_bytes)
            if source['branches'] == 'alle' or branch in source['branches']:
                selected.append((branch, commit.decode('ascii')))

        def branch_index(item):
            branch, commit = item
            paths = []
            for entry in git('ls-tree', '-r', '-z', '--full-tree', commit).split(b'\0'):
                if entry:
                    meta, path = entry.split(b'\t', 1)
                    text = os.fsdecode(path)
                    if meta.split(b' ')[1] == b'blob' and Path(text).suffix.lower() in manager.QUELLSPRACHEN:
                        paths.append(text)
            return branch, {'commit': commit, 'paths': paths}

        with ThreadPoolExecutor(max_workers=2) as pool:
            branches = dict(pool.map(branch_index, selected))
        if not branches or (source['branches'] != 'alle' and set(branches) != set(source['branches'])):
            raise ValueError('incomplete source branches')
        return name, branches

    with ThreadPoolExecutor(max_workers=3) as pool:
        repositories = dict(pool.map(repository_index, manager.QUELLEN))
    return {'version': 1, 'run_id': run_id, 'run_attempt': run_attempt,
            'workflow_sha': workflow_sha, 'repositories': repositories}


def prepare_git_sources(manager, directory, state, priority, count, run_id, run_attempt, workflow_sha):
    """Index pinned Git trees and materialize only selected source blobs."""
    from concurrent.futures import ThreadPoolExecutor
    import hashlib
    import io
    import re
    import subprocess

    def git(mirror, *args, data=None):
        return subprocess.run(["git", "-C", str(mirror), *args], input=data,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              check=True, timeout=1800).stdout

    manager.QUELLEN_DIR.mkdir(parents=True, exist_ok=True)

    def update(source):
        repo = str(source["repo"])
        mirror = manager.QUELLEN_DIR / (repo + ".git")
        if mirror.exists():
            result = manager._git("remote", "update", "--prune", verzeichnis=mirror)
        else:
            url = f"https://github.com/{manager.GITHUB_BENUTZER}/{repo}.git"
            result = manager._git("clone", "--mirror", "--filter=blob:none", url, str(mirror))
        if result.returncode != 0:
            raise RuntimeError(f"{repo}: Quellspiegel nicht verfuegbar")

    with ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(update, manager.QUELLEN))

    index = snapshot(manager, run_id, run_attempt, workflow_sha)
    sources = []

    def list_branch(item):
        repo, branch, commit = item
        mirror = manager.QUELLEN_DIR / (repo + ".git")
        records = []
        for item in git(mirror, "ls-tree", "-r", "-z", "--full-tree", commit).split(b"\0"):
            if not item:
                continue
            metadata, raw_path = item.split(b"\t", 1)
            mode, kind, oid = metadata.split(b" ", 2)
            if kind != b"blob" or mode not in (b"100644", b"100755"):
                continue
            path = os.fsdecode(raw_path).replace("\\\\", "/")
            language = manager.QUELLSPRACHEN.get(Path(path).suffix.lower())
            if language is None or any(pattern in "/" + path for pattern in manager.AUSSCHLUSS):
                continue
            if not re.fullmatch(r"[0-9a-f]{40}", oid.decode("ascii")):
                raise ValueError("invalid Git blob identity")
            records.append((repo, branch, commit, path, language, oid.decode("ascii")))
        return records

    branches = [(repo, branch, data["commit"]) for repo, details in index["repositories"].items()
                for branch, data in details.items()]
    with ThreadPoolExecutor(max_workers=6) as pool:
        for records in pool.map(list_branch, branches):
            sources.extend(records)

    grouped = {}
    for repo, branch, commit, path, language, oid in sources:
        origin = f"{repo}@{branch}:{path}"
        item = grouped.get(oid)
        if item is None:
            item = {"blob": oid, "repo": repo, "commit": commit, "path": path,
                    "sprache": language, "herkunft": [], "prioritaet": manager._prioritaet(path, language)}
            grouped[oid] = item
        item["herkunft"].append(origin)

    rank = {"high": 0, "medium": 1, "low": 2}
    candidates = sorted((item for item in grouped.values()
                         if priority == "alle" or item["prioritaet"] == priority),
                        key=lambda item: (rank[item["prioritaet"]], Path(item["path"]).name))
    cursor = state.get("auswahl_blob_cursor", {}).get(priority)
    if cursor:
        pos = next((i for i, item in enumerate(candidates) if item["blob"] == cursor), None)
        if pos is not None:
            candidates = candidates[pos + 1:] + candidates[:pos + 1]
    selected = candidates[:count]
    by_repo = {}
    for item in selected:
        by_repo.setdefault(item["repo"], []).append(item)

    def read_blobs(pair):
        repo, items = pair
        mirror = manager.QUELLEN_DIR / (repo + ".git")
        requested = b"".join((item["blob"] + "\n").encode("ascii") for item in items)
        checks = git(mirror, "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)", data=requested).splitlines()
        if len(checks) != len(items):
            raise ValueError("incomplete Git blob metadata")
        eligible = []
        for item, line in zip(items, checks):
            fields = line.split()
            if len(fields) != 3 or fields[0].decode("ascii") != item["blob"] or fields[1] != b"blob":
                raise ValueError("invalid Git blob metadata")
            if int(fields[2]) <= manager.MAX_BYTES:
                eligible.append((item, int(fields[2])))
        if not eligible:
            return []
        wanted = b"".join((item["blob"] + "\n").encode("ascii") for item, _ in eligible)
        output = io.BytesIO(git(mirror, "cat-file", "--batch", data=wanted))
        result = []
        for item, size in eligible:
            header = output.readline().rstrip(b"\n").split()
            if len(header) != 3 or header[0].decode("ascii") != item["blob"] or header[1] != b"blob" or int(header[2]) != size:
                raise ValueError("invalid Git blob response")
            raw = output.read(size)
            if len(raw) != size or output.read(1) != b"\n":
                raise ValueError("incomplete Git blob response")
            result.append((item, raw))
        return result

    loaded = {}
    with ThreadPoolExecutor(max_workers=3) as pool:
        for result in pool.map(read_blobs, by_repo.items()):
            for item, raw in result:
                loaded[item["blob"]] = raw

    source_dir = Path(directory) / "sources"
    source_dir.mkdir(mode=0o700, exist_ok=True)
    inventory = []
    for item in selected:
        raw = loaded.get(item["blob"])
        if raw is None or not raw.strip() or manager.enthaelt_zugangsdaten(raw):
            continue
        digest = hashlib.sha256(raw).hexdigest()
        target = source_dir / digest
        if not target.exists():
            write_private(target, raw)
        source_path = Path(item["path"])
        inventory.append({"hash": digest[:16], "name": source_path.name, "stamm": source_path.stem,
                          "sprache": item["sprache"], "bytes": len(raw), "pfad": str(target),
                          "herkunft": item["herkunft"], "prioritaet": item["prioritaet"],
                          "css_only": False, "source_blob": item["blob"], "source_repo": item["repo"],
                          "source_commit": item["commit"], "source_path": item["path"],
                          "source_sha256": digest})
    return index, inventory, (selected[-1]["blob"] if selected else None)

