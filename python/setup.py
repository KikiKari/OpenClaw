#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "13d9fb62e4898f850b90d6646e1f7ed87c7bcd24864f474b1ce80a145d4a1775", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "python"}
# setup.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# One-time host setup for rootless OpenClaw in Podman. Uses the current
# non-root user throughout, builds or pulls the image into that user's Podman
# store, writes config under ~/.openclaw by default, and uses the repo-local
# launch script at ./scripts/run-openclaw-podman.sh.
#
# Usage: ./scripts/podman/setup.py [--quadlet|--container]
#   --quadlet   Install a Podman Quadlet as the current user's systemd service
#   --container Only install image + config; you start the container manually (default)
#   Or set OPENCLAW_PODMAN_QUADLET=1 (or 0) to choose without a flag.
#
# After this, start the gateway manually:
#   ./scripts/run-openclaw-podman.sh launch
#   ./scripts/run-openclaw-podman.sh launch setup
# Or, if you used --quadlet:
#   systemctl --user start openclaw.service
import os
import sys
import subprocess
import tempfile
import shutil
import json
import stat
import argparse
import re
from pathlib import Path

def require_cmd(cmd):
    """Check if command exists in PATH"""
    if not shutil.which(cmd):
        print(f"Missing dependency: {cmd}", file=sys.stderr)
        sys.exit(1)

def is_root():
    """Check if running as root"""
    return os.geteuid() == 0

def fail(msg):
    """Print error message and exit"""
    print(msg, file=sys.stderr)
    sys.exit(1)

def validate_single_line_value(label, value):
    """Validate that value doesn't contain newlines or carriage returns"""
    if '\n' in value or '\r' in value:
        fail(f"Invalid {label}: control characters are not allowed.")

def validate_absolute_path(label, value):
    """Validate that value is an absolute path without problematic patterns"""
    validate_single_line_value(label, value)
    if not value.startswith('/'):
        fail(f"Invalid {label}: expected an absolute path.")
    if '//' in value:
        fail(f"Invalid {label}: repeated slashes are not allowed.")
    if '/./' in value or value.endswith('/.') or '/../' in value or value.endswith('/..'):
        fail(f"Invalid {label}: dot path segments are not allowed.")

def validate_mount_source_path(label, value):
    """Validate mount source path (absolute path without colons)"""
    validate_absolute_path(label, value)
    if ':' in value:
        fail(f"Invalid {label}: ':' is not allowed in Podman bind-mount source paths.")

def validate_container_name(value):
    """Validate container name format"""
    validate_single_line_value("container name", value)
    if not re.match(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$', value):
        fail(f"Invalid container name: {value}")

def validate_image_name(value):
    """Validate image name format"""
    validate_single_line_value("image name", value)
    
    # Check for forbidden transport prefixes
    forbidden_prefixes = ['oci-archive:', 'docker-archive:', 'dir:', 'oci:', 
                         'containers-storage:', 'docker-daemon:', 'archive:']
    for prefix in forbidden_prefixes:
        if value.startswith(prefix):
            fail(f"Invalid image name: transport prefixes are not allowed: {value}")
    
    if not re.match(r'^[A-Za-z0-9][A-Za-z0-9._/:@-]*$', value):
        fail(f"Invalid image name: {value}")

def ensure_safe_existing_dir(label, dir_path):
    """Ensure directory exists and is safe"""
    validate_absolute_path(label, dir_path)
    if not os.path.isdir(dir_path):
        fail(f"Missing {label}: {dir_path}")
    if os.path.islink(dir_path):
        fail(f"Unsafe {label}: symlinks are not allowed ({dir_path})")

def stat_uid(path):
    """Get UID of path"""
    return os.stat(path).st_uid

def stat_mode(path):
    """Get octal mode of path"""
    return stat.S_IMODE(os.stat(path).st_mode)

def ensure_private_existing_dir_owned_by_user(label, dir_path):
    """Ensure directory exists, is owned by current user, and has secure permissions"""
    ensure_safe_existing_dir(label, dir_path)
    uid = stat_uid(dir_path)
    if uid != os.geteuid():
        fail(f"Unsafe {label}: not owned by current user ({dir_path})")
    mode = stat_mode(dir_path)
    if mode & 0o022:  # Check if group/other have write permissions
        fail(f"Unsafe {label}: group/other writable ({dir_path})")

def ensure_safe_write_file_path(label, file_path):
    """Ensure file path is safe for writing"""
    validate_absolute_path(label, file_path)
    if os.path.exists(file_path):
        if os.path.islink(file_path):
            fail(f"Unsafe {label}: symlinks are not allowed ({file_path})")
        if not os.path.isfile(file_path):
            fail(f"Unsafe {label}: expected a regular file ({file_path})")
    
    dir_path = os.path.dirname(file_path)
    ensure_safe_existing_dir(f"{label} parent directory", dir_path)

def write_file_atomically(file_path, content, mode=0o600):
    """Write content to file atomically with specified mode"""
    ensure_safe_write_file_path("output file", file_path)
    dir_path = os.path.dirname(file_path)
    
    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_path, delete=False) as tmp:
        tmp.write(content)
        tmp_name = tmp.name
    
    try:
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, file_path)
    except Exception:
        os.unlink(tmp_name)
        raise

