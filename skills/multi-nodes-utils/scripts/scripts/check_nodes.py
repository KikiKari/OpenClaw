#!/usr/bin/env python3
"""
Node-Status Checker - Prüft Verfügbarkeit aller Nodes
"""

import subprocess
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List

# Node-Konfiguration (sollte aus config file geladen werden)
NODES = {
    "node1": {
        "always_available": True,
        "capacity": "medium",
        "priority": 2,
        "description": "Gateway-Master"
    },
    "node2": {
        "always_available": True,
        "capacity": "medium",
        "priority": 3,
        "description": "Stable Worker"
    },
    "node3": {
        "always_available": False,
        "capacity": "medium",
        "priority": 4,
        "description": "Bald verfügbar (nach Reorganisation)"
    },
    "node5": {
        "always_available": False,
        "capacity": "low",
        "priority": 5,
        "device": "Redmi Note 11S",
        "description": "Mobile (bei Internet verfügbar)"
    },
    "node7": {
        "always_available": True,
        "capacity": "high",
        "priority": 1,
        "description": "Docker Hauptarbeitspferd (bald verfügbar)"
    },
}

def check_node_status(node_id: str) -> Dict:
    """Prüft Status eines einzelnen Nodes"""
    try:
        result = subprocess.run(
            ["openclaw", "nodes", "status", node_id],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        is_online = result.returncode == 0 and (
            "online" in result.stdout.lower() or 
            "active" in result.stdout.lower()
        )
        
        return {
            "id": node_id,
            "online": is_online,
            "available": NODES[node_id].get("always_available", False),
            "response": result.stdout.strip()[:100] if result.stdout else "No response"
        }
    except subprocess.TimeoutExpired:
        return {
            "id": node_id,
            "online": False,
            "available": NODES[node_id].get("always_available", False),
            "response": "Timeout"
        }
    except Exception as e:
        return {
            "id": node_id,
            "online": False,
            "available": NODES[node_id].get("always_available", False),
            "response": f"Error: {e}"
        }

def print_table(nodes_status: List[Dict]):
    """Gibt Node-Status als Tabelle aus"""
    print("\n" + "=" * 90)
    print(f"{'Node':<8} {'Status':<12} {'Verfügbar':<12} {'Kapazität':<10} {'Priorität':<10} {'Gerät/Beschreibung'}")
    print("=" * 90)
    
    for status in nodes_status:
        node_id = status["id"]
        config = NODES[node_id]
        
        status_icon = "🟢 Online" if status["online"] else "🔴 Offline"
        avail_icon = "✅ Immer" if status["available"] else "📱 Bedingt"
        capacity = config.get("capacity", "unknown")
        priority = config.get("priority", "-")
        device = config.get("device", config.get("description", ""))
        
        print(f"{node_id:<8} {status_icon:<12} {avail_icon:<12} {capacity:<10} {priority:<10} {device}")
    
    print("=" * 90)
    print(f"\nGeprüft am: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

def print_json(nodes_status: List[Dict]):
    """Gibt Node-Status als JSON aus"""
    output = {
        "timestamp": datetime.now().isoformat(),
        "nodes": {}
    }
    
    for status in nodes_status:
        node_id = status["id"]
        output["nodes"][node_id] = {
            "status": status,
            "config": NODES[node_id]
        }
    
    print(json.dumps(output, indent=2))

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Check all node statuses")
    parser.add_argument("--format", "-f", choices=["table", "json"], default="table", help="Output format")
    parser.add_argument("--save", "-s", help="Save to file")
    
    args = parser.parse_args()
    
    print("🔍 Prüfe Node-Status...")
    
    # Prüfe alle Nodes
    nodes_status = []
    for node_id in sorted(NODES.keys()):
        print(f"  → {node_id}...", end=" ", flush=True)
        status = check_node_status(node_id)
        nodes_status.append(status)
        print("✓" if status["online"] else "✗")
    
    # Ausgabe
    if args.format == "table":
        print_table(nodes_status)
    else:
        print_json(nodes_status)
    
    # Speichern
    if args.save:
        output = {
            "timestamp": datetime.now().isoformat(),
            "nodes": {s["id"]: s for s in nodes_status}
        }
        with open(args.save, 'w') as f:
            json.dump(output, f, indent=2)
        print(f"\n💾 Gespeichert: {args.save}")
    
    # Zusammenfassung
    online_count = sum(1 for s in nodes_status if s["online"])
    print(f"\n📊 Zusammenfassung: {online_count}/{len(nodes_status)} Nodes online")

if __name__ == "__main__":
    main()