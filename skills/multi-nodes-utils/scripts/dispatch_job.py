#!/usr/bin/env python3
"""
Job Dispatcher - Verteilt Jobs auf passende Nodes
"""

import subprocess
import json
import sys
import uuid
from pathlib import Path
from typing import Optional

def _job_weight_bytes(script_path: Path, target_langs_count: int) -> int:
    """Arbeitsvolumen: Dateigröße × Anzahl der Zielsprachen."""
    return script_path.stat().st_size * target_langs_count

# Node-Konfiguration
NODES = {
    "node1": {"always_available": True, "capacity": "medium", "priority": 3, "description": "Gateway"},
    "node2": {"always_available": False, "capacity": "high", "priority": 1, "description": "ARM Server"},
    "node3": {"always_available": False, "capacity": "medium", "priority": 4, "description": "AMD Server"},
    "node4": {"always_available": False, "capacity": "low", "priority": 5, "device": "Redmi Note 11S"},
    "node5": {"always_available": False, "capacity": "high", "priority": 2, "device": "Lenovo"},
    "node6": {"always_available": False, "device": "Lenovo (Docker)"},
}

NODE_NAMES = {
    "node2": {"openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"},
    "node3": {"openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"},
    "node4": {"openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"},
    "node5": {"openclaw-node5", "windows node (lenovo-7)"},
    "node6": {"openclaw-node6"},
}


def fetch_node_status():
    """Return mapped OpenClaw connection states; None indicates lookup failure."""
    try:
        result = subprocess.run(
            ["openclaw", "nodes", "status", "--json"],
            capture_output=True, text=True, timeout=10, check=True,
        )
        payload = json.loads(result.stdout)
        if not isinstance(payload, dict) or not isinstance(payload.get("nodes"), list):
            return None
        states = {node: False for node in NODE_NAMES}
        for item in payload["nodes"]:
            if not isinstance(item, dict):
                continue
            names = {str(item.get(key, "")).lower() for key in ("displayName", "nodeId", "remoteIp")}
            for node, aliases in NODE_NAMES.items():
                if names & aliases and item.get("connected") is True:
                    states[node] = True
        states["node1"] = True  # successful Gateway status request
        return states
    except (OSError, subprocess.SubprocessError, ValueError, TypeError):
        return None

class JobDispatcher:
    """Dispatches jobs to appropriate nodes based on weight"""
    
    def get_job_weight(self, script_path: Path, target_langs_count: int = 1) -> str:
        """Bewertet Job-Gewicht"""
        if not script_path.exists():
            return "medium"
        
        total_work = _job_weight_bytes(script_path, target_langs_count)
        
        if total_work > 50000:  # > 50KB
            return "heavy"
        elif total_work > 10000:  # > 10KB
            return "medium"
        else:
            return "light"
    
    def select_node(self, job_weight: str) -> Optional[str]:
        """Wählt besten Node basierend auf Job-Gewicht"""
        
        if job_weight == "heavy":
            preferred = ["node1", "node2", "node5", "node6"]
        elif job_weight == "medium":
            preferred = ["node1", "node2", "node3", "node6"]
        elif job_weight == "light":
            preferred = ["node2", "node1", "node3", "node4"]
        else:
            raise ValueError(f"Unknown job weight: {job_weight}")

        states = fetch_node_status()
        for node_id in preferred:
            if states and states.get(node_id, False):
                return node_id
        return None  # no verified reachable node

    def check_node_available(self, node_id: str) -> bool:
        """Use the live connection state rather than static availability."""
        states = fetch_node_status()
        return bool(states and states.get(node_id, False))

    def execute_translation(self, job: dict, transport) -> str:
        return execute_translation(job, transport)

    def _check_mobile_online(self) -> bool:
        """Check Node4 (Redmi)."""
        return self.check_node_available("node4")

    def dispatch(self, job_script: Path, target_langs: list = None,
                 source_text: Optional[str] = None,
                 source_language: Optional[str] = None) -> dict:
        """Dispatched Job und gibt Info zurück"""
        if target_langs is None:
            target_langs = ["perl5"]
        
        weight = self.get_job_weight(job_script, len(target_langs))
        selected_node = self.select_node(weight)
        translation_jobs = []
        for language in target_langs:
            job = {
                "job_id": str(uuid.uuid4()),
                "source": str(job_script),
                "target_language": language,
                "selected_node": selected_node,
            }
            if source_text is not None:
                job["source_text"] = source_text
            if source_language is not None:
                job["source_language"] = source_language
            translation_jobs.append(job)
        
        return {
            "job": str(job_script),
            "weight": weight,
            "selected_node": selected_node,
            "target_langs": target_langs,
            "translation_jobs": translation_jobs,
            "status": "selected" if selected_node else "unavailable"
        }

def execute_translation(job: dict, transport) -> str:
    """Execute via a supplied transport and verify its result belongs to the job."""
    if not job.get("selected_node") or transport is None:
        raise RuntimeError("no verified node or authorized translation transport")
    response = transport(job)
    if not isinstance(response, dict):
        raise ValueError("invalid transport response")
    for key in ("job_id", "selected_node", "target_language"):
        if response.get(key) != job.get(key):
            raise ValueError("transport response does not match job")
    code = response.get("code")
    if response.get("status") != "ok" or not isinstance(code, str) or not code.strip():
        raise ValueError("translation did not complete with code")
    return code


def dispatch_abstraction_job(job_script: Path, target_langs: list) -> dict:
    """Erstellt eine Node-Auswahl und je (Skript, Sprache) einen Auftrag."""
    dispatcher = JobDispatcher()
    return dispatcher.dispatch(job_script, target_langs)

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Dispatch job to optimal node")
    parser.add_argument("--job", "-j", required=True, help="Path to job script")
    parser.add_argument("--langs", "-l", default="perl5", help="Comma-separated target languages")
    parser.add_argument("--weight", "-w", choices=["light", "medium", "heavy"], help="Force job weight")
    parser.add_argument("--execute", "-x", action="store_true", help="Actually execute on selected node")
    
    args = parser.parse_args()
    
    job_path = Path(args.job)
    if not job_path.exists():
        print(f"❌ Job not found: {job_path}")
        sys.exit(1)
    
    dispatcher = JobDispatcher()
    target_langs = args.langs.split(",")
    
    # Determine weight
    if args.weight:
        weight = args.weight
    else:
        weight = dispatcher.get_job_weight(job_path, len(target_langs))
    
    # Select node
    selected_node = dispatcher.select_node(weight)
    
    # Output
    print("📦 Job Dispatch Information")
    print("=" * 50)
    print(f"Job: {job_path}")
    print(f"Size: {job_path.stat().st_size} bytes")
    print(f"Target langs: {', '.join(target_langs)}")
    print(f"Job weight: {weight}")
    print(f"Selected node: {selected_node}")
    print("=" * 50)
    
    if args.execute:
        print(f"\nTranslation dispatch on {selected_node} is not implemented.", file=sys.stderr)
        return 1
    else:
        print(f"\n💡 To execute: {sys.argv[0]} --job {args.job} --execute")
    return 0

if __name__ == "__main__":
    sys.exit(main())
