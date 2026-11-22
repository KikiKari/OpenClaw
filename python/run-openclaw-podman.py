#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "a712d406dffd4c374b35c36de6e7c0eb4aef575c2c0760fce9d642acfcd4b199", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "python"}
# run-openclaw-podman.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/run-openclaw-podman.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Rootless OpenClaw in Podman: run after one-time setup.
#
# One-time setup (from repo root): ./scripts/podman/setup.sh
# Then:
#   ./scripts/run-openclaw-podman.sh launch        # Start gateway
#   ./scripts/run-openclaw-podman.sh launch setup  # Onboarding wizard
#
# Manage the running container from the host CLI:
#   openclaw --container openclaw dashboard --no-open
#   openclaw --container openclaw channels login
#
# Legacy: "setup-host" delegates to the Podman setup script

import os
import sys
import subprocess
import tempfile
import shutil
import stat
import json
import secrets
import argparse
from pathlib import Path


def resolve_user_home(user):
    """Resolve user's home directory"""
    try:
        import pwd
        return pwd.getpwnam(user).pw_dir
    except ImportError:
        # Fallback for systems without pwd module
        home = "/home/" + user
        if os.path.exists("/etc/passwd"):
            try:
                with open("/etc/passwd", "r") as f:
                    for line in f:
                        parts = line.split(":")
                        if len(parts) >= 6 and parts[0] == user:
                            return parts[5].strip()
            except Exception:
                pass
        return home


def fail(message):
    """Print error message and exit"""
    print(message, file=sys.stderr)
    sys.exit(1)


def validate_single_line_value(label, value):
    """Validate that value doesn't contain newlines or carriage returns"""
    if "\n" in value or "\r" in value:
        fail(f"Invalid {label}: control characters are not allowed.")


def validate_absolute_path(label, value):
    """Validate that value is an absolute path"""
    validate_single_line_value(label, value)
    if not value.startswith("/"):
        fail(f"Invalid {label}: expected an absolute path.")
    if "//" in value:
        fail(f"Invalid {label}: repeated slashes are not allowed.")
    if "/./" in value or value.endswith("/.") or "/../" in value or value.endswith("/.."):
        fail(f"Invalid {label}: dot path segments are not allowed.")


def validate_mount_source_path(label, value):
    """Validate mount source path"""
    validate_absolute_path(label, value)
    if ":" in value:
        fail(f"Invalid {label}: ':' is not allowed in Podman bind-mount source paths.")


def ensure_safe_existing_regular_file(label, file_path):
    """Ensure file exists, is regular file, and not a symlink"""
    validate_absolute_path(label, file_path)
    if not os.path.exists(file_path):
        fail(f"Missing {label}: {file_path}")
    if os.path.islink(file_path):
        fail(f"Unsafe {label}: symlinks are not allowed ({file_path})")
    if not os.path.isfile(file_path):
        fail(f"Unsafe {label}: expected a regular file ({file_path})")


def ensure_safe_existing_dir(label, dir_path):
    """Ensure directory exists and is not a symlink"""
    validate_absolute_path(label, dir_path)
    if not os.path.isdir(dir_path):
        fail(f"Missing {label}: {dir_path}")
    if os.path.islink(dir_path):
        fail(f"Unsafe {label}: symlinks are not allowed ({dir_path})")


def stat_uid(path):
    """Get UID of file/directory"""
    return os.stat(path).st_uid


def stat_mode(path):
    """Get mode of file/directory"""
    return oct(os.stat(path).st_mode)[-3:]


def ensure_private_existing_dir_owned_by_user(label, dir_path):
    """Ensure directory is owned by current user and has private permissions"""
    ensure_safe_existing_dir(label, dir_path)
    uid = stat_uid(dir_path)
    if uid != os.getuid():
        fail(f"Unsafe {label}: not owned by current user ({dir_path})")
    mode = int(stat_mode(dir_path), 8)
    if mode & 0o022 != 0:
        fail(f"Unsafe {label}: group/other writable ({dir_path})")


