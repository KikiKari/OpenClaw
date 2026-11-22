#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "69c21597ac158e2eec4971fe8e0915bd164a0576130e2c6273856cdbd159ac53", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "python"}
# run.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import urllib.request

def run_command(command, check=True, capture_output=False):
    """Helper function to run shell commands"""
    try:
        result = subprocess.run(command, shell=True, check=check, 
                              capture_output=capture_output, text=True)
        return result.stdout.strip() if capture_output else None
    except subprocess.CalledProcessError as e:
        if not capture_output:
            print(f"Command failed: {command}", file=sys.stderr)
            sys.exit(1)
        raise e

def source_script(script_path):
    """Source a shell script and import its environment variables"""
    # This is a simplified approach - in practice, fully sourcing shell scripts
    # in Python is complex. We'll handle the specific case we need.
    pass

def verify_installed_cli(package_name, expected_version):
    """Verify that the CLI is installed with correct version"""
    try:
        # Get installed version
        result = subprocess.run(['npm', 'list', '-g', package_name], 
                              capture_output=True, text=True)
        if expected_version:
            if expected_version in result.stdout:
                print(f"✓ {package_name}@{expected_version} is installed")
            else:
                print(f"✗ Expected {package_name}@{expected_version}, but got different version", file=sys.stderr)
                sys.exit(1)
        else:
            if package_name in result.stdout:
                print(f"✓ {package_name} is installed")
            else:
                print(f"✗ {package_name} is not installed", file=sys.stderr)
                sys.exit(1)
    except Exception as e:
        print(f"✗ Failed to verify {package_name} installation: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    INSTALL_URL = os.environ.get('OPENCLAW_INSTALL_URL', 'https://openclaw.bot/install.sh')
    DEFAULT_PACKAGE = "openclaw"
    PACKAGE_NAME = os.environ.get('OPENCLAW_INSTALL_PACKAGE', DEFAULT_PACKAGE)
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

    # Source the verification script (simplified)
    # In practice, this would require more sophisticated handling
    # source "$SCRIPT_DIR/../install-sh-common/cli-verify.sh"

    print("==> Pre-flight: ensure git absent")
    try:
        subprocess.run(['git', '--version'], 
                     check=True, capture_output=True)
        print("git is present unexpectedly", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError:
        pass  # This is what we want - git should not be present

    print("==> Pre-flight: ensure supported Node is already present")
    try:
        result = subprocess.run(['node', '-e', '''
  const version = process.versions.node.split(".").map(Number);
  const ok =
    version.length >= 2 &&
    (version[0] > 22 || (version[0] === 22 && version[1] >= 16));
  if (!ok) {
    process.stderr.write(`unsupported node ${process.versions.node}\\n`);
    process.exit(1);
  }
'''], check=True)
    except subprocess.CalledProcessError:
        sys.exit(1)

    # Check npm exists
    try:
        subprocess.run(['npm', '--version'], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("npm not found", file=sys.stderr)
        sys.exit(1)

    print("==> Run installer (non-root user)")
    try:
        # Download and execute the install script
        response = urllib.request.urlopen(INSTALL_URL)
        script_content = response.read().decode('utf-8')
        
        # Execute the script
        result = subprocess.run(['bash'], input=script_content, 
                              text=True, capture_output=True)
        if result.returncode != 0:
            print(f"Installer failed: {result.stderr}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"Failed to download or run installer: {e}", file=sys.stderr)
        sys.exit(1)

    # Ensure PATH picks up user npm prefix
    home_dir = os.path.expanduser('~')
    npm_bin_path = f"{home_dir}/.npm-global/bin"
    os.environ['PATH'] = f"{npm_bin_path}:{os.environ.get('PATH', '')}"

    print("==> Verify git installed")
    try:
        subprocess.run(['git', '--version'], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("git not installed after installation", file=sys.stderr)
        sys.exit(1)

    EXPECTED_VERSION = os.environ.get('OPENCLAW_INSTALL_EXPECT_VERSION', '')
    
    if EXPECTED_VERSION:
        LATEST_VERSION = EXPECTED_VERSION
    else:
        try:
            # Get latest version using npm view (quiet mode)
            result = subprocess.run(['npm', 'view', PACKAGE_NAME, 'version'], 
                                  capture_output=True, text=True, check=True)
            LATEST_VERSION = result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Failed to get package version: {e}", file=sys.stderr)
            sys.exit(1)

    print("==> Verify CLI installed")
    verify_installed_cli(PACKAGE_NAME, LATEST_VERSION)

    print("OK")

if __name__ == "__main__":
    main()
