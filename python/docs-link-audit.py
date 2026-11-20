#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "3fdb30b88a10ffe6d1b6d5bd8d05890ff574b194cacaa39d011c980f48d3987c", "source_sha256": "9846e805dd3219c9d0bd40ccd4a368fb397647c0f7db6d88a1eab2f1d73061f3", "target_language": "python"}
# docs-link-audit.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-link-audit.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union

ROOT = Path.cwd()
DOCS_DIR = ROOT / "docs"
DOCS_JSON_PATH = DOCS_DIR / "docs.json"
MINTLIFY_BROKEN_LINKS_ARGS = ["dlx", "mint", "broken-links", "--check-anchors"]
NODE_25_UNSUPPORTED_BY_MINTLIFY = 25

if not DOCS_DIR.exists() or not DOCS_DIR.is_dir():
    print("docs:check-links: missing docs directory; run from repo root.")
    sys.exit(1)

if not DOCS_JSON_PATH.exists():
    print("docs:check-links: missing docs/docs.json.")
    sys.exit(1)


def walk(dir_path: Path) -> List[Path]:
    """Walk through directory and return all files."""
    out = []
    for entry in dir_path.iterdir():
        if entry.name.startswith("."):
            continue
        if entry.is_dir():
            out.extend(walk(entry))
        elif entry.is_file():
            out.append(entry)
    return out


def normalize_slashes(p: str) -> str:
    """Normalize path slashes to forward slashes."""
    return p.replace("\\", "/")


def normalize_route(p: str) -> str:
    """Normalize a route path."""
    without_fragment = p.split("#")[0]
    without_query = without_fragment.split("?")[0]
    stripped = re.sub(r"^/+|/+$", "", without_query)
    return f"/{stripped}" if stripped else "/"


def strip_inline_code(text: str) -> str:
    """Remove inline code from text."""
    return re.sub(r"`[^`]+`", "", text)


# Read docs config
with open(DOCS_JSON_PATH, "r", encoding="utf-8") as f:
    docs_config = json.load(f)

redirects = {}
for item in docs_config.get("redirects", []):
    source = normalize_route(item.get("source", ""))
    destination = normalize_route(item.get("destination", ""))
    redirects[source] = destination

all_files = walk(DOCS_DIR)
rel_all_files = set(normalize_slashes(str(f.relative_to(DOCS_DIR))) for f in all_files)


def is_localize_doc_path(p: str) -> bool:
    """Check if path is a localized documentation path."""
    return bool(re.match(r"^/?[a-z]{2}(?:-[A-Za-z]{2,8})+/", p))


def is_generated_translated_doc(rel_path: str) -> bool:
    """Check if document is generated translated content."""
    return is_localize_doc_path(rel_path)


markdown_files = [
    f for f in all_files 
    if re.search(r"\.(md|mdx)$", str(f), re.IGNORECASE) and 
       not is_generated_translated_doc(normalize_slashes(str(f.relative_to(DOCS_DIR))))
]

routes: Set[str] = set()

for abs_file in markdown_files:
    rel_path = normalize_slashes(str(abs_file.relative_to(DOCS_DIR)))
    with open(abs_file, "r", encoding="utf-8") as f:
        text = f.read()
    
    slug = re.sub(r"\.(md|mdx)$", "", rel_path, flags=re.IGNORECASE)
    route = normalize_route(slug)
    routes.add(route)
    
    if slug.endswith("/index"):
        routes.add(normalize_route(slug[:-len("/index")]))
    
    if not text.startswith("---"):
        continue
    
    end = text.find("\n---", 3)
    if end == -1:
        continue
    
    front_matter = text[3:end]
    match = re.search(r"^permalink:\s*(.+)\s*$", front_matter, re.MULTILINE)
    if not match:
        continue
    
    permalink = match.group(1).strip().strip("'\"")
    routes.add(normalize_route(permalink))


def resolve_route(
    route: str, 
    redirects_map: Optional[Dict[str, str]] = None, 
    published_routes: Optional[Set[str]] = None
) -> Dict[str, Union[bool, str]]:
    """Resolve a route through redirects to find if it's valid."""
    redirect_map = redirects_map or redirects
    published_routes_set = published_routes or routes
    
    current = normalize_route(route)
    if current == "/":
        return {"ok": True, "terminal": "/"}
    
    seen = {current}
    while current in redirect_map:
        current = normalize_route(redirect_map[current])
        if current in seen:
            return {"ok": False, "terminal": current, "loop": True}
        seen.add(current)
    
    return {"ok": current in published_routes_set, "terminal": current}


