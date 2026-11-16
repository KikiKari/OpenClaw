#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "933d55c884cedf1a8294b07ac064182b4388ce46fd264193ad6f59daafb45f10", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "python"}
# build-all.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
from pathlib import Path

# Importiere resolve_pnpm_runner aus pnpm_runner.py
# Da es keine direkte Entsprechung zu ES Modules gibt, gehen wir davon aus,
# dass pnpm_runner.py im selben Verzeichnis liegt und eine Funktion resolve_pnpm_runner bereitstellt.
from pnpm_runner import resolve_pnpm_runner

node_bin = sys.executable
WINDOWS_BUILD_MAX_OLD_SPACE_MB = 4096

BUILD_ALL_STEPS = [
    {"label": "canvas:a2ui:bundle", "kind": "pnpm", "pnpmArgs": ["canvas:a2ui:bundle"]},
    {"label": "tsdown", "kind": "node", "args": ["scripts/tsdown-build.mjs"]},
    {"label": "runtime-postbuild", "kind": "node", "args": ["scripts/runtime-postbuild.mjs"]},
    {
        "label": "write-npm-update-compat-sidecars",
        "kind": "node",
        "args": ["scripts/write-npm-update-compat-sidecars.mjs"],
    },
    {"label": "build-stamp", "kind": "node", "args": ["scripts/build-stamp.mjs"]},
    {
        "label": "build:plugin-sdk:dts",
        "kind": "pnpm",
        "pnpmArgs": ["build:plugin-sdk:dts"],
        "windowsNodeOptions": f"--max-old-space-size={WINDOWS_BUILD_MAX_OLD_SPACE_MB}",
    },
    {
        "label": "write-plugin-sdk-entry-dts",
        "kind": "node",
        "args": ["--import", "tsx", "scripts/write-plugin-sdk-entry-dts.ts"],
    },
    {
        "label": "check-plugin-sdk-exports",
        "kind": "node",
        "args": ["scripts/check-plugin-sdk-exports.mjs"],
    },
    {
        "label": "canvas-a2ui-copy",
        "kind": "node",
        "args": ["--import", "tsx", "scripts/canvas-a2ui-copy.ts"],
    },
    {
        "label": "copy-hook-metadata",
        "kind": "node",
        "args": ["--import", "tsx", "scripts/copy-hook-metadata.ts"],
    },
    {
        "label": "copy-export-html-templates",
        "kind": "node",
        "args": ["--import", "tsx", "scripts/copy-export-html-templates.ts"],
    },
    {
        "label": "write-build-info",
        "kind": "node",
        "args": ["--import", "tsx", "scripts/write-build-info.ts"],
    },
    {
        "label": "write-cli-startup-metadata",
        "kind": "node",
        "args": ["--experimental-strip-types", "scripts/write-cli-startup-metadata.ts"],
    },
    {
        "label": "write-cli-compat",
        "kind": "node",
        "args": ["--import", "tsx", "scripts/write-cli-compat.ts"],
    },
]


def resolve_step_env(step, env, platform):
    """Löst die Umgebungsvariablen für einen Schritt auf."""
    if platform != "win32" or not step.get("windowsNodeOptions"):
        return env
    current_node_options = env.get("NODE_OPTIONS", "").strip()
    if step["windowsNodeOptions"] in current_node_options:
        return env
    new_options = (
        f"{current_node_options} {step['windowsNodeOptions']}" if current_node_options else step["windowsNodeOptions"]
    )
    return {**env, "NODE_OPTIONS": new_options}


def resolve_build_all_step(step, params=None):
    """Löst einen Build-Schritt auf und gibt das Kommando zum Ausführen zurück."""
    if params is None:
        params = {}
    platform = params.get("platform", sys.platform)
    env = resolve_step_env(step, params.get("env", os.environ), platform)

    if step["kind"] == "pnpm":
        runner = resolve_pnpm_runner(
            pnpm_args=step["pnpmArgs"],
            node_exec_path=params.get("nodeExecPath", node_bin),
            npm_exec_path=params.get("npmExecPath", env.get("npm_execpath")),
            com_spec=params.get("comSpec", env.get("ComSpec")),
            platform=platform,
        )
        return {
            "command": runner["command"],
            "args": runner["args"],
            "options": {
                "env": env,
                "shell": runner.get("shell"),
                "windows_verbatim_arguments": runner.get("windows_verbatim_arguments"),
            },
        }

    return {
        "command": params.get("nodeExecPath", node_bin),
        "args": step["args"],
        "options": {
            "env": env,
        },
    }


def is_main_module():
    """Prüft, ob dieses Skript als Hauptmodul ausgeführt wird."""
    # In Python können wir nicht direkt import.meta.url vergleichen.
    # Stattdessen prüfen wir, ob __name__ == "__main__" und ob sys.argv[0] auf diese Datei zeigt.
    # Dies ist eine Näherung. Wir verwenden einfach den Standardweg.
    return True


if __name__ == "__main__":
    for step in BUILD_ALL_STEPS:
        print(f"[build-all] {step['label']}", file=sys.stderr)
        invocation = resolve_build_all_step(step)
        cmd = [invocation["command"]] + invocation["args"]
        options = invocation["options"]

        # Bereite die Umgebung vor
        env = options.get("env", os.environ)
        shell = options.get("shell", False)
        windows_verbatim_arguments = options.get("windows_verbatim_arguments", None)

        try:
            # Unter Windows kann es sein, dass wir shell=True benötigen
            # subprocess.Popen oder subprocess.run akzeptiert cwd, env, shell etc.
            # Für maximale Kompatibilität verwenden wir subprocess.run
            result = subprocess.run(
                cmd,
                env=env,
                shell=shell,
                cwd=os.getcwd(),
            )
            if result.returncode != 0:
                sys.exit(result.returncode)
        except Exception as e:
            print(f"Fehler beim Ausführen von {step['label']}: {e}", file=sys.stderr)
            sys.exit(1)