def validate_port(label, value):
    """Validate port number"""
    if not re.match(r'^[0-9]{1,5}$', value):
        fail(f"Invalid {label}: must be numeric.")
    
    numeric = int(value)
    if not (1 <= numeric <= 65535):
        fail(f"Invalid {label}: out of range.")

def escape_sed_replacement_pipe_delim(text):
    """Escape text for sed replacement with pipe delimiter"""
    return re.sub(r'[\\&|]', r'\\\g<0>', text)

def resolve_user_home(user):
    """Resolve home directory for user"""
    home = os.environ.get('HOME', '')
    if home:
        return home
    
    # Try getent first
    try:
        result = subprocess.run(['getent', 'passwd', user], 
                              capture_output=True, text=True, check=True)
        parts = result.stdout.strip().split(':')
        if len(parts) >= 6:
            return parts[5]
    except subprocess.CalledProcessError:
        pass
    
    # Try /etc/passwd
    try:
        with open('/etc/passwd', 'r') as f:
            for line in f:
                parts = line.strip().split(':')
                if len(parts) >= 6 and parts[0] == user:
                    return parts[5]
    except FileNotFoundError:
        pass
    
    return f"/home/{user}"

def generate_token_hex_32():
    """Generate 32-byte hex token"""
    try:
        import secrets
        return secrets.token_hex(32)
    except ImportError:
        pass
    
    try:
        result = subprocess.run(['openssl', 'rand', '-hex', '32'], 
                               capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    try:
        result = subprocess.run(['od', '-An', '-N32', '-tx1', '/dev/urandom'], 
                               capture_output=True, text=True, check=True)
        return re.sub(r'\s+', '', result.stdout)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    print("Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.", 
          file=sys.stderr)
    sys.exit(1)

def seed_local_control_ui_origins(config_file, port):
    """Seed gateway.controlUi.allowedOrigins in config file"""
    ensure_safe_write_file_path("config file", config_file)
    
    if not os.path.exists(config_file):
        return
    
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        print(f"Warning: unable to seed gateway.controlUi.allowedOrigins in {config_file}: "
              f"existing config is not strict JSON ({exc}). Leaving file unchanged.", 
              file=sys.stderr)
        return
    
    if not isinstance(data, dict):
        print(f"{config_file}: expected top-level object", file=sys.stderr)
        return
    
    gateway = data.setdefault("gateway", {})
    if not isinstance(gateway, dict):
        print(f"{config_file}: expected gateway object", file=sys.stderr)
        return
    
    gateway.setdefault("mode", "local")
    control_ui = gateway.setdefault("controlUi", {})
    if not isinstance(control_ui, dict):
        print(f"{config_file}: expected gateway.controlUi object", file=sys.stderr)
        return
    
    allowed = control_ui.get("allowedOrigins")
    managed_localhosts = {"127.0.0.1", "localhost"}
    desired = [
        f"http://127.0.0.1:{port}",
        f"http://localhost:{port}",
    ]
    
    if not isinstance(allowed, list):
        allowed = []
    
    cleaned = []
    for origin in allowed:
        if not isinstance(origin, str):
            continue
        normalized = origin.strip()
        if not normalized:
            continue
        if normalized.startswith("http://"):
            host_port = normalized[len("http://"):]
            host = host_port.split(":", 1)[0]
            if host in managed_localhosts:
                continue
        cleaned.append(normalized)
    
    control_ui["allowedOrigins"] = cleaned + desired
    
    dir_path = os.path.dirname(config_file)
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_path, delete=False) as tmp:
        json.dump(data, tmp, indent=2)
        tmp.write("\n")
        tmp_name = tmp.name
    
    try:
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, config_file)
    except Exception:
        os.unlink(tmp_name)
        raise