def ensure_private_existing_regular_file_owned_by_user(label, file_path):
    """Ensure file is owned by current user and has private permissions"""
    ensure_safe_existing_regular_file(label, file_path)
    uid = stat_uid(file_path)
    if uid != os.getuid():
        fail(f"Unsafe {label}: not owned by current user ({file_path})")
    mode = int(stat_mode(file_path), 8)
    if mode & 0o077 != 0:
        fail(f"Unsafe {label}: expected owner-only permissions ({file_path})")


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


def write_file_atomically(file_path, mode, content):
    """Write file atomically"""
    ensure_safe_write_file_path("output file", file_path)
    dir_path = os.path.dirname(file_path)
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_path, delete=False) as tmp:
        tmp.write(content)
        tmp.flush()
        os.fchmod(tmp.fileno(), int(mode, 8))
        temp_name = tmp.name
    shutil.move(temp_name, file_path)


def load_podman_env_file(file_path):
    """Load environment variables from file"""
    ensure_private_existing_regular_file_owned_by_user("Podman env file", file_path)
    dir_path = os.path.dirname(file_path)
    ensure_private_existing_dir_owned_by_user("Podman env directory", dir_path)
    
    valid_keys = {
        "OPENCLAW_GATEWAY_TOKEN", "OPENCLAW_PODMAN_CONTAINER", "OPENCLAW_PODMAN_IMAGE",
        "OPENCLAW_IMAGE", "OPENCLAW_PODMAN_PULL", "OPENCLAW_PODMAN_GATEWAY_HOST_PORT",
        "OPENCLAW_GATEWAY_PORT", "OPENCLAW_PODMAN_BRIDGE_HOST_PORT", "OPENCLAW_BRIDGE_PORT",
        "OPENCLAW_GATEWAY_BIND", "OPENCLAW_PODMAN_USERNS", "OPENCLAW_BIND_MOUNT_OPTIONS",
        "OPENCLAW_PODMAN_PUBLISH_HOST"
    }
    
    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' not in line:
                    continue
                
                key, value = line.split('=', 1)
                key = key.strip()
                
                if not key.replace('_', '').isalnum() or not key[0].isalpha():
                    continue
                    
                if key not in valid_keys:
                    continue
                    
                # Handle quoted values
                if (value.startswith('"') and value.endswith('"')) or \
                   (value.startswith("'") and value.endswith("'")):
                    value = value[1:-1]
                    
                os.environ[key] = value
    except Exception as e:
        fail(f"Unable to open Podman env file: {file_path} - {str(e)}")


def validate_port(label, value):
    """Validate port number"""
    try:
        numeric = int(value)
        if not (1 <= numeric <= 65535):
            fail(f"Invalid {label}: out of range.")
    except ValueError:
        fail(f"Invalid {label}: must be numeric.")


def which(command):
    """Check if command exists in PATH"""
    return shutil.which(command) is not None


def resolve_config_gateway_bind(config_dir):
    """Resolve gateway bind configuration"""
    if not which("openclaw"):
        return ""
    
    try:
        result = subprocess.run([
            "openclaw", "config", "get", "gateway.bind"
        ], env={**os.environ, "OPENCLAW_CONTAINER": "", "OPENCLAW_CONFIG_DIR": config_dir},
           capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    
    return ""


def upsert_env_var(file_path, key, value):
    """Insert or update environment variable in file"""
    ensure_safe_write_file_path("env file", file_path)
    dir_path = os.path.dirname(file_path)
    
    lines = []
    found = False
    
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            for line in f:
                if line.startswith(key + '='):
                    lines.append(f"{key}={value}\n")
                    found = True
                else:
                    lines.append(line)
    
    if not found:
        lines.append(f"{key}={value}\n")
    
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_path, delete=False) as tmp:
        tmp.writelines(lines)
        temp_name = tmp.name
    
    shutil.move(temp_name, file_path)
    try:
        os.chmod(file_path, 0o600)
    except Exception:
        pass


