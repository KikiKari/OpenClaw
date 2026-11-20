#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "7a3048fa8ae415a554f65ea8ce07890403755a6ad9a75bc4161e198fa7c56819", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "python"}
# docker-e2e-logs.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import subprocess
import tempfile
import os
import sys

def run_logged(label, *args):
    """
    Führt einen Befehl aus und protokolliert die Ausgabe in einer temporären Datei.
    Gibt die Ausgabe auf stdout aus und löscht die temporäre Datei.
    """
    # Erstelle eine temporäre Datei für die Protokollierung
    with tempfile.NamedTemporaryFile(mode='w+', suffix='.log', prefix=f'openclaw-{label}.', delete=False) as log_file:
        log_file_path = log_file.name
    
    try:
        # Führe den Befehl aus und leite stdout und stderr in die Logdatei
        with open(log_file_path, 'w') as log_file:
            result = subprocess.run(args, stdout=log_file, stderr=subprocess.STDOUT)
        
        # Wenn der Befehl fehlgeschlagen ist, zeige den Inhalt der Logdatei an
        if result.returncode != 0:
            with open(log_file_path, 'r') as log_file:
                print(log_file.read(), file=sys.stdout)
            return False
        
        return True
    finally:
        # Lösche die temporäre Datei
        if os.path.exists(log_file_path):
            os.unlink(log_file_path)