def collect_nav_page_entries(node: Any) -> List[str]:
    """Collect navigation page entries recursively."""
    entries = []
    if isinstance(node, list):
        for item in node:
            entries.extend(collect_nav_page_entries(item))
        return entries
    
    if not isinstance(node, dict):
        return entries
    
    if "pages" in node and isinstance(node["pages"], list):
        for page in node["pages"]:
            if isinstance(page, str):
                entries.append(page)
            else:
                entries.extend(collect_nav_page_entries(page))
    
    for key, value in node.items():
        if key != "pages":
            entries.extend(collect_nav_page_entries(value))
    
    return entries


def sanitize_docs_config_for_english_only(value: Any) -> Any:
    """Sanitize docs config to include only English content."""
    if isinstance(value, list):
        result = [sanitize_docs_config_for_english_only(item) for item in value]
        return [item for item in result if item is not None]
    
    if not isinstance(value, dict):
        if isinstance(value, str) and is_localize_doc_path(value):
            return None
        return value
    
    if value.get("language", "en") != "en":
        return None
    
    sanitized = {}
    for key, child in value.items():
        next_val = sanitize_docs_config_for_english_only(child)
        if next_val is None:
            continue
        if isinstance(next_val, list) and len(next_val) == 0:
            continue
        if isinstance(next_val, dict) and len(next_val) == 0:
            continue
        sanitized[key] = next_val
    
    if "pages" in value and not isinstance(sanitized.get("pages"), list):
        return None
    if "groups" in value and not isinstance(sanitized.get("groups"), list):
        return None
    if "tabs" in value and not isinstance(sanitized.get("tabs"), list):
        return None
    if "source" in value and isinstance(value["source"], str) and not isinstance(sanitized.get("source"), str):
        return None
    if "destination" in value and isinstance(value["destination"], str) and not isinstance(sanitized.get("destination"), str):
        return None
    
    return sanitized if sanitized else None


def prepare_anchor_audit_docs_dir(source_dir: Path = DOCS_DIR) -> str:
    """Prepare temporary directory for anchor audit."""
    temp_dir = tempfile.mkdtemp(prefix="openclaw-docs-anchor-audit-")
    temp_path = Path(temp_dir)
    
    # Copy source directory
    shutil.copytree(source_dir, temp_path, dirs_exist_ok=True)
    
    # Remove localized directories
    for entry in temp_path.iterdir():
        if entry.is_dir() and is_generated_translated_doc(f"{entry.name}/"):
            shutil.rmtree(entry, ignore_errors=True)
    
    # Sanitize docs.json
    docs_json_path = temp_path / "docs.json"
    with open(docs_json_path, "r", encoding="utf-8") as f:
        docs_config_content = json.load(f)
    
    sanitized = sanitize_docs_config_for_english_only(docs_config_content)
    with open(docs_json_path, "w", encoding="utf-8") as f:
        json.dump(sanitized, f, indent=2)
        f.write("\n")
    
    return temp_dir


def parse_node_major(version: str) -> int:
    """Parse major version number from Node version string."""
    parts = version.split(".")
    if parts and parts[0].isdigit():
        return int(parts[0])
    return 0


