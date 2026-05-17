#!/usr/bin/env python3
"""
Testet Multi-Node Fallback-Logik des db-maintainer
Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal
"""

import subprocess
import sys
from pathlib import Path

WORKSPACE = Path("/home/openclaw/.openclaw/workspace")

def check_node_reachable(node_id):
    """Prüft ob Node erreichbar ist"""
    try:
        # Versuche Node-Status abzufragen
        result = subprocess.run(
            ['openclaw', 'nodes', 'status'],
            capture_output=True, text=True, timeout=10
        )
        return node_id in result.stdout and 'connected' in result.stdout
    except:
        return False

def spawn_on_node(node_id, task):
    """Versucht Task auf Node auszuführen"""
    print(f"Versuche Task auf Node {node_id} zu starten...")
    try:
        # Simuliert: openclaw agent spawn --node {node_id}
        result = subprocess.run(
            ['echo', f'Spawned on {node_id}: {task}'],
            capture_output=True, text=True, timeout=5
        )
        print(f"✅ Erfolgreich delegiert an {node_id}")
        return True
    except Exception as e:
        print(f"❌ Node {node_id} nicht erreichbar: {e}")
        return False

def execute_locally(task):
    """Führt Task lokal aus (Fallback)"""
    print(f"🔄 Fallback: Führe Task lokal aus...")
    try:
        if task == 'db_maintainer':
            result = subprocess.run(
                ['python3', str(WORKSPACE / 'skills' / 'db-maintainer' / 'scripts' / 'db_maintainer.py')],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                print("✅ Lokale Ausführung erfolgreich")
                return True
            else:
                print(f"❌ Fehler: {result.stderr[:200]}")
                return False
    except Exception as e:
        print(f"❌ Lokale Ausführung fehlgeschlagen: {e}")
        return False

def main():
    print("="*60)
    print("MULTI-NODE FALLBACK TEST")
    print("="*60)
    print()
    
    # Konfiguration
    primary_node = 'v2202603104722445775'  # Node 2
    task = 'db_maintainer'
    
    print(f"Primärer Node: {primary_node}")
    print(f"Task: {task}")
    print()
    
    # 1. Prüfe Node-Erreichbarkeit
    print("--- 1. Prüfe Node-Erreichbarkeit ---")
    if check_node_reachable(primary_node):
        print(f"✅ Node {primary_node} ist erreichbar")
        
        # 2. Versuche Delegation
        print("\n--- 2. Versuche Delegation ---")
        if spawn_on_node(primary_node, task):
            print("\n✅ MULTI-NODE: Task erfolgreich delegiert")
            return 0
        else:
            print("\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback...")
    else:
        print(f"❌ Node {primary_node} nicht erreichbar")
        print("🔄 Fallback wird aktiviert...")
    
    # 3. Lokale Ausführung (Fallback)
    print("\n--- 3. Lokale Ausführung (Fallback) ---")
    if execute_locally(task):
        print("\n✅ FALLBACK: Task lokal erfolgreich ausgeführt")
        return 0
    else:
        print("\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich")
        return 1

if __name__ == "__main__":
    sys.exit(main())
