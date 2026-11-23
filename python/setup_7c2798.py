#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f36739f8499403d4dc907d230dfcd8b44fc5d4f9a66b45e3f4882e1573a79f45", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "python"}
# setup.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import json
import secrets
import re
from pathlib import Path

def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)

def require_cmd(cmd):
    if not shutil.which(cmd):
        print(f"Missing dependency: {cmd}", file=sys.stderr)
        sys.exit(1)

def run_docker_build(*args):
    env = os.environ.copy()
    env['DOCKER_BUILDKIT'] = '1'
    result = subprocess.run(['docker', 'build'] + list(args), env=env)
    if result.returncode != 0:
        sys.exit(result.returncode)

def is_truthy_value(raw):
    if not raw:
        return False
    raw_lower = raw.lower()
    return raw_lower in ['1', 'true', 'yes', 'on']

def read_config_gateway_token():
    config_path = os.environ.get('OPENCLAW_CONFIG_DIR', '') + '/openclaw.json'
    if not os.path.isfile(config_path):
        return ''
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            cfg = json.load(f)
    except Exception:
        return ''
    
    gateway = cfg.get('gateway')
    if not isinstance(gateway, dict):
        return ''
    auth = gateway.get('auth')
    if not isinstance(auth, dict):
        return ''
    token = auth.get('token')
    if isinstance(token, str):
        token = token.strip()
        if token:
            return token
    return ''

def read_env_gateway_token(env_path):
    if not os.path.isfile(env_path):
        return ''
    
    with open(env_path, 'r') as f:
        for line in f:
            line = line.rstrip('\r\n')
            if line.startswith('OPENCLAW_GATEWAY_TOKEN='):
                return line[len('OPENCLAW_GATEWAY_TOKEN='):]
    return ''

def sync_gateway_config(run_prestart_cli):
    allowed_origin_json = ''
    current_allowed_origins = ''
    
    if os.environ.get('OPENCLAW_GATEWAY_BIND') != 'loopback':
        port = os.environ.get('OPENCLAW_GATEWAY_PORT')
        allowed_origin_json = f'["http://localhost:{port}","http://127.0.0.1:{port}"]'
        try:
            result = run_prestart_cli('config', 'get', 'gateway.controlUi.allowedOrigins', capture_output=True, text=True)
            if result.returncode == 0:
                current_allowed_origins = result.stdout.strip().replace('\r', '')
        except Exception:
            pass
    
    batch_items = [
        {"path": "gateway.mode", "value": "local"},
        {"path": "gateway.bind", "value": os.environ.get('OPENCLAW_GATEWAY_BIND')}
    ]
    
    if allowed_origin_json:
        if not current_allowed_origins or current_allowed_origins in ('null', '[]'):
            batch_items.append({
                "path": "gateway.controlUi.allowedOrigins",
                "value": json.loads(allowed_origin_json)
            })
        else:
            print("Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged.")
    
    batch_json = json.dumps(batch_items)
    
    result = run_prestart_cli('config', 'set', '--batch-json', batch_json, capture_output=True)
    if result.returncode != 0:
        fail("Failed to configure gateway settings")
    
    print(f"Pinned gateway.mode=local and gateway.bind={os.environ.get('OPENCLAW_GATEWAY_BIND')} for Docker setup.")
    if allowed_origin_json and (not current_allowed_origins or current_allowed_origins in ('null', '[]')):
        print(f"Set gateway.controlUi.allowedOrigins to {allowed_origin_json} for non-loopback bind.")

def run_prestart_gateway(compose_args, *args):
    cmd = ['docker', 'compose'] + compose_args + ['run', '--rm', '--no-deps'] + list(args)
    return subprocess.run(cmd)

def run_prestart_cli(compose_args, *args):
    # During setup, avoid the shared-network openclaw-cli service because it
    # requires the gateway container's network namespace to already exist. That
    # creates a circular dependency for config writes that are needed before the
    # gateway can start cleanly.
    cmd = ['docker', 'compose'] + compose_args + [
        'run', '--rm', '--no-deps', '--entrypoint', 'node', 
        'openclaw-gateway', 'dist/index.js'
    ] + list(args)
    return subprocess.run(cmd)

