#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d466654aa14884209d1ab5508a1621c04b082eaba58693071367f303ba4dc546", "source_sha256": "5826d57477404d40d10bccd3a144f22f3f46ce4897073fa71d1d3868edfe8719", "target_language": "python"}
# format-generated-module.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/format-generated-module.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import subprocess
import tempfile
import os
import sys
import shutil

def format_generated_module(source, *, repo_root, output_path, error_label):
    """
    Formats a generated module using oxlint's formatter.
    
    Args:
        source: The source code string to format
        repo_root: The repository root directory
        output_path: The intended output path for the formatted file
        error_label: Label used in error messages
        
    Returns:
        The formatted source code as a string
        
    Raises:
        Exception: If formatting fails
    """
    resolved_repo_root = os.path.abspath(repo_root)
    
    # Resolve output path relative to repo root if it's not absolute
    if os.path.isabs(output_path):
        rel_path = os.path.relpath(output_path, resolved_repo_root)
        resolved_output_path = os.path.join(resolved_repo_root, rel_path)
    else:
        resolved_output_path = os.path.join(resolved_repo_root, output_path)
    
    # Determine if we can use the direct formatter or need to go through pnpm
    direct_formatter_path = os.path.join(resolved_repo_root, "node_modules", ".bin", "oxfmt")
    use_direct_formatter = sys.platform != "win32" and os.path.exists(direct_formatter_path)
    
    command = direct_formatter_path if use_direct_formatter else "pnpm"
    
    # Create temporary directory and file
    temp_dir = tempfile.mkdtemp(prefix="openclaw-generated-format-", dir=tempfile.gettempdir())
    temp_output_path = os.path.join(temp_dir, os.path.basename(resolved_output_path))
    
    try:
        # Write source to temp file
        with open(temp_output_path, 'w', encoding='utf-8') as f:
            f.write(source)
        
        # Prepare arguments for formatter
        if use_direct_formatter:
            args = [command, "--write", temp_output_path]
        else:
            args = [command, "exec", "oxfmt", "--write", temp_output_path]
        
        # Run formatter
        try:
            result = subprocess.run(
                args,
                cwd=resolved_repo_root,
                capture_output=True,
                text=True,
                shell=(sys.platform == "win32")  # Windows needs shell for package manager shims
            )
            
            if result.returncode != 0:
                details = (
                    result.stderr.strip() or 
                    result.stdout.strip() or 
                    (result.args if hasattr(result, 'args') else str(result)) or
                    "unknown formatter failure"
                )
                raise Exception(f"failed to format generated {error_label}: {details}")
                
        except FileNotFoundError as e:
            raise Exception(f"failed to format generated {error_label}: command not found: {command}") from e
            
        # Read formatted content
        with open(temp_output_path, 'r', encoding='utf-8') as f:
            return f.read()
            
    finally:
        # Clean up temp directory
        shutil.rmtree(temp_dir, ignore_errors=True)