def generate_token_hex_32():
    """Generate 32-byte hex token"""
    if which("openssl"):
        try:
            result = subprocess.run(["openssl", "rand", "-hex", "32"], 
                                  capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except Exception:
            pass
    
    try:
        return secrets.token_hex(32)
    except Exception:
        pass
    
    if which("od"):
        try:
            result = subprocess.run(["od", "-An", "-N32", "-tx1", "/dev/urandom"], 
                                  capture_output=True, text=True, check=True)
            return ''.join(result.stdout.strip().split())
        except Exception:
            pass
    
    fail("Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.")


def create_token_env_file(file_path, token):
    """Create temporary token environment file"""
    dir_path = os.path.dirname(file_path)
    ensure_private_existing_dir_owned_by_user("token env directory", dir_path)
    
    fd, tmp_path = tempfile.mkstemp(prefix=".token.env.", suffix="", dir=dir_path)
    try:
        os.close(fd)
        with open(tmp_path, 'w') as f:
            f.write(f'OPENCLAW_GATEWAY_TOKEN={token}\n')
        os.chmod(tmp_path, 0o600)
        return tmp_path
    except Exception:
        os.unlink(tmp_path)
        raise


def sync_local_control_ui_origins_via_cli(file_path, port):
    """Sync control UI origins via CLI"""
    if not which("openclaw"):
        print("Warning: openclaw not found; unable to sync gateway.controlUi.allowedOrigins in {}.".format(file_path), file=sys.stderr)
        return
    
    config_dir = os.path.dirname(file_path)
    
    if not which("python3"):
        subprocess.run([
            "openclaw", "config", "set", "gateway.controlUi.allowedOrigins",
            f'[\"http://127.0.0.1:{port}\",\"http://localhost:{port}\"]'
        ], env={**os.environ, "OPENCLAW_CONTAINER": "", "OPENCLAW_CONFIG_DIR": config_dir},
           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    
    try:
        result = subprocess.run([
            "openclaw", "config", "get", "gateway.controlUi.allowedOrigins", "--json"
        ], env={**os.environ, "OPENCLAW_CONTAINER": "", "OPENCLAW_CONFIG_DIR": config_dir},
               capture_output=True, text=True)
        
        allowed_json = result.stdout.strip() if result.returncode == 0 else ""
        
        # Process with Python
        import json
        desired = [f"http://127.0.0.1:{port}", f"http://localhost:{port}"]
        allowed = []
        
        if allowed_json:
            try:
                parsed = json.loads(allowed_json)
                if isinstance(parsed, list):
                    allowed = parsed
            except json.JSONDecodeError:
                allowed = []
        
        cleaned = []
        seen = set()
        
        for origin in allowed + desired:
            if not isinstance(origin, str):
                continue
            normalized = origin.strip()
            if not normalized or normalized in seen:
                continue
            cleaned.append(normalized)
            seen.add(normalized)
        
        subprocess.run([
            "openclaw", "config", "set", "gateway.controlUi.allowedOrigins", json.dumps(cleaned)
        ], env={**os.environ, "OPENCLAW_CONTAINER": "", "OPENCLAW_CONFIG_DIR": config_dir},
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
    except Exception as e:
        print(f"Error syncing control UI origins: {e}", file=sys.stderr)


def sync_local_control_ui_origins(file_path, port):
    """Sync control UI origins in config file"""
    ensure_safe_write_file_path("config file", file_path)
    
    if not which("python3"):
        print("Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in {}.".format(file_path), file=sys.stderr)
        return
    
    dir_path = os.path.dirname(file_path)
    ensure_private_existing_dir_owned_by_user("config file directory", dir_path)
    
    fd, tmp_path = tempfile.mkstemp(prefix=".config.tmp.", suffix="", dir=dir_path)
    os.close(fd)
    
    try:
        with open(file_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        
        if not isinstance(data, dict):
            raise SystemExit(f"{file_path}: expected top-level object")
            
        gateway = data.setdefault("gateway", {})
        if not isinstance(gateway, dict):
            raise SystemExit(f"{file_path}: expected gateway object")
            
        gateway.setdefault("mode", "local")
        control_ui = gateway.setdefault("controlUi", {})
        if not isinstance(control_ui, dict):
            raise SystemExit(f"{file_path}: expected gateway.controlUi object")
            
        allowed = control_ui.get("allowedOrigins")
        desired = [f"http://127.0.0.1:{port}", f"http://localhost:{port}"]
        
        if not isinstance(allowed, list):
            allowed = []
            
        cleaned = []
        seen = set()
        
        for origin in allowed:
            if not isinstance(origin, str):
                continue
            normalized = origin.strip()
            if not normalized or normalized in seen:
                continue
            cleaned.append(normalized)
            seen.add(normalized)
            
        for origin in desired:
            if origin not in seen:
                cleaned.append(origin)
                seen.add(origin)
                
        control_ui["allowedOrigins"] = cleaned
        
        with open(tmp_path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
            
        os.chmod(tmp_path, 0o600)
        shutil.move(tmp_path, file_path)
        
    except json.JSONDecodeError as exc:
        os.unlink(tmp_path)
        print(f"Warning: unable to sync gateway.controlUi.allowedOrigins in {file_path}: existing config is not strict JSON ({exc}). Leaving file unchanged.", file=sys.stderr)
        sync_local_control_ui_origins_via_cli(file_path, port)
    except Exception as e:
        os.unlink(tmp_path)
        sync_local_control_ui_origins_via_cli(file_path, port)


def main():
    """Main function"""
    platform_name = os.uname().sysname if hasattr(os, 'uname') else 'unknown'
    
    effective_user = os.getlogin() if hasattr(os, 'getlogin') else os.getenv('USER', '')
    effective_home = os.getenv('HOME', '')
    
    if not effective_home:
        effective_home = resolve_user_home(effective_user)
    
    if os.getuid() == 0:
        fail("Run run-openclaw-podman.sh as your normal user so Podman stays rootless.")
    
    args = sys.argv[1:]
    
    # Legacy: setup-host -> run the Podman setup script
    if args and args[0] == "setup-host":
        args = args[1:]
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        setup_podman = os.path.join(repo_root, "scripts", "podman", "setup.sh")
        
        if os.path.exists(setup_podman):
            os.execv(setup_podman, [setup_podman] + args)
            
        setup_podman = os.path.join(repo_root, "setup-podman.sh")
        if os.path.exists(setup_podman):
            os.execv(setup_podman, [setup_podman] + args)
            
        print("Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh", file=sys.stderr)
        sys.exit(1)
    
    # Handle launch argument
    if args and args[0] == "launch":
        args = args[1:]
    
    if not effective_home:
        effective_home = "/tmp"
    
    validate_absolute_path("effective home", effective_home)
    
    config_dir = os.getenv("OPENCLAW_CONFIG_DIR", os.path.join(effective_home, ".openclaw"))
    env_file = os.getenv("OPENCLAW_PODMAN_ENV", os.path.join(config_dir, ".env"))
    
    # Bootstrap `.env` may set runtime/container options
    if os.path.exists(env_file):
        load_podman_env_file(env_file)
    
    # Re-read after potential env file loading
    config_dir = os.getenv("OPENCLAW_CONFIG_DIR", os.path.join(effective_home, ".openclaw"))
    env_file = os.getenv("OPENCLAW_PODMAN_ENV", os.path.join(config_dir, ".env"))
    workspace_dir = os.getenv("OPENCLAW_WORKSPACE_DIR", os.path.join(config_dir, "workspace"))
    container_name = os.getenv("OPENCLAW_PODMAN_CONTAINER", "openclaw")
    openclaw_image = os.getenv("OPENCLAW_PODMAN_IMAGE", os.getenv("OPENCLAW_IMAGE", "openclaw:local"))
    podman_pull = os.getenv("OPENCLAW_PODMAN_PULL", "never")
    host_gateway_port = os.getenv("OPENCLAW_PODMAN_GATEWAY_HOST_PORT", os.getenv("OPENCLAW_GATEWAY_PORT", "18789"))
    host_bridge_port = os.getenv("OPENCLAW_PODMAN_BRIDGE_HOST_PORT", os.getenv("OPENCLAW_BRIDGE_PORT", "18790"))
    publish_host = os.getenv("OPENCLAW_PODMAN_PUBLISH_HOST", "127.0.0.1")
    
    validate_mount_source_path("config directory", config_dir)
    validate_mount_source_path("workspace directory", workspace_dir)
    validate_absolute_path("env file path", env_file)
    validate_single_line_value("container name", container_name)
    validate_single_line_value("image name", openclaw_image)
    validate_single_line_value("publish host", publish_host)
    validate_port("gateway host port", host_gateway_port)
    validate_port("bridge host port", host_bridge_port)
    
    try:
        os.chdir(effective_home)
    except Exception:
        try:
            os.chdir("/tmp")
        except Exception:
            pass
    
    run_setup = False
    if args and args[0] in ["setup", "onboard"]:
        run_setup = True
        args = args[1:]
    
    # Create directories
    os.makedirs(config_dir, mode=0o700, exist_ok=True)
    os.makedirs(workspace_dir, mode=0o700, exist_ok=True)
    os.makedirs(os.path.join(config_dir, "canvas"), mode=0o700, exist_ok=True)
    os.makedirs(os.path.join(config_dir, "cron"), mode=0o700, exist_ok=True)
    
    os.chmod(config_dir, 0o700)
    os.chmod(workspace_dir, 0o700)
    
    ensure_private_existing_dir_owned_by_user("config directory", config_dir)
    ensure_private_existing_dir_owned_by_user("workspace directory", workspace_dir)
    
    # Resolve gateway bind
    config_gateway_bind = resolve_config_gateway_bind(config_dir)
    gateway_bind = os.getenv("OPENCLAW_GATEWAY_BIND", config_gateway_bind or "lan")
    
    # Handle token generation
    token_env_file = None
    
    def cleanup_token_env_file():
        nonlocal token_env_file
        if token_env_file and os.path.exists(token_env_file):
            try:
                os.unlink(token_env_file)
            except Exception:
                pass
    
    import atexit
    atexit.register(cleanup_token_env_file)
    
    if not os.getenv("OPENCLAW_GATEWAY_TOKEN"):
        openclaw_gateway_token = generate_token_hex_32()
        os.environ["OPENCLAW_GATEWAY_TOKEN"] = openclaw_gateway_token
        os.makedirs(os.path.dirname(env_file), mode=0o700, exist_ok=True)
        ensure_safe_existing_dir("env file directory", os.path.dirname(env_file))
        upsert_env_var(env_file, "OPENCLAW_GATEWAY_TOKEN", openclaw_gateway_token)
        print("Generated OPENCLAW_GATEWAY_TOKEN and wrote it to {}.".format(env_file), file=sys.stderr)
    else:
        openclaw_gateway_token = os.getenv("OPENCLAW_GATEWAY_TOKEN")
    
    config_json = os.path.join(config_dir, "openclaw.json")
    if not os.path.exists(config_json):
        content = '{ "gateway": { "mode": "local" } }\n'
        write_file_atomically(config_json, "600", content)
        print("Created {} (minimal gateway.mode=local).".format(config_json), file=sys.stderr)
    
    sync_local_control_ui_origins(config_json, host_gateway_port)
    
    podman_userns = os.getenv("OPENCLAW_PODMAN_USERNS", "keep-id")
    userns_args = []
    run_user_args = []
    
    if podman_userns == "keep-id":
        userns_args = ["--userns=keep-id"]
    elif podman_userns == "host":
        userns_args = ["--userns=host"]
    elif podman_userns not in ["", "auto"]:
        fail("Unsupported OPENCLAW_PODMAN_USERNS={} (expected: keep-id, auto, host).".format(podman_userns))
    
    run_uid = str(os.getuid())
    run_gid = str(os.getgid())
    
    if podman_userns == "keep-id":
        run_user_args = ["--user", "{}:{}".format(run_uid, run_gid)]
    else:
        print("Starting container without --user (OPENCLAW_PODMAN_USERNS={}), mounts may require ownership fixes.".format(podman_userns), file=sys.stderr)
    
    selinux_mount_opts = ""
    if not os.getenv("OPENCLAW_BIND_MOUNT_OPTIONS"):
        if platform_name == "Linux" and which("getenforce"):
            try:
                result = subprocess.run(["getenforce"], capture_output=True, text=True)
                selinux_mode = result.stdout.strip()
                if selinux_mode in ["Enforcing", "Permissive"]:
                    selinux_mount_opts = ",Z"
            except Exception:
                pass
    else:
        selinux_mount_opts = os.getenv("OPENCLAW_BIND_MOUNT_OPTIONS")
        if selinux_mount_opts.startswith(":"):
            selinux_mount_opts = selinux_mount_opts[1:]
        if selinux_mount_opts:
            selinux_mount_opts = "," + selinux_mount_opts
    
    # Create token env file
    token_env_file = create_token_env_file(env_file, openclaw_gateway_token)
    
    # Build podman command
    podman_cmd = ["podman", "run"]
    
    if run_setup:
        podman_cmd.extend(["--pull=" + podman_pull, "--rm", "-it"])
    else:
        podman_cmd.extend(["--pull=" + podman_pull, "-d", "--replace", "--name", container_name])
    
    podman_cmd.extend(["--init"])
    podman_cmd.extend(userns_args)
    podman_cmd.extend(run_user_args)
    
    podman_cmd.extend([
        "-e", "HOME=/home/node",
        "-e", "TERM=xterm-256color",
        "-e", "BROWSER=echo",
        "-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
        "-e", "OPENCLAW_NO_RESPAWN=1",
        "--env-file", token_env_file,
        "-v", "{}:/home/node/.openclaw:rw{}".format(config_dir, selinux_mount_opts),
        "-v", "{}:/home/node/.openclaw/workspace:rw{}".format(workspace_dir, selinux_mount_opts)
    ])
    
    if not run_setup:
        podman_cmd.extend([
            "-p", "{}:{}:18789".format(publish_host, host_gateway_port),
            "-p", "{}:{}:18790".format(publish_host, host_bridge_port)
        ])
    
    podman_cmd.append(openclaw_image)
    
    if run_setup:
        podman_cmd.extend(["node", "dist/index.js", "onboard"] + args)
        os.execvp("podman", podman_cmd)
    else:
        podman_cmd.extend(["node", "dist/index.js", "gateway", "--bind", gateway_bind, "--port", "18789"])
        
        try:
            subprocess.run(podman_cmd, check=True, stdout=subprocess.DEVNULL)
            print("Container {} started: http://127.0.0.1:{}/".format(container_name, host_gateway_port))
            print("podman exec -it {} openclaw dashboard --no-open".format(container_name))
            print("podman exec -it {} openclaw devices approve --latest  # if pairing required".format(container_name))
            print("podman logs -f {}".format(container_name))
            if platform_name == "Linux":
                print("For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service).")
        except subprocess.CalledProcessError as e:
            fail("Failed to start container: {}".format(e))


if __name__ == "__main__":
    main()
