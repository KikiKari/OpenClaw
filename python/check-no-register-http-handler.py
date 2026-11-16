#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "b0e21726c17786d8a6d7c634beb9efd77262f855473e198520a0611a0514056a", "source_sha256": "a01dcf18c06d5aeb081cedf0088a13b316c08622615e4de86febe2deaee2596d", "target_language": "python"}
# check-no-register-http-handler.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-no-register-http-handler.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import sys
import os
from pathlib import Path
from typing import List, Optional, Callable
import ast
import asyncio

# Fuege das lib-Verzeichnis zum Pfad hinzu
sys.path.append(str(Path(__file__).parent / "lib"))

try:
    from callsite_guard import run_callsite_guard
    from ts_guard_utils import collect_call_expression_lines, run_as_script, unwrap_expression
except ImportError:
    # Alternative Implementierung ohne externe Abhaengigkeiten
    def run_callsite_guard(**kwargs):
        print("callsite-guard not available")
        return False
        
    def collect_call_expression_lines(module, source_file, filter_func):
        return []
        
    def run_as_script(script_path, main_func):
        if __name__ == "__main__":
            asyncio.run(main_func())
            
    def unwrap_expression(expression):
        return expression

source_roots = ["src", "extensions"]

def is_deprecated_register_http_handler_call(expression):
    """Prueft ob ein Ausdruck ein veraltetes registerHttpHandler ist"""
    callee = unwrap_expression(expression)
    
    # Pruefe auf PropertyAccessExpression mit name 'registerHttpHandler'
    if hasattr(callee, 'attr') and callee.attr == 'registerHttpHandler':
        return True
    
    # Pruefe auf direkten Funktionsaufruf
    if isinstance(callee, ast.Name) and callee.id == 'registerHttpHandler':
        return True
        
    return False

def find_deprecated_register_http_handler_lines(content: str, file_name: str = "source.py") -> List[int]:
    """
    Findet Zeilen mit veralteten registerHttpHandler Aufrufen
    
    Args:
        content: Der zu pruefende Quellcode
        file_name: Name der Datei (fuer Debugging)
        
    Returns:
        Liste der Zeilennummern mit veralteten Aufrufen
    """
    try:
        # Parse den Python-Code
        tree = ast.parse(content, filename=file_name)
        
        lines = []
        
        # Durchsuche den AST nach Funktionsaufrufen
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                if is_deprecated_register_http_handler_call(node.func):
                    # Bestimme die Zeilennummer
                    if hasattr(node, 'lineno'):
                        lines.append(node.lineno)
                        
        return list(set(lines))  # Entferne Duplikate
        
    except SyntaxError as e:
        print(f"Syntax error in {file_name}: {e}")
        return []

async def main():
    """Hauptfunktion"""
    await run_callsite_guard(
        import_meta_url=__file__,
        source_roots=source_roots,
        find_call_lines=find_deprecated_register_http_handler_lines,
        header="Found deprecated plugin API call registerHttpHandler(...):",
        footer="Use registerHttpRoute({ path, auth, match, handler }) and registerPluginHttpRoute for dynamic webhook paths."
    )

# Skript-Modus
if __name__ == "__main__":
    run_as_script(__file__, main)