def upsert_env_var(file_path, key, value):
    """Insert or update environment variable in file"""
    ensure_safe_write_file_path("env file", file_path)
    lines = []
    
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            lines = f.readlines()
    
    found = False
    new_lines = []
    for line in lines:
        if line.startswith(f"{key}="):
            new_lines.append(f"{key}={value}\n")
            found = True
        else:
            new_lines.append(line)
    
    if not found:
        new_lines.append(f"{key}={value}\n")
    
    with open(file_path, 'w') as f:
        f.writelines(new_lines)
    
    try:
        os.chmod(file_path, 0o600)
    except OSError:
        pass

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--quadlet', action='store_true', help='Install Quadlet service')
    parser.add_argument('--container', action='store_true', help='Only install image + config')
    args = parser.parse_args()
    
    # Determine installation mode
    install_quadlet = args.quadlet
    if args.container:
        install_quadlet = False
    
    # Check environment variable override
    quadlet_env = os.environ.get('OPENCLAW_PODMAN_QUADLET', '')
    if quadlet_env:
        quadlet_env_lower = quadlet_env.lower()
        if quadlet_env_lower in ('1', 'yes', 'true'):
            install_quadlet = True
        elif quadlet_env_lower in ('0', 'no', 'false'):
            install_quadlet = False
    
    # Platform check
    platform_name = os.uname().sysname if hasattr(os, 'uname') else 'unknown'
    if install_quadlet and platform_name != 'Linux':
        fail("--quadlet is only supported on Linux with systemd user services.")
    
    # Configuration
    repo_path = os.environ.get('OPENCLAW_REPO_PATH')
    if not repo_path:
        script_dir = Path(__file__).parent.parent.parent
        repo_path = str(script_dir.resolve())
    
    run_script_src = os.path.join(repo_path, 'scripts', 'run-openclaw-podman.sh')
    quadlet_template = os.path.join(repo_path, 'scripts', 'podman', 'openclaw.container.in')
    
    openclaw_user = os.environ.get('USER', '')
    if not openclaw_user:
        openclaw_user = subprocess.check_output(['id', '-un'], text=True).strip()
    
    openclaw_home = os.environ.get('HOME', '')
    if not openclaw_home:
        openclaw_home = resolve_user_home(openclaw_user)
    
    openclaw_config_dir = os.environ.get('OPENCLAW_CONFIG_DIR', '')
    if not openclaw_config_dir:
        openclaw_config_dir = os.path.join(openclaw_home, '.openclaw')
    
    openclaw_workspace_dir = os.environ.get('OPENCLAW_WORKSPACE_DIR', '')
    if not openclaw_workspace_dir:
        openclaw_workspace_dir = os.path.join(openclaw_config_dir, 'workspace')
    
    openclaw_image = os.environ.get('OPENCLAW_PODMAN_IMAGE', 
                                   os.environ.get('OPENCLAW_IMAGE', 'openclaw:local'))
    openclaw_container_name = os.environ.get('OPENCLAW_PODMAN_CONTAINER', 'openclaw')
    host_gateway_port = os.environ.get('OPENCLAW_PODMAN_GATEWAY_HOST_PORT', 
                                      os.environ.get('OPENCLAW_GATEWAY_PORT', '18789'))
    quadlet_gateway_port = '18789'
    
    seed_gateway_port = host_gateway_port if not install_quadlet else quadlet_gateway_port
    
    # Validation
    require_cmd('podman')
    if is_root():
        print("Run scripts/podman/setup.py as your normal user so Podman stays rootless.", 
              file=sys.stderr)
        sys.exit(1)
    
    dockerfile_path = os.path.join(repo_path, 'Dockerfile')
    if openclaw_image == 'openclaw:local' and not os.path.exists(dockerfile_path):
        print(f"Dockerfile not found at {repo_path}. Set OPENCLAW_REPO_PATH to the repo root.", 
              file=sys.stderr)
        sys.exit(1)
    
    if not os.path.exists(run_script_src):
        print(f"Launch script not found at {run_script_src}.", file=sys.stderr)
        sys.exit(1)
    
    if not openclaw_home:
        print(f"Unable to resolve HOME for user {openclaw_user}.", file=sys.stderr)
        sys.exit(1)
    
    validate_absolute_path("home directory", openclaw_home)
    validate_mount_source_path("config directory", openclaw_config_dir)
    validate_mount_source_path("workspace directory", openclaw_workspace_dir)
    validate_container_name(openclaw_container_name)
    validate_image_name(openclaw_image)
    validate_port("gateway host port", host_gateway_port)
    validate_port("seed gateway port", seed_gateway_port)
    
    # Create directories
    os.makedirs(openclaw_config_dir, mode=0o700, exist_ok=True)
    os.makedirs(openclaw_workspace_dir, mode=0o700, exist_ok=True)
    ensure_private_existing_dir_owned_by_user("config directory", openclaw_config_dir)
    ensure_private_existing_dir_owned_by_user("workspace directory", openclaw_workspace_dir)
    
    # Build or pull image
    build_args = []
    if os.environ.get('OPENCLAW_DOCKER_APT_PACKAGES'):
        build_args.extend(['--build-arg', f"OPENCLAW_DOCKER_APT_PACKAGES={os.environ['OPENCLAW_DOCKER_APT_PACKAGES']}"])
    if os.environ.get('OPENCLAW_EXTENSIONS'):
        build_args.extend(['--build-arg', f"OPENCLAW_EXTENSIONS={os.environ['OPENCLAW_EXTENSIONS']}"])
    
    if openclaw_image == 'openclaw:local':
        print(f"Building image {openclaw_image} ...")
        cmd = ['podman', 'build', '-t', openclaw_image, '-f', dockerfile_path] + build_args + [repo_path]
        subprocess.run(cmd, check=True)
    else:
        # Check if image exists
        result = subprocess.run(['podman', 'image', 'exists', openclaw_image], 
                               capture_output=True)
        if result.returncode == 0:
            print(f"Using existing image {openclaw_image}")
        else:
            print(f"Pulling image {openclaw_image} ...")
            subprocess.run(['podman', 'pull', openclaw_image], check=True)
    
    # Handle environment file
    env_file = os.path.join(openclaw_config_dir, '.env')
    if not os.path.exists(env_file):
        token = generate_token_hex_32()
        content = f"OPENCLAW_GATEWAY_TOKEN={token}\n"
        write_file_atomically(env_file, content, 0o600)
        print(f"Generated OPENCLAW_GATEWAY_TOKEN and wrote it to {env_file}")
    
    upsert_env_var(env_file, "OPENCLAW_PODMAN_CONTAINER", openclaw_container_name)
    upsert_env_var(env_file, "OPENCLAW_PODMAN_IMAGE", openclaw_image)
    
    # Handle config file
    config_json = os.path.join(openclaw_config_dir, 'openclaw.json')
    if not os.path.exists(config_json):
        content = json.dumps({
            "gateway": {
                "mode": "local",
                "controlUi": {
                    "allowedOrigins": [
                        f"http://127.0.0.1:{seed_gateway_port}",
                        f"http://localhost:{seed_gateway_port}"
                    ]
                }
            }
        }, indent=2) + "\n"
        write_file_atomically(config_json, content, 0o600)
        print(f"Wrote minimal config to {config_json}")
    
    seed_local_control_ui_origins(config_json, seed_gateway_port)
    
    # Handle Quadlet installation
    if install_quadlet:
        quadlet_dir = os.path.join(openclaw_home, '.config', 'containers', 'systemd')
        quadlet_dst = os.path.join(quadlet_dir, 'openclaw.container')
        print(f"Installing Quadlet to {quadlet_dst} ...")
        os.makedirs(quadlet_dir, exist_ok=True)
        ensure_safe_existing_dir("quadlet directory", quadlet_dir)
        
        # Read template and substitute variables
        with open(quadlet_template, 'r') as f:
            template_content = f.read()
        
        # Escape values for sed-like replacement
        openclaw_home_escaped = escape_sed_replacement_pipe_delim(openclaw_home)
        openclaw_config_escaped = escape_sed_replacement_pipe_delim(openclaw_config_dir)
        openclaw_workspace_escaped = escape_sed_replacement_pipe_delim(openclaw_workspace_dir)
        openclaw_image_escaped = escape_sed_replacement_pipe_delim(openclaw_image)
        openclaw_container_escaped = escape_sed_replacement_pipe_delim(openclaw_container_name)
        
        # Perform substitutions
        content = template_content
        content = content.replace('{{OPENCLAW_HOME}}', openclaw_home_escaped)
        content = content.replace('{{OPENCLAW_CONFIG_DIR}}', openclaw_config_escaped)
        content = content.replace('{{OPENCLAW_WORKSPACE_DIR}}', openclaw_workspace_escaped)
        content = content.replace('{{IMAGE_NAME}}', openclaw_image_escaped)
        content = content.replace('{{CONTAINER_NAME}}', openclaw_container_escaped)
        
        write_file_atomically(quadlet_dst, content, 0o644)
        
        # Try to start service
        if shutil.which('systemctl'):
            print("Reloading and starting user service...")
            try:
                subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
                subprocess.run(['systemctl', '--user', 'start', 'openclaw.service'], check=True)
                print("Quadlet installed and service started.")
            except subprocess.CalledProcessError:
                print("Quadlet installed, but automatic start failed.", file=sys.stderr)
                print("Try: systemctl --user daemon-reload && systemctl --user start openclaw.service", 
                      file=sys.stderr)
                if shutil.which('loginctl'):
                    print(f"For boot persistence on headless hosts, you may also need: "
                          f"sudo loginctl enable-linger {openclaw_user}", file=sys.stderr)
        else:
            print("systemctl not found; Quadlet installed but not started.", file=sys.stderr)
    else:
        print("Container setup complete.")
    
    print()
    print("Next:")
    print("  ./scripts/run-openclaw-podman.sh launch")
    print("  ./scripts/run-openclaw-podman.sh launch setup")
    print(f"  openclaw --container {openclaw_container_name} dashboard --no-open")

if __name__ == '__main__':
    main()
