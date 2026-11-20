#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "af2f1efca1f529a540d5e562438306e01870db7219720fc97d0ffc37f02363a2", "source_sha256": "4a2907e2ea521dc1e81ebd6e57ee9ab2269d633101a5fe398c3b55dfc0d99040", "target_language": "python"}
# install.ps1 — portiert nach python
# Quelle: powershell, workspace@local:skills/github-clones/openclaw/scripts/install.ps1
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

"""
OpenClaw Installer for Windows (Python)
Usage: python -c "import urllib.request; exec(urllib.request.urlopen('https://openclaw.ai/install.py').read())"
"""

import argparse
import os
import sys
import subprocess
import shutil
import re
from pathlib import Path


# Colors
ACCENT = "\033[38;2;255;77;77m"    # coral-bright
SUCCESS = "\033[38;2;0;229;204m"  # cyan-bright
WARN = "\033[38;2;255;176;32m"    # amber
ERROR = "\033[38;2;230;57;70m"    # coral-mid
MUTED = "\033[38;2;90;100;128m"   # text-muted
NC = "\033[0m"                    # No Color


def write_host(message, level="info"):
    """Print colored message based on level."""
    msg_map = {
        "success": f"{SUCCESS}✓{NC} {message}",
        "warn": f"{WARN}!{NC} {message}",
        "error": f"{ERROR}✗{NC} {message}",
        "default": f"{MUTED}·{NC} {message}"
    }
    msg = msg_map.get(level, msg_map["default"])
    print(msg)


def write_banner():
    """Display the installer banner."""
    print()
    print(f"{ACCENT}  🦞 OpenClaw Installer{NC}")
    print(f"{MUTED}  All your chats, one OpenClaw.{NC}")
    print()


def get_execution_policy_status():
    """Check if PowerShell execution policy blocks script execution."""
    try:
        result = subprocess.run(
            ["powershell", "-Command", "Get-ExecutionPolicy"],
            capture_output=True,
            text=True
        )
        policy = result.stdout.strip()
        blocked = policy in ("Restricted", "AllSigned")
        return {"Blocked": blocked, "Policy": policy}
    except Exception:
        return {"Blocked": True, "Policy": "Unknown"}


def test_admin():
    """Check if running with administrator privileges."""
    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False


def ensure_execution_policy():
    """Ensure PowerShell execution policy allows script execution."""
    status = get_execution_policy_status()
    if status["Blocked"]:
        write_host(f"PowerShell execution policy is set to: {status['Policy']}", "warn")
        write_host("This prevents scripts like npm.ps1 from running.", "warn")
        print()

        # Try setting execution policy for current process
        try:
            subprocess.run(
                ["powershell", "-Command", "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process"],
                check=True
            )
            write_host("Set execution policy to RemoteSigned for current process", "success")
            return True
        except subprocess.CalledProcessError:
            write_host("Could not automatically set execution policy", "error")
            print()
            write_host("To fix this, run:", "info")
            write_host("  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process", "info")
            print()
            write_host("Or run PowerShell as Administrator and execute:", "info")
            write_host("  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine", "info")
            return False
    return True


