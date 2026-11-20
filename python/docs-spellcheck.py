#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "33ff05c51e4028ee28d9b51b6a5e68801e376624582f9bf2799630f44c3fa73f", "source_sha256": "d563770ee41496760efbfdbb5c3e2c054ecf84de1c5e8eb2fc7cd2ad260b16ce", "target_language": "python"}
# docs-spellcheck.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docs-spellcheck.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
import site


def main():
    # Determine mode from first argument
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    write_flag = ["-w"] if mode == "--write" else []

    # Common arguments for codespell
    args = [
        "README.md",
        "docs",
        "--skip=*.png,*.jpg,*.jpeg,*.gif,*.svg",
        "-D",
        "-",
        "-D",
        "scripts/codespell-dictionary.txt",
        "-I",
        "scripts/codespell-ignore.txt"
    ] + write_flag

    # Try to run codespell directly
    if is_command_available("codespell"):
        subprocess.run(["codespell"] + args, check=True)
        return

    # Try to install and run codespell via python3
    if is_command_available("python3"):
        # Attempt to install codespell
        try:
            subprocess.run([
                "python3", "-m", "pip", "install", "--user",
                "--disable-pip-version-check", "--break-system-packages",
                "codespell"
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            try:
                subprocess.run([
                    "python3", "-m", "pip", "install", "--user",
                    "--disable-pip-version-check", "codespell"
                ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except subprocess.CalledProcessError:
                print("Failed to install codespell", file=sys.stderr)
                sys.exit(1)

        # Get user bin directory
        user_bin = f"{site.USER_BASE}/bin"

        # Run codespell if available in user bin
        codespell_path = os.path.join(user_bin, "codespell")
        if os.path.isfile(codespell_path) and os.access(codespell_path, os.X_OK):
            subprocess.run([codespell_path] + args, check=True)
            return

    # If all methods fail
    print("codespell unavailable: install codespell or python3", file=sys.stderr)
    sys.exit(1)


def is_command_available(cmd):
    """Check if a command is available in the system PATH."""
    return shutil.which(cmd) is not None


if __name__ == "__main__":
    import shutil
    main()
