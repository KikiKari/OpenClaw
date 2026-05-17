#!/usr/bin/env python3
"""
Job Dispatcher - Verteilt Jobs auf passende Nodes
"""

import subprocess
import sys
from pathlib import Path
from typing import Optional

# Node-Konfiguration
NODES = {
    "node1": {"always_available": True, "capacity": "medium", "priority": 2},
    "node2": {"always_available": True, "capacity": "medium", "priority": 3},
    "node3": {"always_available": False, "capacity": "medium", "priority": 4},
    "node5": {"always_available": False, "capacity": "low", "priority": 5, "device": "Redmi Note 11S"},
    "node7": {"always_available": True, "capacity": "high", "priority": 1},
}

class JobDispatcher:
    """Dispatches jobs to appropriate nodes based on weight"""
    
    def get_job_weight(self, script_path: Path, target_langs_count: int = 1) -> str:
        """Bewertet Job-Gewicht"""
        if not script_path.exists():
            return "medium"
        
        script_size = script_path.stat().st_size
        total_work = script_size * target_langs_count
        
        if total_work > 50000:  # > 50KB
            return "heavy"
        elif total_work > 10000:  # > 10KB
            return "medium"
        else:
            return "light"
    
    def select_node(self, job_weight: str) -> str:
        """Wählt besten Node basierend auf Job-Gewicht"""
        
        if job_weight == "heavy":
            # Schwere Jobs → Node 7 (Docker), dann Node 2, dann Node 1
            preferred = ["node7", "node2", "node1"]
        elif job_weight == "medium":
            # Mittlere Jobs → Stable Nodes
            preferred = ["node2", "node1", "node7"]
        else:  # light
            # Leichte Jobs → Mobile/verfügbare Nodes
            preferred = ["node5", "node1", "node2"]
        
        # Prüfe Verfügbarkeit
        for node_id in preferred:
            if self.check_node_available(node_id):
                return node_id
        
        # Fallback
        return "node1"
    
    def check_node_available(self, node_id: str) -> bool:
        """Prüft ob Node erreichbar ist"""
        if node_id not in NODES:
            return False
        
        node = NODES[node_id]
        
        # Nicht immer-verfügbare Nodes nur wenn explizit requested
        if not node.get("always_available", False):
            # Für light-jobs prüfen wir ob online
            if node_id == "node5":  # Redmi
                return self._check_mobile_online()
            return False
        
        # Für immer-verfügbare Nodes: prüfe ob wirklich online
        try:
            result = subprocess.run(
                ["openclaw", "nodes", "status", node_id],
                capture_output=True,
                timeout=3
            )
            return result.returncode == 0
        except:
            return node.get("always_available", False)
    
    def _check_mobile_online(self) -> bool:
        """Prüft ob Redmi (Node 5) Internet hat"""
        try:
            result = subprocess.run(
                ["openclaw", "nodes", "status", "node5"],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0 and "online" in result.stdout.lower()
        except:
            return False
    
    def dispatch(self, job_script: Path, target_langs: list = None) -> dict:
        """Dispatched Job und gibt Info zurück"""
        if target_langs is None:
            target_langs = ["perl5"]
        
        weight = self.get_job_weight(job_script, len(target_langs))
        selected_node = self.select_node(weight)
        
        return {
            "job": str(job_script),
            "weight": weight,
            "selected_node": selected_node,
            "target_langs": target_langs,
            "status": "dispatched"
        }

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
        print(f"\n🚀 Executing on {selected_node}...")
        # TODO: Implement remote execution
        print("(Remote execution not yet implemented)")
    else:
        print(f"\n💡 To execute: {sys.argv[0]} --job {args.job} --execute")

if __name__ == "__main__":
    main()