def resolve_mintlify_anchor_audit_invocation(
    cwd: str, 
    node_version: Optional[str] = None, 
    spawn_sync_impl=subprocess.run
) -> Dict[str, Union[str, List[str]]]:
    """Resolve the correct mintlify invocation command."""
    node_version = node_version or sys.version
    if parse_node_major(node_version) < NODE_25_UNSUPPORTED_BY_MINTLIFY:
        return {"command": "pnpm", "args": MINTLIFY_BROKEN_LINKS_ARGS}
    
    node22_probe = "process.exit(Number(process.versions.node.split('.')[0]) === 22 ? 0 : 1)"
    candidates = [
        {
            "command": "fnm",
            "probe_args": ["exec", "--using=22", "node", "-e", node22_probe],
            "args": ["exec", "--using=22", "pnpm"] + MINTLIFY_BROKEN_LINKS_ARGS,
        },
        {
            "command": "mise",
            "probe_args": ["exec", "node@22", "--", "node", "-e", node22_probe],
            "args": ["exec", "node@22", "--", "pnpm"] + MINTLIFY_BROKEN_LINKS_ARGS,
        },
    ]
    
    for candidate in candidates:
        try:
            probe_result = spawn_sync_impl(
                [candidate["command"]] + candidate["probe_args"],
                cwd=cwd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            if probe_result.returncode == 0:
                return {"command": candidate["command"], "args": candidate["args"]}
        except FileNotFoundError:
            continue
    
    return {"command": "pnpm", "args": MINTLIFY_BROKEN_LINKS_ARGS}


def audit_docs_links() -> Dict[str, Union[int, List[Dict[str, Union[str, int]]]]]:
    """Audit documentation links for broken references."""
    broken = []
    checked = 0
    markdown_link_regex = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
    
    for abs_file in markdown_files:
        rel_path = normalize_slashes(str(abs_file.relative_to(DOCS_DIR)))
        base_dir = normalize_slashes(str(abs_file.parent.relative_to(DOCS_DIR)))
        
        with open(abs_file, "r", encoding="utf-8") as f:
            raw_text = f.read()
        
        lines = raw_text.split("\n")
        in_code_fence = False
        
        for line_num, line in enumerate(lines):
            line_stripped = line.strip()
            
            if line_stripped.startswith("```"):
                in_code_fence = not in_code_fence
                continue
            
            if in_code_fence:
                continue
            
            line_processed = strip_inline_code(line)
            
            for match in markdown_link_regex.finditer(line_processed):
                raw = (match.group(1) or "").strip()
                if not raw:
                    continue
                
                if re.match(r"^(https?:|mailto:|tel:|data:|#)", raw, re.IGNORECASE):
                    continue
                
                path_part = raw.split("#")[0]
                clean = path_part.split("?")[0]
                if not clean:
                    continue
                
                checked += 1
                
                if clean.startswith("/"):
                    route = normalize_route(clean)
                    resolved_route = resolve_route(route)
                    if not resolved_route["ok"]:
                        static_rel = route[1:] if route.startswith("/") else route
                        if static_rel not in rel_all_files:
                            broken.append({
                                "file": rel_path,
                                "line": line_num + 1,
                                "link": raw,
                                "reason": f"route/file not found (terminal: {resolved_route['terminal']})"
                            })
                    continue
                
                if not clean.startswith(".") and "/" not in clean:
                    continue
                
                normalized_rel = normalize_slashes(os.path.normpath(os.path.join(base_dir, clean)))
                
                if re.search(r"\.[a-zA-Z0-9]+$", normalized_rel):
                    if normalized_rel not in rel_all_files:
                        broken.append({
                            "file": rel_path,
                            "line": line_num + 1,
                            "link": raw,
                            "reason": "relative file not found"
                        })
                    continue
                
                candidates = [
                    normalized_rel,
                    f"{normalized_rel}.md",
                    f"{normalized_rel}.mdx",
                    f"{normalized_rel}/index.md",
                    f"{normalized_rel}/index.mdx",
                ]
                
                if not any(candidate in rel_all_files for candidate in candidates):
                    broken.append({
                        "file": rel_path,
                        "line": line_num + 1,
                        "link": raw,
                        "reason": "relative doc target not found"
                    })
    
    # Check navigation pages
    for page in collect_nav_page_entries(docs_config.get("navigation", [])):
        if is_generated_translated_doc(page):
            continue
        checked += 1
        route = normalize_route(page)
        resolved_route = resolve_route(route)
        if resolved_route["ok"]:
            continue
        
        broken.append({
            "file": "docs.json",
            "line": 0,
            "link": page,
            "reason": f"navigation page not published (terminal: {resolved_route['terminal']})"
        })
    
    return {"checked": checked, "broken": broken}


def run_docs_link_audit_cli(
    args: Optional[List[str]] = None,
    node_version: Optional[str] = None,
    spawn_sync_impl=subprocess.run,
    prepare_anchor_audit_docs_dir_impl=prepare_anchor_audit_docs_dir,
    cleanup_anchor_audit_docs_dir_impl=None
) -> int:
    """Run the documentation link audit CLI."""
    if cleanup_anchor_audit_docs_dir_impl is None:
        cleanup_anchor_audit_docs_dir_impl = lambda dir: shutil.rmtree(dir, ignore_errors=True)
    
    args = args or sys.argv[1:]
    if "--anchors" in args:
        anchor_docs_dir = prepare_anchor_audit_docs_dir_impl(DOCS_DIR)
        
        try:
            invocation = resolve_mintlify_anchor_audit_invocation(
                anchor_docs_dir,
                node_version,
                spawn_sync_impl
            )
            
            result = spawn_sync_impl(
                [invocation["command"]] + invocation["args"],
                cwd=anchor_docs_dir,
                stdout=sys.stdout,
                stderr=sys.stderr
            )
            
            return result.returncode if result.returncode is not None else 1
        finally:
            cleanup_anchor_audit_docs_dir_impl(anchor_docs_dir)
    
    result = audit_docs_links()
    checked = result["checked"]
    broken = result["broken"]
    
    print(f"checked_internal_links={checked}")
    print(f"broken_links={len(broken)}")
    
    for item in broken:
        print(f"{item['file']}:{item['line']} :: {item['link']} :: {item['reason']}")
    
    return 1 if len(broken) > 0 else 0


if __name__ == "__main__":
    sys.exit(run_docs_link_audit_cli())