def get_node_version():
    """Get installed Node.js version."""
    try:
        result = subprocess.run(["node", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip().lstrip('v')
    except FileNotFoundError:
        pass
    return None


def get_npm_version():
    """Get installed npm version."""
    try:
        result = subprocess.run(["npm", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None


def install_node():
    """Install Node.js using available package managers."""
    write_host("Node.js not found", "info")
    write_host("Installing Node.js...", "info")

    # Try winget first
    if shutil.which("winget"):
        write_host("  Using winget...", "info")
        try:
            subprocess.run(
                ["winget", "install", "OpenJS.NodeJS.LTS", "--accept-package-agreements", "--accept-source-agreements"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            # Refresh PATH
            os.environ["PATH"] = (
                f"{os.environ.get('PATH', '')};"
                f"{subprocess.check_output(['cmd', '/c', 'echo', '%PATH%'], text=True).strip()}"
            )
            write_host("  Node.js installed via winget", "success")
            return True
        except subprocess.CalledProcessError as e:
            write_host(f"  Winget install failed: {e}", "warn")

    # Try chocolatey
    if shutil.which("choco"):
        write_host("  Using chocolatey...", "info")
        try:
            subprocess.run(
                ["choco", "install", "nodejs-lts", "-y"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            os.environ["PATH"] = (
                f"{os.environ.get('PATH', '')};"
                f"{subprocess.check_output(['cmd', '/c', 'echo', '%PATH%'], text=True).strip()}"
            )
            write_host("  Node.js installed via chocolatey", "success")
            return True
        except subprocess.CalledProcessError as e:
            write_host(f"  Chocolatey install failed: {e}", "warn")

    # Try scoop
    if shutil.which("scoop"):
        write_host("  Using scoop...", "info")
        try:
            subprocess.run(
                ["scoop", "install", "nodejs-lts"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            os.environ["PATH"] = (
                f"{os.environ.get('PATH', '')};"
                f"{subprocess.check_output(['cmd', '/c', 'echo', '%PATH%'], text=True).strip()}"
            )
            write_host("  Node.js installed via scoop", "success")
            return True
        except subprocess.CalledProcessError as e:
            write_host(f"  Scoop install failed: {e}", "warn")

    write_host("Could not install Node.js automatically", "error")
    write_host("Please install Node.js 22+ manually from: https://nodejs.org", "info")
    return False


def ensure_node():
    """Ensure Node.js is installed and meets version requirements."""
    node_version = get_node_version()
    if node_version:
        major = int(node_version.split('.')[0])
        if major >= 22:
            write_host(f"Node.js v{node_version} found", "success")
            return True
        write_host(f"Node.js v{node_version} found, but need v22+", "warn")
    return install_node()


def get_git_version():
    """Get installed Git version."""
    try:
        result = subprocess.run(["git", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None


def install_git():
    """Install Git using winget or provide manual instructions."""
    write_host("Git not found", "info")

    if shutil.which("winget"):
        write_host("  Installing Git via winget...", "info")
        try:
            subprocess.run(
                ["winget", "install", "Git.Git", "--accept-package-agreements", "--accept-source-agreements"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            os.environ["PATH"] = (
                f"{os.environ.get('PATH', '')};"
                f"{subprocess.check_output(['cmd', '/c', 'echo', '%PATH%'], text=True).strip()}"
            )
            write_host("  Git installed", "success")
            return True
        except subprocess.CalledProcessError:
            write_host("  Winget install failed", "warn")

    write_host("Please install Git for Windows from: https://git-scm.com", "error")
    return False


def ensure_git():
    """Ensure Git is installed."""
    git_version = get_git_version()
    if git_version:
        write_host(f"{git_version} found", "success")
        return True
    return install_git()


def install_openclaw_npm(target="latest"):
    """Install OpenClaw via npm."""
    install_spec = resolve_package_install_spec(target)
    write_host(f"Installing OpenClaw ({install_spec})...", "info")

    try:
        subprocess.run(
            ["npm", "install", "-g", install_spec, "--no-fund", "--no-audit"],
            check=True
        )
        write_host("OpenClaw installed", "success")
        return True
    except subprocess.CalledProcessError as e:
        write_host(f"npm install failed: {e}", "error")
        return False


def install_openclaw_git(repo_dir, update=True):
    """Install OpenClaw from Git repository."""
    write_host("Installing OpenClaw from git...", "info")

    repo_path = Path(repo_dir)
    if not repo_path.exists():
        write_host("  Cloning repository...", "info")
        subprocess.run(["git", "clone", "https://github.com/openclaw/openclaw.git", str(repo_path)])
    elif update:
        write_host("  Updating repository...", "info")
        subprocess.run(["git", "-C", str(repo_path), "pull", "--rebase"])

    # Install pnpm if not present
    if not shutil.which("pnpm"):
        write_host("  Installing pnpm...", "info")
        subprocess.run(["npm", "install", "-g", "pnpm"])

    # Install dependencies
    write_host("  Installing dependencies...", "info")
    subprocess.run(["pnpm", "install", "--dir", str(repo_path)])

    # Build
    write_host("  Building...", "info")
    subprocess.run(["pnpm", "--dir", str(repo_path), "build"])

    # Create wrapper
    wrapper_dir = Path.home() / ".local" / "bin"
    wrapper_dir.mkdir(parents=True, exist_ok=True)

    wrapper_content = '@echo off\nnode "%~dp0..\\openclaw\\dist\\entry.js" %*\n'
    wrapper_file = wrapper_dir / "openclaw.cmd"
    wrapper_file.write_text(wrapper_content, encoding="ascii")

    write_host("OpenClaw installed", "success")
    return True


def test_explicit_package_install_spec(target):
    """Test if target specifies an explicit package installation spec."""
    if not target or not target.strip():
        return False
    return (
        "://" in target or
        "#" in target or
        re.match(r'^(file|github|git\+ssh|git\+https|git\+http|git\+file|npm):', target)
    )


def resolve_package_install_spec(target="latest"):
    """Resolve package installation specification."""
    trimmed = target.strip()
    if not trimmed:
        return "openclaw@latest"
    if trimmed.lower() == "main":
        return "github:openclaw/openclaw#main"
    if test_explicit_package_install_spec(trimmed):
        return trimmed
    return f"openclaw@{trimmed}"


def add_to_path(path):
    """Add path to user's PATH environment variable."""
    current_path = os.environ.get("PATH", "")
    if path not in current_path:
        new_path = f"{current_path};{path}"
        os.system(f'setx PATH "{new_path}"')
        write_host(f"Added {path} to user PATH", "info")


def main():
    """Main installation function."""
    parser = argparse.ArgumentParser(description="OpenClaw Installer")
    parser.add_argument("--install-method", default="npm", choices=["npm", "git"])
    parser.add_argument("--tag", default="latest")
    parser.add_argument("--git-dir", default=str(Path.home() / "openclaw"))
    parser.add_argument("--no-onboard", action="store_true")
    parser.add_argument("--no-git-update", action="store_true")
    parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    write_banner()
    write_host("Windows detected", "success")

    # Check and handle execution policy FIRST, before any npm calls
    if not ensure_execution_policy():
        print()
        write_host("Installation cannot continue due to execution policy restrictions", "error")
        sys.exit(1)

    if not ensure_node():
        sys.exit(1)

    if args.install_method == "git":
        if not ensure_git():
            sys.exit(1)

        if args.dry_run:
            write_host(f"[DRY RUN] Would install OpenClaw from git to {args.git_dir}", "info")
        else:
            install_openclaw_git(args.git_dir, update=not args.no_git_update)
    else:
        # npm method
        if not ensure_git():
            write_host("Git is required for npm installs. Please install Git and try again.", "warn")

        if args.dry_run:
            spec = resolve_package_install_spec(args.tag)
            write_host(f"[DRY RUN] Would install OpenClaw via npm ({spec})", "info")
        else:
            if not install_openclaw_npm(args.tag):
                sys.exit(1)

    # Try to add npm global bin to PATH
    try:
        result = subprocess.run(["npm", "config", "get", "prefix"], capture_output=True, text=True)
        if result.returncode == 0:
            prefix = result.stdout.strip()
            add_to_path(prefix)
    except Exception:
        pass

    if not args.no_onboard and not args.dry_run:
        print()
        write_host("Run 'openclaw onboard' to complete setup", "info")

    print()
    write_host("🦞 OpenClaw installed successfully!", "success")


if __name__ == "__main__":
    main()