def run_runtime_cli(compose_args_base, compose_scope, deps_mode, *args):
    compose_args = []
    if compose_scope == 'base':
        compose_args = compose_args_base.copy()
    elif compose_scope == 'current':
        compose_args = compose_args_base.copy()
    else:
        fail(f"Unknown runtime CLI compose scope: {compose_scope}")
    
    run_args = ['run', '--rm']
    if deps_mode == 'no-deps':
        run_args.append('--no-deps')
    elif deps_mode != 'with-deps':
        fail(f"Unknown runtime CLI deps mode: {deps_mode}")
    
    cmd = ['docker', 'compose'] + compose_args + run_args + ['openclaw-cli'] + list(args)
    return subprocess.run(cmd)

def contains_disallowed_chars(value):
    return '\n' in value or '\r' in value or '\t' in value

def is_valid_timezone(value):
    zone_path = Path('/usr/share/zoneinfo') / value
    return zone_path.exists() and not zone_path.is_dir()

def validate_mount_path_value(label, value):
    if not value:
        fail(f"{label} cannot be empty.")
    if contains_disallowed_chars(value):
        fail(f"{label} contains unsupported control characters.")
    if ' ' in value:
        fail(f"{label} cannot contain whitespace.")

def validate_named_volume(value):
    if not re.match(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$', value):
        fail("OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume.")

def validate_mount_spec(mount):
    if contains_disallowed_chars(mount):
        fail("OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters.")
    # Keep mount specs strict to avoid YAML structure injection.
    # Expected format: source:target[:options]
    if not re.match(r'^[^ ,:]+:[^ ,:]+(:[^ ,:]+)?$', mount):
        fail(f"Invalid mount format '{mount}'. Expected source:target[:options] without spaces.")

def write_extra_compose(extra_compose_file, home_volume, *mounts):
    content = '''services:
  openclaw-gateway:
    volumes:
'''
    
    if home_volume:
        gateway_home_mount = f"{home_volume}:/home/node"
        gateway_config_mount = f"{os.environ['OPENCLAW_CONFIG_DIR']}:/home/node/.openclaw"
        gateway_workspace_mount = f"{os.environ['OPENCLAW_WORKSPACE_DIR']}:/home/node/.openclaw/workspace"
        validate_mount_spec(gateway_home_mount)
        validate_mount_spec(gateway_config_mount)
        validate_mount_spec(gateway_workspace_mount)
        content += f'''      - {gateway_home_mount}
      - {gateway_config_mount}
      - {gateway_workspace_mount}
'''
    
    for mount in mounts:
        validate_mount_spec(mount)
        content += f'      - {mount}\n'
    
    content += '''  openclaw-cli:
    volumes:
'''
    
    if home_volume:
        content += f'''      - {gateway_home_mount}
      - {gateway_config_mount}
      - {gateway_workspace_mount}
'''
    
    for mount in mounts:
        validate_mount_spec(mount)
        content += f'      - {mount}\n'
    
    if home_volume and '/' not in home_volume:
        validate_named_volume(home_volume)
        content += f'''volumes:
  {home_volume}:
'''
    
    with open(extra_compose_file, 'w') as f:
        f.write(content)

def upsert_env(file, keys):
    seen = set()
    lines = []
    
    if os.path.isfile(file):
        with open(file, 'r') as f:
            for line in f:
                line = line.rstrip('\n\r')
                if '=' in line:
                    key = line.split('=', 1)[0]
                    if key in keys:
                        lines.append(f"{key}={os.environ.get(key, '')}")
                        seen.add(key)
                        continue
                lines.append(line)
    
    for key in keys:
        if key not in seen:
            lines.append(f"{key}={os.environ.get(key, '')}")
    
    with open(file, 'w') as f:
        for line in lines:
            f.write(line + '\n')

def main():
    import shutil
    
    # Set working directory to script's parent directory
    script_dir = Path(__file__).parent.resolve()
    root_dir = script_dir.parent.parent
    os.chdir(root_dir)
    
    compose_file = str(root_dir / 'docker-compose.yml')
    extra_compose_file = str(root_dir / 'docker-compose.extra.yml')
    
    image_name = os.environ.get('OPENCLAW_IMAGE', 'openclaw:local')
    extra_mounts_raw = os.environ.get('OPENCLAW_EXTRA_MOUNTS', '')
    home_volume_name = os.environ.get('OPENCLAW_HOME_VOLUME', '')
    raw_sandbox_setting = os.environ.get('OPENCLAW_SANDBOX', '')
    sandbox_enabled = ''
    docker_socket_path = os.environ.get('OPENCLAW_DOCKER_SOCKET', '')
    timezone = os.environ.get('OPENCLAW_TZ', '')
    
    require_cmd('docker')
    try:
        subprocess.run(['docker', 'compose', 'version'], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        print("Docker Compose not available (try: docker compose version)", file=sys.stderr)
        sys.exit(1)
    
    if not docker_socket_path and os.environ.get('DOCKER_HOST', '').startswith('unix://'):
        docker_socket_path = os.environ['DOCKER_HOST'][len('unix://'):]
    
    if not docker_socket_path:
        docker_socket_path = '/var/run/docker.sock'
    
    if is_truthy_value(raw_sandbox_setting):
        sandbox_enabled = '1'
    
    openclaw_config_dir = os.environ.get('OPENCLAW_CONFIG_DIR', str(Path.home() / '.openclaw'))
    openclaw_workspace_dir = os.environ.get('OPENCLAW_WORKSPACE_DIR', str(Path.home() / '.openclaw/workspace'))
    
    validate_mount_path_value('OPENCLAW_CONFIG_DIR', openclaw_config_dir)
    validate_mount_path_value('OPENCLAW_WORKSPACE_DIR', openclaw_workspace_dir)
    
    if home_volume_name:
        if '/' in home_volume_name:
            validate_mount_path_value('OPENCLAW_HOME_VOLUME', home_volume_name)
        else:
            validate_named_volume(home_volume_name)
    
    if contains_disallowed_chars(extra_mounts_raw):
        fail('OPENCLAW_EXTRA_MOUNTS cannot contain control characters.')
    
    if sandbox_enabled:
        validate_mount_path_value('OPENCLAW_DOCKER_SOCKET', docker_socket_path)
    
    if timezone:
        if contains_disallowed_chars(timezone):
            fail('OPENCLAW_TZ contains unsupported control characters.')
        if not re.match(r'^[A-Za-z0-9/_+\-]+$', timezone):
            fail('OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai).')
        if not is_valid_timezone(timezone):
            fail('OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai).')
    
    os.makedirs(openclaw_config_dir, exist_ok=True)
    os.makedirs(openclaw_workspace_dir, exist_ok=True)
    os.makedirs(os.path.join(openclaw_config_dir, 'identity'), exist_ok=True)
    os.makedirs(os.path.join(openclaw_config_dir, 'agents/main/agent'), exist_ok=True)
    os.makedirs(os.path.join(openclaw_config_dir, 'agents/main/sessions'), exist_ok=True)
    
    # Export environment variables
    os.environ['OPENCLAW_CONFIG_DIR'] = openclaw_config_dir
    os.environ['OPENCLAW_WORKSPACE_DIR'] = openclaw_workspace_dir
    os.environ['OPENCLAW_GATEWAY_PORT'] = os.environ.get('OPENCLAW_GATEWAY_PORT', '18789')
    os.environ['OPENCLAW_BRIDGE_PORT'] = os.environ.get('OPENCLAW_BRIDGE_PORT', '18790')
    os.environ['OPENCLAW_GATEWAY_BIND'] = os.environ.get('OPENCLAW_GATEWAY_BIND', 'lan')
    os.environ['OPENCLAW_IMAGE'] = image_name
    os.environ['OPENCLAW_DOCKER_APT_PACKAGES'] = os.environ.get('OPENCLAW_DOCKER_APT_PACKAGES', '')
    os.environ['OPENCLAW_EXTENSIONS'] = os.environ.get('OPENCLAW_EXTENSIONS', '')
    os.environ['OPENCLAW_EXTRA_MOUNTS'] = extra_mounts_raw
    os.environ['OPENCLAW_HOME_VOLUME'] = home_volume_name
    os.environ['OPENCLAW_ALLOW_INSECURE_PRIVATE_WS'] = os.environ.get('OPENCLAW_ALLOW_INSECURE_PRIVATE_WS', '')
    os.environ['OPENCLAW_SANDBOX'] = sandbox_enabled
    os.environ['OPENCLAW_DOCKER_SOCKET'] = docker_socket_path
    os.environ['OPENCLAW_TZ'] = timezone
    
    # Detect Docker socket GID for sandbox group_add
    docker_gid = ''
    if sandbox_enabled and os.path.exists(docker_socket_path) and os.path.socket(docker_socket_path):
        try:
            docker_gid = str(os.stat(docker_socket_path).st_gid)
        except Exception:
            pass
    os.environ['DOCKER_GID'] = docker_gid
    
    if not os.environ.get('OPENCLAW_GATEWAY_TOKEN'):
        existing_config_token = read_config_gateway_token()
        if existing_config_token:
            os.environ['OPENCLAW_GATEWAY_TOKEN'] = existing_config_token
            print(f"Reusing gateway token from {openclaw_config_dir}/openclaw.json")
        else:
            dotenv_gateway_token = read_env_gateway_token(str(root_dir / '.env'))
            if dotenv_gateway_token:
                os.environ['OPENCLAW_GATEWAY_TOKEN'] = dotenv_gateway_token
                print(f"Reusing gateway token from {root_dir}/.env")
            elif shutil.which('openssl'):
                result = subprocess.run(['openssl', 'rand', '-hex', '32'], capture_output=True, text=True)
                os.environ['OPENCLAW_GATEWAY_TOKEN'] = result.stdout.strip()
            else:
                os.environ['OPENCLAW_GATEWAY_TOKEN'] = secrets.token_hex(32)
    
    compose_files = [compose_file]
    compose_args = []
    
    # Process extra mounts
    valid_mounts = []
    if extra_mounts_raw:
        mounts = [m.strip() for m in extra_mounts_raw.split(',')]
        valid_mounts = [m for m in mounts if m]
    
    if home_volume_name or valid_mounts:
        write_extra_compose(extra_compose_file, home_volume_name, *valid_mounts)
        compose_files.append(extra_compose_file)
    
    for compose_file_path in compose_files:
        compose_args.extend(['-f', compose_file_path])
    
    base_compose_args = compose_args.copy()
    compose_hint = 'docker compose ' + ' '.join(compose_args)
    
    env_file = str(root_dir / '.env')
    
    upsert_env(env_file, [
        'OPENCLAW_CONFIG_DIR',
        'OPENCLAW_WORKSPACE_DIR',
        'OPENCLAW_GATEWAY_PORT',
        'OPENCLAW_BRIDGE_PORT',
        'OPENCLAW_GATEWAY_BIND',
        'OPENCLAW_GATEWAY_TOKEN',
        'OPENCLAW_IMAGE',
        'OPENCLAW_EXTRA_MOUNTS',
        'OPENCLAW_HOME_VOLUME',
        'OPENCLAW_DOCKER_APT_PACKAGES',
        'OPENCLAW_EXTENSIONS',
        'OPENCLAW_SANDBOX',
        'OPENCLAW_DOCKER_SOCKET',
        'DOCKER_GID',
        'OPENCLAW_INSTALL_DOCKER_CLI',
        'OPENCLAW_ALLOW_INSECURE_PRIVATE_WS',
        'OPENCLAW_TZ'
    ])
    
    if image_name == 'openclaw:local':
        print(f"==> Building Docker image: {image_name}")
        run_docker_build(
            '--build-arg', f"OPENCLAW_DOCKER_APT_PACKAGES={os.environ['OPENCLAW_DOCKER_APT_PACKAGES']}",
            '--build-arg', f"OPENCLAW_EXTENSIONS={os.environ['OPENCLAW_EXTENSIONS']}",
            '--build-arg', f"OPENCLAW_INSTALL_DOCKER_CLI={os.environ.get('OPENCLAW_INSTALL_DOCKER_CLI', '')}",
            '-t', image_name,
            '-f', str(root_dir / 'Dockerfile'),
            str(root_dir)
        )
    else:
        print(f"==> Pulling Docker image: {image_name}")
        try:
            subprocess.run(['docker', 'pull', image_name], check=True)
        except subprocess.CalledProcessError:
            print(f"ERROR: Failed to pull image {image_name}. Please check the image name and your access permissions.", file=sys.stderr)
            sys.exit(1)
    
    # Ensure bind-mounted data directories are writable by the container's `node`
    # user (uid 1000). Host-created dirs inherit the host user's uid which may
    # differ, causing EACCES when the container tries to mkdir/write.
    # Running a brief root container to chown is the portable Docker idiom --
    # it works regardless of the host uid and doesn't require host-side root.
    print("")
    print("==> Fixing data-directory permissions")
    # Use -xdev to restrict chown to the config-dir mount only — without it,
    # the recursive chown would cross into the workspace bind mount and rewrite
    # ownership of all user project files on Linux hosts.
    # After fixing the config dir, only the OpenClaw metadata subdirectory
    # (.openclaw/) inside the workspace gets chowned, not the user's project files.
    run_prestart_gateway(
        base_compose_args,
        '--user', 'root', '--entrypoint', 'sh', 'openclaw-gateway', '-c',
        'find /home/node/.openclaw -xdev -exec chown node:node {} +; '
        '[ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true'
    )
    
    print("")
    print("==> Onboarding (interactive)")
    print("Docker setup pins Gateway mode to local.")
    print("Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan).")
    print(f"Current runtime bind: {os.environ['OPENCLAW_GATEWAY_BIND']}")
    print(f"Gateway token: {os.environ['OPENCLAW_GATEWAY_TOKEN']}")
    print("Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately).")
    print("Install Gateway daemon: No (managed by Docker Compose)")
    print("")
    
    def run_prestart_cli_wrapper(*args):
        return run_prestart_cli(base_compose_args, *args)
    
    run_prestart_cli_wrapper('onboard', '--mode', 'local', '--no-install-daemon')
    
    print("")
    print("==> Docker gateway defaults")
    sync_gateway_config(run_prestart_cli_wrapper)
    
    print("")
    print("==> Provider setup (optional)")
    print("WhatsApp (QR):")
    print(f"  {compose_hint} run --rm openclaw-cli channels login")
    print("Telegram (bot token):")
    print(f"  {compose_hint} run --rm openclaw-cli channels add --channel telegram --token <token>")
    print("Discord (bot token):")
    print(f"  {compose_hint} run --rm openclaw-cli channels add --channel discord --token <token>")
    print("Docs: https://docs.openclaw.ai/channels")
    
    print("")
    print("==> Starting gateway")
    subprocess.run(['docker', 'compose'] + compose_args + ['up', '-d', 'openclaw-gateway'])
    
    # --- Sandbox setup (opt-in via OPENCLAW_SANDBOX=1) ---
    if sandbox_enabled:
        print("")
        print("==> Sandbox setup")
        
        # Build sandbox image if Dockerfile.sandbox exists.
        dockerfile_sandbox = root_dir / 'Dockerfile.sandbox'
        if dockerfile_sandbox.exists():
            print("Building sandbox image: openclaw-sandbox:bookworm-slim")
            run_docker_build(
                '-t', 'openclaw-sandbox:bookworm-slim',
                '-f', str(dockerfile_sandbox),
                str(root_dir)
            )
        else:
            print("WARNING: Dockerfile.sandbox not found in", str(root_dir), file=sys.stderr)
            print("  Sandbox config will be applied but no sandbox image will be built.", file=sys.stderr)
            print("  Agent exec may fail if the configured sandbox image does not exist.", file=sys.stderr)
        
        # Defense-in-depth: verify Docker CLI in the running image before enabling
        # sandbox. This avoids claiming sandbox is enabled when the image cannot
        # launch sandbox containers.
        try:
            result = subprocess.run(
                ['docker', 'compose'] + compose_args + ['run', '--rm', '--entrypoint', 'docker', 'openclaw-gateway', '--version'],
                capture_output=True
            )
            if result.returncode != 0:
                print("WARNING: Docker CLI not found inside the container image.", file=sys.stderr)
                print("  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1", file=sys.stderr)
                print("  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.", file=sys.stderr)
                sandbox_enabled = ''
        except Exception:
            print("WARNING: Docker CLI not found inside the container image.", file=sys.stderr)
            print("  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1", file=sys.stderr)
            print("  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.", file=sys.stderr)
            sandbox_enabled = ''
    
    # Apply sandbox config only if prerequisites are met.
    if sandbox_enabled:
        # Mount Docker socket via a dedicated compose overlay. This overlay is
        # created only after sandbox prerequisites pass, so the socket is never
        # exposed when sandbox cannot actually run.
        if os.path.exists(docker_socket_path) and os.path.socket(docker_socket_path):
            sandbox_compose_file = str(root_dir / 'docker-compose.sandbox.yml')
            content = f'''services:
  openclaw-gateway:
    volumes:
      - {docker_socket_path}:/var/run/docker.sock
'''
            if docker_gid:
                content += f'''    group_add:
      - "{docker_gid}"
'''
            
            with open(sandbox_compose_file, 'w') as f:
                f.write(content)
            
            compose_args.extend(['-f', sandbox_compose_file])
            print("==> Sandbox: added Docker socket mount")
        else:
            print(f"WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at {docker_socket_path}.", file=sys.stderr)
            print("  Sandbox requires Docker socket access. Skipping sandbox setup.", file=sys.stderr)
            sandbox_enabled = ''
    
    if sandbox_enabled:
        # Enable sandbox in OpenClaw config.
        sandbox_config_ok = True
        
        def run_runtime_cli_current_no_deps(*args):
            return run_runtime_cli(base_compose_args, 'current', 'no-deps', *args)
        
        try:
            if run_runtime_cli_current_no_deps('config', 'set', 'agents.defaults.sandbox.mode', 'non-main').returncode != 0:
                print("WARNING: Failed to set agents.defaults.sandbox.mode", file=sys.stderr)
                sandbox_config_ok = False
            
            if run_runtime_cli_current_no_deps('config', 'set', 'agents.defaults.sandbox.scope', 'agent').returncode != 0:
                print("WARNING: Failed to set agents.defaults.sandbox.scope", file=sys.stderr)
                sandbox_config_ok = False
            
            if run_runtime_cli_current_no_deps('config', 'set', 'agents.defaults.sandbox.workspaceAccess', 'none').returncode != 0:
                print("WARNING: Failed to set agents.defaults.sandbox.workspaceAccess", file=sys.stderr)
                sandbox_config_ok = False
        except Exception as e:
            print(f"WARNING: Failed to set sandbox configuration: {e}", file=sys.stderr)
            sandbox_config_ok = False
        
        if sandbox_config_ok:
            print("Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none")
            print("Docs: https://docs.openclaw.ai/gateway/sandboxing")
            # Restart gateway with sandbox compose overlay to pick up socket mount + config.
            subprocess.run(['docker', 'compose'] + compose_args + ['up', '-d', 'openclaw-gateway'])
        else:
            print("WARNING: Sandbox config was partially applied. Check errors above.", file=sys.stderr)
            print("  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy.", file=sys.stderr)
            
            def run_runtime_cli_base_no_deps(*args):
                return run_runtime_cli(base_compose_args, 'base', 'no-deps', *args)
            
            try:
                if run_runtime_cli_base_no_deps('config', 'set', 'agents.defaults.sandbox.mode', 'off').returncode != 0:
                    print("WARNING: Failed to roll back agents.defaults.sandbox.mode to off", file=sys.stderr)
                else:
                    print("Sandbox mode rolled back to off due to partial sandbox config failure.")
            except Exception:
                print("WARNING: Failed to roll back agents.defaults.sandbox.mode to off", file=sys.stderr)
            
            sandbox_compose_file = str(root_dir / 'docker-compose.sandbox.yml')
            if os.path.exists(sandbox_compose_file):
                os.remove(sandbox_compose_file)
            
            # Ensure gateway service definition is reset without sandbox overlay mount.
            subprocess.run(['docker', 'compose'] + base_compose_args + ['up', '-d', '--force-recreate', 'openclaw-gateway'])
    else:
        # Keep reruns deterministic: if sandbox is not active for this run, reset
        # persisted sandbox mode so future execs do not require docker.sock by stale
        # config alone.
        def run_runtime_cli_current_with_deps(*args):
            return run_runtime_cli(base_compose_args, 'current', 'with-deps', *args)
        
        try:
            if run_runtime_cli_current_with_deps('config', 'set', 'agents.defaults.sandbox.mode', 'off').returncode != 0:
                print("WARNING: Failed to reset agents.defaults.sandbox.mode to off", file=sys.stderr)
        except Exception:
            print("WARNING: Failed to reset agents.defaults.sandbox.mode to off", file=sys.stderr)
        
        sandbox_compose_file = str(root_dir / 'docker-compose.sandbox.yml')
        if os.path.exists(sandbox_compose_file):
            os.remove(sandbox_compose_file)
    
    print("")
    print("Gateway running with host port mapping.")
    print("Access from tailnet devices via the host's tailnet IP.")
    print(f"Config: {openclaw_config_dir}")
    print(f"Workspace: {openclaw_workspace_dir}")
    print(f"Token: {os.environ['OPENCLAW_GATEWAY_TOKEN']}")
    print("")
    print("Commands:")
    print(f"  {compose_hint} logs -f openclaw-gateway")
    print(f"  {compose_hint} exec openclaw-gateway node dist/index.js health --token \"{os.environ['OPENCLAW_GATEWAY_TOKEN']}\"")

if __name__ == '__main__':
    main()
