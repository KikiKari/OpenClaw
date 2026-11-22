#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "022f6b6a271f163c454d226a2de80d521f52f86ca860793b6f3305a4a41e4e0e", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "python"}
# run.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def get_env_var(name, default=None):
    """Get environment variable or return default."""
    value = os.environ.get(name, "")
    if not value and default is not None:
        return default
    return value


def run_command(cmd, capture_output=True, cwd=None):
    """Run a command and return its result."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=capture_output,
            text=True,
            check=True,
            cwd=cwd
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        if capture_output:
            print(f"Command failed: {cmd}", file=sys.stderr)
            print(f"stdout: {e.stdout}", file=sys.stderr)
            print(f"stderr: {e.stderr}", file=sys.stderr)
        raise


def quiet_npm(args):
    """Run npm command with quiet output."""
    env = os.environ.copy()
    env["npm_config_loglevel"] = "silent"
    env["NPM_CONFIG_LOGLEVEL"] = "silent"
    
    cmd = f"npm {args}"
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            check=True,
            env=env
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"npm command failed: {cmd}", file=sys.stderr)
        print(f"stdout: {e.stdout}", file=sys.stderr)
        print(f"stderr: {e.stderr}", file=sys.stderr)
        raise


def verify_installed_cli(package_name, expected_version):
    """Verify that the CLI was installed correctly."""
    script_dir = Path(__file__).parent
    cli_verify_path = script_dir.parent / "install-sh-common" / "cli-verify.sh"
    
    if not cli_verify_path.exists():
        raise FileNotFoundError(f"cli-verify.sh not found at {cli_verify_path}")
    
    # Source and run the verification function
    env = os.environ.copy()
    env["EXPECTED_VERSION"] = expected_version
    
    cmd = f'. "{cli_verify_path}"; verify_installed_cli "{package_name}" "$EXPECTED_VERSION"'
    try:
        subprocess.run(
            ["bash", "-c", cmd],
            check=True,
            env=env
        )
    except subprocess.CalledProcessError:
        raise RuntimeError("CLI verification failed")


def find_previous_version(latest_version, versions_json):
    """Find the previous version using Node.js logic."""
    node_script = """
const latest = String(process.env.LATEST_VERSION || "");
const raw = process.env.VERSIONS_JSON || "[]";
let versions;
try {
  versions = JSON.parse(raw);
} catch {
  versions = raw ? [raw] : [];
}
if (!Array.isArray(versions)) {
  versions = [versions];
}
if (versions.length === 0 || latest.length === 0) {
  process.exit(1);
}
const latestIndex = versions.lastIndexOf(latest);
if (latestIndex <= 0) {
  process.stdout.write(latest);
  process.exit(0);
}
process.stdout.write(String(versions[latestIndex - 1] ?? latest));
"""
    
    env = os.environ.copy()
    env["LATEST_VERSION"] = latest_version
    env["VERSIONS_JSON"] = versions_json
    
    result = subprocess.run(
        ["node", "-e", node_script],
        capture_output=True,
        text=True,
        check=True,
        env=env
    )
    return result.stdout.strip()


def run_install_smoke():
    """Run installation smoke test."""
    install_url = get_env_var("OPENCLAW_INSTALL_URL", "https://openclaw.bot/install.sh")
    fresh_version = get_env_var("OPENCLAW_INSTALL_FRESH_VERSION")
    fresh_tag_url = get_env_var("OPENCLAW_INSTALL_FRESH_TAG_URL")
    package_name = get_env_var("OPENCLAW_INSTALL_PACKAGE", "openclaw")
    skip_previous = get_env_var("OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS", "0")
    smoke_previous_version = get_env_var("OPENCLAW_INSTALL_SMOKE_PREVIOUS")
    
    if fresh_version and fresh_tag_url:
        print(f"package={package_name} latest={fresh_version} source={fresh_tag_url}")
        print("==> Install latest release tarball")
        quiet_npm(f"install -g --omit=optional {fresh_tag_url}")
        
        print("==> Verify installed version")
        latest_out = get_env_var("OPENCLAW_INSTALL_LATEST_OUT")
        if latest_out:
            Path(latest_out).write_text(fresh_version)
        
        verify_installed_cli(package_name, fresh_version)
        print("OK")
        return
    
    print("==> Resolve npm versions")
    if skip_previous == "1":
        latest_version = quiet_npm(f"view {package_name} version")
        previous_version = latest_version
    elif smoke_previous_version:
        latest_version = quiet_npm(f"view {package_name} version")
        previous_version = smoke_previous_version
    else:
        latest_version = quiet_npm(f"view {package_name} dist-tags.latest")
        versions_json = quiet_npm(f"view {package_name} versions --json")
        previous_version = find_previous_version(latest_version, versions_json)
    
    print(f"package={package_name} latest={latest_version} previous={previous_version}")
    
    if skip_previous == "1":
        print("==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)")
    else:
        print("==> Preinstall previous (forces installer upgrade path)")
        quiet_npm(f"install -g {package_name}@{previous_version}")
    
    print("==> Run official installer one-liner")
    subprocess.run(
        f"curl -fsSL {install_url} | bash -s -- --no-prompt",
        shell=True,
        check=True
    )
    
    print("==> Verify installed version")
    latest_out = get_env_var("OPENCLAW_INSTALL_LATEST_OUT")
    if latest_out:
        Path(latest_out).write_text(latest_version)
    
    verify_installed_cli(package_name, latest_version)
    print("OK")


def run_update_smoke():
    """Run update smoke test."""
    package_name = get_env_var("OPENCLAW_INSTALL_PACKAGE", "openclaw")
    update_expect_version = get_env_var("OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION")
    update_tag_url = get_env_var("OPENCLAW_INSTALL_UPDATE_TAG_URL")
    update_baseline_version = get_env_var("OPENCLAW_INSTALL_UPDATE_BASELINE", "2026.4.10")
    update_baseline_tag_url = get_env_var("OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL")
    
    if not update_expect_version:
        print("ERROR: OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode", file=sys.stderr)
        sys.exit(1)
    
    if not update_tag_url:
        print("ERROR: OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode", file=sys.stderr)
        sys.exit(1)
    
    print(f"package={package_name} baseline={update_baseline_version} target={update_expect_version}")
    print("==> Install baseline release")
    
    if update_baseline_tag_url:
        quiet_npm(f"install -g --omit=optional {update_baseline_tag_url}")
    else:
        quiet_npm(f"install -g --omit=optional {package_name}@{update_baseline_version}")
    
    verify_installed_cli(package_name, update_baseline_version)
    
    print("==> Run openclaw update from host-served tgz")
    
    with tempfile.NamedTemporaryFile(mode='w+', delete=False) as tmp_file:
        tmp_filename = tmp_file.name
    
    try:
        env = os.environ.copy()
        env["npm_config_omit"] = "optional"
        env["NPM_CONFIG_OMIT"] = "optional"
        
        update_cmd = [
            "openclaw", 
            "update", 
            "--tag", update_tag_url,
            "--yes",
            "--json"
        ]
        
        try:
            result = subprocess.run(
                update_cmd,
                capture_output=True,
                text=True,
                check=True,
                env=env
            )
            update_json = result.stdout.strip()
            update_stderr = result.stderr.strip()
        except subprocess.CalledProcessError as e:
            update_json = e.stdout.strip() if e.stdout else ""
            update_stderr = e.stderr.strip() if e.stderr else ""
            update_status = e.returncode
            
            print(update_json)
            if update_stderr:
                print(update_stderr, file=sys.stderr)
            
            print(f"ERROR: openclaw update failed with exit code {update_status}", file=sys.stderr)
            sys.exit(update_status)
        
        print(update_json)
        if update_stderr:
            print(update_stderr, file=sys.stderr)
        
        # Validate update JSON with Node.js
        validation_script = """
