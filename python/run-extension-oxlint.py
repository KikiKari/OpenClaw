#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "9f0df401f5b494bdb6ee41594769cdad9b4b372ba41d795acaf630742fecbba6", "source_sha256": "12dffdae6f3576ff268694787ca9415cbb1e307cb0b7cb39a0784412c35e1318", "target_language": "python"}
# run-extension-oxlint.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/run-extension-oxlint.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Import functions from local-heavy-check-runtime.py (assuming it's available)
from local_heavy_check_runtime import acquire_local_heavy_check_lock_sync, apply_local_oxlint_policy

def run_extension_oxlint(params):
    repo_root = Path.cwd()
    oxlint_path = repo_root / "node_modules" / ".bin" / "oxlint"
    release_lock = acquire_local_heavy_check_lock_sync({
        "cwd": str(repo_root),
        "env": dict(os.environ),
        "tool_name": params["toolName"],
        "lock_name": params["lockName"],
    })
    temp_dir = Path(tempfile.mkdtemp(prefix=params["tempDirPrefix"]))
    temp_config_path = temp_dir / "oxlint.json"
    exit_code = 0

    try:
        prepare_extension_package_boundary_artifacts(str(repo_root))

        extension_files = []
        for root in params["roots"]:
            resolved_root = (repo_root / root).resolve()
            extension_files.extend(collect_typescript_files(str(resolved_root)))

        if not extension_files:
            print(params["emptyMessage"], file=sys.stderr)
            sys.exit(1)

        write_temp_oxlint_config(str(repo_root), str(temp_config_path))

        base_args = ["-c", str(temp_config_path)] + sys.argv[1:] + extension_files
        final_args, env = apply_local_oxlint_policy(base_args, dict(os.environ))
        
        # Adjust for Windows if needed
        shell = sys.platform == "win32"
        result = subprocess.run([str(oxlint_path)] + final_args, 
                                 stdout=subprocess.PIPE, 
                                 stderr=subprocess.PIPE,
                                 env=env,
                                 shell=shell)

        if result.returncode is not None:
            exit_code = result.returncode
        else:
            exit_code = 1

    except Exception as e:
        print(f"Error running oxlint: {e}", file=sys.stderr)
        exit_code = 1
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)
        release_lock()

    sys.exit(exit_code)


def prepare_extension_package_boundary_artifacts(repo_root):
    release_lock = acquire_local_heavy_check_lock_sync({
        "cwd": repo_root,
        "env": dict(os.environ),
        "tool_name": "extension-package-boundary-artifacts",
        "lock_name": "extension-package-boundary-artifacts",
    })
    exit_code = 0

    try:
        script_path = Path(repo_root) / "scripts" / "prepare-extension-package-boundary-artifacts.mjs"
        result = subprocess.run(
            [sys.executable, str(script_path)],
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=dict(os.environ)
        )

        if result.returncode is not None:
            exit_code = result.returncode
        else:
            exit_code = 1

    except Exception as e:
        print(f"Error preparing artifacts: {e}", file=sys.stderr)
        exit_code = 1
    finally:
        release_lock()

    if exit_code != 0:
        sys.exit(exit_code)


def write_temp_oxlint_config(repo_root, config_path):
    oxlintrc_path = Path(repo_root) / ".oxlintrc.json"
    with open(oxlintrc_path, 'r', encoding='utf-8') as f:
        config = json.load(f)

    config.pop('$schema', None)

    if isinstance(config.get('ignorePatterns'), list):
        extensions_ignore_pattern = next((
            pattern for pattern in config['ignorePatterns']
            if is_top_level_extensions_ignore_pattern(pattern)
        ), None)
        
        if extensions_ignore_pattern:
            raise ValueError(
                f'Refusing to run extension oxlint with .oxlintrc.json ignore pattern '
                f'{json.dumps(extensions_ignore_pattern)}. Remove the top-level extensions ignore '
                f'so root and focused lint agree.'
            )

    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2)
        f.write('\n')


def is_top_level_extensions_ignore_pattern(pattern):
    normalized = pattern.strip().replace('\\', '/').removeprefix('./')
    return normalized in ('extensions', 'extensions/', 'extensions/**')


def collect_typescript_files(directory_path):
    files = []
    try:
        entries = sorted(os.scandir(directory_path), key=lambda e: e.name)
        for entry in entries:
            entry_path = os.path.join(directory_path, entry.name)
            if entry.is_dir():
                files.extend(collect_typescript_files(entry_path))
            elif entry.is_file() and (entry.name.endswith('.ts') or entry.name.endswith('.tsx')):
                rel_path = os.path.relpath(entry_path, os.getcwd())
                files.append(rel_path.replace(os.sep, '/'))
    except Exception as e:
        print(f"Error reading directory {directory_path}: {e}", file=sys.stderr)
    
    return files


if __name__ == "__main__":
    # Example usage - you would need to provide actual parameters here
    example_params = {
        "toolName": "oxlint",
        "lockName": "oxlint-lock",
        "tempDirPrefix": "oxlint-temp-",
        "roots": ["src"],
        "emptyMessage": "No TypeScript files found to lint."
    }
    run_extension_oxlint(example_params)
