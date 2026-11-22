#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "752766471e1dbf11ba3de9357114c822bd8bbf2b8401e444bae60b526d86a871", "source_sha256": "5425378c778f4ef6ac0e8404ecffe774c2d3aea6bad539b4fd772554e566f469", "target_language": "python"}
# run-tsgo.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-tsgo.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os
from pathlib import Path

# Importiere die benötigten Funktionen aus dem lokalen Modul
# Hinweis: Da es keine direkte Entsprechung für JS-Imports gibt,
# müssen diese Funktionen in Python implementiert werden
# oder aus einem entsprechenden Python-Modul importiert werden

def acquire_local_heavy_check_lock_sync(config):
    """
    Dummy-Implementierung der Lock-Funktion.
    In einer echten Implementierung würde hier eine Sperrmechanik realisiert.
    """
    def release_lock():
        pass
    return release_lock

def apply_local_tsgo_policy(args, env):
    """
    Dummy-Implementierung der Policy-Anwendung.
    In einer echten Implementierung würden hier Umgebungsvariablen und Argumente angepasst.
    """
    return {"args": args, "env": env}

def read_flag_value(args, name):
    """Liest den Wert eines Flags aus den Argumenten"""
    for index in range(len(args)):
        arg = args[index]
        if arg == name:
            return args[index + 1] if index + 1 < len(args) else None
        if arg.startswith(f"{name}="):
            return arg[len(name) + 1:]
    return None

# Wende die lokale TSGO-Policy an
final_args = sys.argv[1:]
env = os.environ.copy()

# Anwenden der Policy (hier nur dummy)
policy_result = apply_local_tsgo_policy(final_args, env)
final_args = policy_result["args"]
env = policy_result["env"]

# Bestimme den Pfad zu tsgo
tsgo_path = Path("node_modules/.bin/tsgo").resolve()

# Lese den tsBuildInfoFile-Wert
ts_build_info_file = read_flag_value(final_args, "--tsBuildInfoFile")
if ts_build_info_file:
    build_info_path = Path(ts_build_info_file).resolve()
    build_info_path.parent.mkdir(parents=True, exist_ok=True)

# Erwerbe das Lock
release_lock = acquire_local_heavy_check_lock_sync({
    "cwd": os.getcwd(),
    "env": env,
    "tool_name": "tsgo"
})

try:
    # Führe tsgo aus
    result = subprocess.run(
        [str(tsgo_path)] + final_args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        shell=(os.name == 'nt')  # Windows verwendet Shell
    )
    
    # Gebe stdout und stderr aus
    sys.stdout.write(result.stdout.decode())
    sys.stderr.write(result.stderr.decode())
    
    # Setze den Exit-Code
    sys.exit(result.returncode)
    
except Exception as e:
    raise e
finally:
    release_lock()