const payload = JSON.parse(process.env.UPDATE_JSON || "{}");
const expectedVersion = String(process.env.UPDATE_EXPECT_VERSION || "");
const baselineVersion = String(process.env.UPDATE_BASELINE_VERSION || "");
const expectedUrl = String(process.env.UPDATE_TAG_URL || "");
if (payload.status !== "ok") {
  throw new Error(`expected update status ok, got ${JSON.stringify(payload.status)}`);
}
if ((payload.before?.version ?? null) !== baselineVersion) {
  throw new Error(
    `expected before.version ${baselineVersion}, got ${JSON.stringify(payload.before?.version)}`,
  );
}
if ((payload.after?.version ?? null) !== expectedVersion) {
  throw new Error(
    `expected after.version ${expectedVersion}, got ${JSON.stringify(payload.after?.version)}`,
  );
}
if (payload.reason != null) {
  throw new Error(`expected no failure reason, got ${JSON.stringify(payload.reason)}`);
}
const steps = Array.isArray(payload.steps) ? payload.steps : [];
const updateStep = steps.find((step) => step?.name === "global update");
if (!updateStep) {
  throw new Error("missing global update step in update JSON");
}
if (Number(updateStep.exitCode ?? 1) !== 0) {
  throw new Error(`global update step failed: ${JSON.stringify(updateStep)}`);
}
if (typeof updateStep.command !== "string" || !updateStep.command.includes(expectedUrl)) {
  throw new Error(`global update step missing expected tgz URL: ${JSON.stringify(updateStep)}`);
}
"""
        
        validate_env = os.environ.copy()
        validate_env["UPDATE_JSON"] = update_json
        validate_env["UPDATE_EXPECT_VERSION"] = update_expect_version
        validate_env["UPDATE_BASELINE_VERSION"] = update_baseline_version
        validate_env["UPDATE_TAG_URL"] = update_tag_url
        
        subprocess.run(
            ["node", "-e", validation_script],
            check=True,
            env=validate_env
        )
        
        print("==> Verify updated version")
        verify_installed_cli(package_name, update_expect_version)
        print("OK")
        
    finally:
        if os.path.exists(tmp_filename):
            os.unlink(tmp_filename)


def main():
    """Main entry point."""
    smoke_mode = get_env_var("OPENCLAW_INSTALL_SMOKE_MODE", "install")
    
    if smoke_mode == "install":
        run_install_smoke()
    elif smoke_mode == "update":
        run_update_smoke()
    else:
        print(f"ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE={smoke_mode}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
