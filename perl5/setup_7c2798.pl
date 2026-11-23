#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "0015fde298b936ce23f0dea208ea2721515a7c147fbf07f403c6c0d717ad63ad", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "perl5"}
# setup.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use POSIX qw(strftime);

my $ROOT_DIR = abs_path(File::Spec->catdir(dirname(__FILE__), '..', '..'));
my $COMPOSE_FILE = File::Spec->catfile($ROOT_DIR, 'docker-compose.yml');
my $EXTRA_COMPOSE_FILE = File::Spec->catfile($ROOT_DIR, 'docker-compose.extra.yml');
my $IMAGE_NAME = $ENV{'OPENCLAW_IMAGE'} // 'openclaw:local';
my $EXTRA_MOUNTS = $ENV{'OPENCLAW_EXTRA_MOUNTS'} // '';
my $HOME_VOLUME_NAME = $ENV{'OPENCLAW_HOME_VOLUME'} // '';
my $RAW_SANDBOX_SETTING = $ENV{'OPENCLAW_SANDBOX'} // '';
my $SANDBOX_ENABLED = '';
my $DOCKER_SOCKET_PATH = $ENV{'OPENCLAW_DOCKER_SOCKET'} // '';
my $TIMEZONE = $ENV{'OPENCLAW_TZ'} // '';

sub fail {
    my ($msg) = @_;
    print STDERR "ERROR: $msg\n";
    exit 1;
}

sub require_cmd {
    my ($cmd) = @_;
    system("command -v $cmd >/dev/null 2>&1") == 0 or fail("Missing dependency: $cmd");
}

sub run_docker_build {
    local %ENV = %ENV;
    $ENV{'DOCKER_BUILDKIT'} = 1;
    system('docker', 'build', @_) == 0 or fail("Docker build failed");
}

sub is_truthy_value {
    my ($raw) = @_;
    $raw //= '';
    $raw = lc($raw);
    return $raw eq '1' || $raw eq 'true' || $raw eq 'yes' || $raw eq 'on';
}

sub read_config_gateway_token {
    my $config_path = $ENV{'OPENCLAW_CONFIG_DIR'} . '/openclaw.json';
    return unless -f $config_path;

    if (system("command -v python3 >/dev/null 2>&1") == 0) {
        my $script = <<'PYTHON';
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
except Exception:
    raise SystemExit(0)

gateway = cfg.get("gateway")
if not isinstance(gateway, dict):
    raise SystemExit(0)
auth = gateway.get("auth")
if not isinstance(auth, dict):
    raise SystemExit(0)
token = auth.get("token")
if isinstance(token, str):
    token = token.strip()
    if token:
        print(token)
PYTHON
        open(my $fh, '-|', "python3 - '$config_path'", $script) or return;
        my $output = <$fh>;
        close($fh);
        chomp($output) if defined $output;
        return $output if $output;
    }

    if (system("command -v node >/dev/null 2>&1") == 0) {
        my $script = <<'NODEJS';
const fs = require("node:fs");
const configPath = process.argv[2];
try {
  const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const token = cfg?.gateway?.auth?.token;
  if (typeof token === "string" && token.trim().length > 0) {
    process.stdout.write(token.trim());
  }
} catch {
  // Keep docker-setup resilient when config parsing fails.
}
NODEJS
        open(my $fh, '-|', "node - '$config_path'", $script) or return;
        my $output = <$fh>;
        close($fh);
        chomp($output) if defined $output;
        return $output if $output;
    }
}

sub read_env_gateway_token {
    my ($env_path) = @_;
    return unless -f $env_path;

    open(my $fh, '<', $env_path) or return;
    while (my $line = <$fh>) {
        chomp($line);
        $line =~ s/\r$//;
        if ($line =~ /^OPENCLAW_GATEWAY_TOKEN=(.*)$/) {
            close($fh);
            return $1;
        }
    }
    close($fh);
    return '';
}

sub sync_gateway_config {
    my $allowed_origin_json = "";
    my $current_allowed_origins = "";

    if ($ENV{'OPENCLAW_GATEWAY_BIND'} ne "loopback") {
        $allowed_origin_json = sprintf('["http://localhost:%s","http://127.0.0.1:%s"]', 
                                       $ENV{'OPENCLAW_GATEWAY_PORT'}, 
                                       $ENV{'OPENCLAW_GATEWAY_PORT'});
        $current_allowed_origins = `run_prestart_cli config get gateway.controlUi.allowedOrigins 2>/dev/null` || '';
        $current_allowed_origins =~ s/\r//g;
    }

    my $batch_json = sprintf('[{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"%s"}', 
                            $ENV{'OPENCLAW_GATEWAY_BIND'});
    
    if ($allowed_origin_json) {
        if ($current_allowed_origins && $current_allowed_origins ne "null" && $current_allowed_origins ne "[]") {
            print "Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged.\n";
        } else {
            $batch_json .= ",{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":$allowed_origin_json}";
        }
    }
    $batch_json .= "]";

    system("run_prestart_cli config set --batch-json '$batch_json' >/dev/null") == 0 
        or fail("Failed to set gateway config");
    print "Pinned gateway.mode=local and gateway.bind=$ENV{'OPENCLAW_GATEWAY_BIND'} for Docker setup.\n";
    
    if ($allowed_origin_json) {
        if (!$current_allowed_origins || $current_allowed_origins eq "null" || $current_allowed_origins eq "[]") {
            print "Set gateway.controlUi.allowedOrigins to $allowed_origin_json for non-loopback bind.\n";
        }
    }
}

sub run_prestart_gateway {
    system('docker', 'compose', @{$ENV{'COMPOSE_ARGS'}}, 'run', '--rm', '--no-deps', @_);
}

sub run_prestart_cli {
    # During setup, avoid the shared-network openclaw-cli service because it
    # requires the gateway container's network namespace to already exist. That
    # creates a circular dependency for config writes that are needed before the
    # gateway can start cleanly.
    run_prestart_gateway('--entrypoint', 'node', 'openclaw-gateway',
                         'dist/index.js', @_);
}

sub run_runtime_cli {
    my ($compose_scope, $deps_mode, @args) = @_;
    $compose_scope //= 'current';
    $deps_mode //= 'with-deps';

    my @compose_args;
    my @run_args = ('run', '--rm');

    if ($compose_scope eq 'current') {
        @compose_args = @{$ENV{'COMPOSE_ARGS'}};
    } elsif ($compose_scope eq 'base') {
        @compose_args = @{$ENV{'BASE_COMPOSE_ARGS'}};
    } else {
        fail("Unknown runtime CLI compose scope: $compose_scope");
    }

    if ($deps_mode eq 'with-deps') {
        # Do nothing
    } elsif ($deps_mode eq 'no-deps') {
        push @run_args, '--no-deps';
    } else {
        fail("Unknown runtime CLI deps mode: $deps_mode");
    }

    system('docker', 'compose', @compose_args, @run_args, 'openclaw-cli', @args) == 0 
        or fail("Runtime CLI failed");
}

sub contains_disallowed_chars {
    my ($value) = @_;
    return $value =~ /[\n\r\t]/;
}

sub is_valid_timezone {
    my ($value) = @_;
    return -e "/usr/share/zoneinfo/$value" && !-d "/usr/share/zoneinfo/$value";
}

sub validate_mount_path_value {
    my ($label, $value) = @_;
    if (!$value) {
        fail("$label cannot be empty.");
    }
    if (contains_disallowed_chars($value)) {
        fail("$label contains unsupported control characters.");
    }
    if ($value =~ /\s/) {
        fail("$label cannot contain whitespace.");
    }
}

sub validate_named_volume {
    my ($value) = @_;
    if ($value !~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/) {
        fail("OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume.");
    }
}

sub validate_mount_spec {
    my ($mount) = @_;
    if (contains_disallowed_chars($mount)) {
        fail("OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters.");
    }
    # Keep mount specs strict to avoid YAML structure injection.
    # Expected format: source:target[:options]
    if ($mount !~ /^[^[:space:],:]+:[^[:space:],:]+(:[^[:space:],:]+)?$/) {
        fail("Invalid mount format '$mount'. Expected source:target[:options] without spaces.");
    }
}

require_cmd('docker');
if (system("docker compose version >/dev/null 2>&1") != 0) {
    print STDERR "Docker Compose not available (try: docker compose version)\n";
    exit 1;
}

if (!$DOCKER_SOCKET_PATH && ($ENV{'DOCKER_HOST'} // '') =~ /^unix:\/\/(.*)/) {
    $DOCKER_SOCKET_PATH = $1;
}
if (!$DOCKER_SOCKET_PATH) {
    $DOCKER_SOCKET_PATH = "/var/run/docker.sock";
}
if (is_truthy_value($RAW_SANDBOX_SETTING)) {
    $SANDBOX_ENABLED = "1";
}

$ENV{'OPENCLAW_CONFIG_DIR'} = $ENV{'OPENCLAW_CONFIG_DIR'} // ($ENV{'HOME'} . '/.openclaw');
$ENV{'OPENCLAW_WORKSPACE_DIR'} = $ENV{'OPENCLAW_WORKSPACE_DIR'} // ($ENV{'OPENCLAW_CONFIG_DIR'} . '/workspace');

validate_mount_path_value("OPENCLAW_CONFIG_DIR", $ENV{'OPENCLAW_CONFIG_DIR'});
validate_mount_path_value("OPENCLAW_WORKSPACE_DIR", $ENV{'OPENCLAW_WORKSPACE_DIR'});

if ($HOME_VOLUME_NAME) {
    if ($HOME_VOLUME_NAME =~ m|/|) {
        validate_mount_path_value("OPENCLAW_HOME_VOLUME", $HOME_VOLUME_NAME);
    } else {
        validate_named_volume($HOME_VOLUME_NAME);
    }
}

if (contains_disallowed_chars($EXTRA_MOUNTS)) {
    fail("OPENCLAW_EXTRA_MOUNTS cannot contain control characters.");
}

if ($SANDBOX_ENABLED) {
    validate_mount_path_value("OPENCLAW_DOCKER_SOCKET", $DOCKER_SOCKET_PATH);
}

if ($TIMEZONE) {
    if (contains_disallowed_chars($TIMEZONE)) {
        fail("OPENCLAW_TZ contains unsupported control characters.");
    }
    if ($TIMEZONE !~ /^[A-Za-z0-9\/_+\-]+$/) {
        fail("OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai).");
    }
    if (!is_valid_timezone($TIMEZONE)) {
        fail("OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai).");
    }
}

make_path($ENV{'OPENCLAW_CONFIG_DIR'});
make_path($ENV{'OPENCLAW_WORKSPACE_DIR'});
# Seed directory tree eagerly so bind mounts work even on Docker Desktop/Windows
# where the container (even as root) cannot create new host subdirectories.
make_path($ENV{'OPENCLAW_CONFIG_DIR'} . '/identity');
make_path($ENV{'OPENCLAW_CONFIG_DIR'} . '/agents/main/agent');
make_path($ENV{'OPENCLAW_CONFIG_DIR'} . '/agents/main/sessions');

$ENV{'OPENCLAW_GATEWAY_PORT'} = $ENV{'OPENCLAW_GATEWAY_PORT'} // '18789';
$ENV{'OPENCLAW_BRIDGE_PORT'} = $ENV{'OPENCLAW_BRIDGE_PORT'} // '18790';
$ENV{'OPENCLAW_GATEWAY_BIND'} = $ENV{'OPENCLAW_GATEWAY_BIND'} // 'lan';
$ENV{'OPENCLAW_IMAGE'} = $IMAGE_NAME;
$ENV{'OPENCLAW_DOCKER_APT_PACKAGES'} = $ENV{'OPENCLAW_DOCKER_APT_PACKAGES'} // '';
$ENV{'OPENCLAW_EXTENSIONS'} = $ENV{'OPENCLAW_EXTENSIONS'} // '';
$ENV{'OPENCLAW_EXTRA_MOUNTS'} = $EXTRA_MOUNTS;
$ENV{'OPENCLAW_HOME_VOLUME'} = $HOME_VOLUME_NAME;
$ENV{'OPENCLAW_ALLOW_INSECURE_PRIVATE_WS'} = $ENV{'OPENCLAW_ALLOW_INSECURE_PRIVATE_WS'} // '';
$ENV{'OPENCLAW_SANDBOX'} = $SANDBOX_ENABLED;
$ENV{'OPENCLAW_DOCKER_SOCKET'} = $DOCKER_SOCKET_PATH;
$ENV{'OPENCLAW_TZ'} = $TIMEZONE;

# Detect Docker socket GID for sandbox group_add.
my $DOCKER_GID = "";
if ($SANDBOX_ENABLED && -S $DOCKER_SOCKET_PATH) {
    my $stat_output = `stat -c '%g' "$DOCKER_SOCKET_PATH" 2>/dev/null || stat -f '%g' "$DOCKER_SOCKET_PATH" 2>/dev/null || echo ""`;
    chomp($stat_output);
    $DOCKER_GID = $stat_output if $stat_output;
}
$ENV{'DOCKER_GID'} = $DOCKER_GID;

if (!defined $ENV{'OPENCLAW_GATEWAY_TOKEN'}) {
    my $EXISTING_CONFIG_TOKEN = read_config_gateway_token() // '';
    if ($EXISTING_CONFIG_TOKEN) {
        $ENV{'OPENCLAW_GATEWAY_TOKEN'} = $EXISTING_CONFIG_TOKEN;
        print "Reusing gateway token from $ENV{'OPENCLAW_CONFIG_DIR'}/openclaw.json\n";
    } else {
        my $DOTENV_GATEWAY_TOKEN = read_env_gateway_token("$ROOT_DIR/.env") // '';
        if ($DOTENV_GATEWAY_TOKEN) {
            $ENV{'OPENCLAW_GATEWAY_TOKEN'} = $DOTENV_GATEWAY_TOKEN;
            print "Reusing gateway token from $ROOT_DIR/.env\n";
        } elsif (system("command -v openssl >/dev/null 2>&1") == 0) {
            $ENV{'OPENCLAW_GATEWAY_TOKEN'} = `openssl rand -hex 32`;
            chomp($ENV{'OPENCLAW_GATEWAY_TOKEN'});
        } else {
            $ENV{'OPENCLAW_GATEWAY_TOKEN'} = `python3 -c "import secrets; print(secrets.token_hex(32))"`;
            chomp($ENV{'OPENCLAW_GATEWAY_TOKEN'});
        }
    }
}

my @COMPOSE_FILES = ($COMPOSE_FILE);
my @COMPOSE_ARGS = ();

sub write_extra_compose {
    my ($home_volume, @mounts) = @_;
    open(my $fh, '>', $EXTRA_COMPOSE_FILE) or fail("Cannot write to $EXTRA_COMPOSE_FILE");

    print $fh "services:\n  openclaw-gateway:\n    volumes:\n";

    if ($home_volume) {
        my $gateway_home_mount = "${home_volume}:/home/node";
        my $gateway_config_mount = "$ENV{'OPENCLAW_CONFIG_DIR'}:/home/node/.openclaw";
        my $gateway_workspace_mount = "$ENV{'OPENCLAW_WORKSPACE_DIR'}:/home/node/.openclaw/workspace";
        
        validate_mount_spec($gateway_home_mount);
        validate_mount_spec($gateway_config_mount);
        validate_mount_spec($gateway_workspace_mount);
        
        print $fh "      - $gateway_home_mount\n";
        print $fh "      - $gateway_config_mount\n";
        print $fh "      - $gateway_workspace_mount\n";
    }

    for my $mount (@mounts) {
        validate_mount_spec($mount);
        print $fh "      - $mount\n";
    }

    print $fh "  openclaw-cli:\n    volumes:\n";

    if ($home_volume) {
        my $gateway_home_mount = "${home_volume}:/home/node";
        my $gateway_config_mount = "$ENV{'OPENCLAW_CONFIG_DIR'}:/home/node/.openclaw";
        my $gateway_workspace_mount = "$ENV{'OPENCLAW_WORKSPACE_DIR'}:/home/node/.openclaw/workspace";
        
        print $fh "      - $gateway_home_mount\n";
        print $fh "      - $gateway_config_mount\n";
        print $fh "      - $gateway_workspace_mount\n";
    }

    for my $mount (@mounts) {
        validate_mount_spec($mount);
        print $fh "      - $mount\n";
    }

    if ($home_volume && $home_volume !~ m|/|) {
        validate_named_volume($home_volume);
        print $fh "volumes:\n  ${home_volume}:\n";
    }
    
    close($fh);
}

# When sandbox is requested, ensure Docker CLI build arg is set for local builds.
# Docker socket mount is deferred until sandbox prerequisites are verified.
if ($SANDBOX_ENABLED) {
    if (!defined $ENV{'OPENCLAW_INSTALL_DOCKER_CLI'}) {
        $ENV{'OPENCLAW_INSTALL_DOCKER_CLI'} = 1;
    }
}

my @VALID_MOUNTS = ();
if ($EXTRA_MOUNTS) {
    @VALID_MOUNTS = split(/,/, $EXTRA_MOUNTS);
    for my $mount (@VALID_MOUNTS) {
        $mount =~ s/^\s+|\s+$//g;  # Trim whitespace
        $mount = '' if !$mount;   # Remove empty strings
    }
    @VALID_MOUNTS = grep { $_ } @VALID_MOUNTS;  # Remove empty elements
}

if ($HOME_VOLUME_NAME || @VALID_MOUNTS) {
    if (@VALID_MOUNTS) {
        write_extra_compose($HOME_VOLUME_NAME, @VALID_MOUNTS);
    } else {
        write_extra_compose($HOME_VOLUME_NAME);
    }
    push @COMPOSE_FILES, $EXTRA_COMPOSE_FILE;
}

for my $compose_file (@COMPOSE_FILES) {
    push @COMPOSE_ARGS, "-f", $compose_file;
}

# Keep a base compose arg set without sandbox overlay so rollback paths can
# force a known-safe gateway service definition (no docker.sock mount).
my @BASE_COMPOSE_ARGS = @COMPOSE_ARGS;
my $COMPOSE_HINT = "docker compose";
for my $compose_file (@COMPOSE_FILES) {
    $COMPOSE_HINT .= " -f $compose_file";
}

my $ENV_FILE = "$ROOT_DIR/.env";

sub upsert_env {
    my ($file, @keys) = @_;
    my ($tmp_fh, $tmp_filename) = tempfile();
    
    # Use a delimited string instead of an associative array so the script
    # works with Bash 3.2 (macOS default) which lacks `declare -A`.
    my $seen = " ";

    if (-f $file) {
        open(my $fh, '<', $file) or fail("Cannot read $file");
        while (my $line = <$fh>) {
            chomp($line);
            my ($key) = $line =~ /^([^=]*)=/;
            my $replaced = 0;
            
            for my $k (@keys) {
                if (defined $key && $key eq $k) {
                    print $tmp_fh "$k=" . ($ENV{$k} // '') . "\n";
                    $seen .= "$k ";
                    $replaced = 1;
                    last;
                }
            }
            
            if (!$replaced) {
                print $tmp_fh "$line\n";
            }
        }
        close($fh);
    }

    for my $k (@keys) {
        if ($seen !~ / $k /) {
            print $tmp_fh "$k=" . ($ENV{$k} // '') . "\n";
        }
    }

    close($tmp_fh);
    rename($tmp_filename, $file) or fail("Cannot move temp file to $file");
}

upsert_env($ENV_FILE,
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
);

if ($IMAGE_NAME eq "openclaw:local") {
    print "==> Building Docker image: $IMAGE_NAME\n";
    run_docker_build(
        '--build-arg', "OPENCLAW_DOCKER_APT_PACKAGES=$ENV{'OPENCLAW_DOCKER_APT_PACKAGES'}",
        '--build-arg', "OPENCLAW_EXTENSIONS=$ENV{'OPENCLAW_EXTENSIONS'}",
        '--build-arg', "OPENCLAW_INSTALL_DOCKER_CLI=" . ($ENV{'OPENCLAW_INSTALL_DOCKER_CLI'} // ''),
        '-t', $IMAGE_NAME,
        '-f', "$ROOT_DIR/Dockerfile",
        $ROOT_DIR
    );
} else {
    print "==> Pulling Docker image: $IMAGE_NAME\n";
    if (system("docker", "pull", $IMAGE_NAME) != 0) {
        print STDERR "ERROR: Failed to pull image $IMAGE_NAME. Please check the image name and your access permissions.\n";
        exit 1;
    }
}

# Ensure bind-mounted data directories are writable by the container's `node`
# user (uid 1000). Host-created dirs inherit the host user's uid which may
# differ, causing EACCES when the container tries to mkdir/write.
# Running a brief root container to chown is the portable Docker idiom --
# it works regardless of the host uid and doesn't require host-side root.
print "\n";
print "==> Fixing data-directory permissions\n";
# Use -xdev to restrict chown to the config-dir mount only — without it,
# the recursive chown would cross into the workspace bind mount and rewrite
# ownership of all user project files on Linux hosts.
# After fixing the config dir, only the OpenClaw metadata subdirectory
# (.openclaw/) inside the workspace gets chowned, not the user's project files.
system("run_prestart_gateway --user root --entrypoint sh openclaw-gateway -c 'find /home/node/.openclaw -xdev -exec chown node:node {} +; [ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true'") == 0
    or fail("Failed to fix permissions");

print "\n";
print "==> Onboarding (interactive)\n";
print "Docker setup pins Gateway mode to local.\n";
print "Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan).\n";
print "Current runtime bind: $ENV{'OPENCLAW_GATEWAY_BIND'}\n";
print "Gateway token: $ENV{'OPENCLAW_GATEWAY_TOKEN'}\n";
print "Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately).\n";
print "Install Gateway daemon: No (managed by Docker Compose)\n";
print "\n";

run_prestart_cli('onboard', '--mode', 'local', '--no-install-daemon');

print "\n";
print "==> Docker gateway defaults\n";
sync_gateway_config();

print "\n";
print "==> Provider setup (optional)\n";
print "WhatsApp (QR):\n";
print "  ${COMPOSE_HINT} run --rm openclaw-cli channels login\n";
print "Telegram (bot token):\n";
print "  ${COMPOSE_HINT} run --rm openclaw-cli channels add --channel telegram --token <token>\n";
print "Discord (bot token):\n";
print "  ${COMPOSE_HINT} run --rm openclaw-cli channels add --channel discord --token <token>\n";
print "Docs: https://docs.openclaw.ai/channels\n";

print "\n";
print "==> Starting gateway\n";
system('docker', 'compose', @COMPOSE_ARGS, 'up', '-d', 'openclaw-gateway') == 0
    or fail("Failed to start gateway");

# --- Sandbox setup (opt-in via OPENCLAW_SANDBOX=1) ---
if ($SANDBOX_ENABLED) {
    print "\n";
    print "==> Sandbox setup\n";

    # Build sandbox image if Dockerfile.sandbox exists.
    if (-f "$ROOT_DIR/Dockerfile.sandbox") {
        print "Building sandbox image: openclaw-sandbox:bookworm-slim\n";
        run_docker_build(
            '-t', 'openclaw-sandbox:bookworm-slim',
            '-f', "$ROOT_DIR/Dockerfile.sandbox",
            $ROOT_DIR
        );
    } else {
        print STDERR "WARNING: Dockerfile.sandbox not found in $ROOT_DIR\n";
        print STDERR "  Sandbox config will be applied but no sandbox image will be built.\n";
        print STDERR "  Agent exec may fail if the configured sandbox image does not exist.\n";
    }

    # Defense-in-depth: verify Docker CLI in the running image before enabling
    # sandbox. This avoids claiming sandbox is enabled when the image cannot
    # launch sandbox containers.
    if (system('docker', 'compose', @COMPOSE_ARGS, 'run', '--rm', '--entrypoint', 'docker', 'openclaw-gateway', '--version', '>/dev/null', '2>&1') != 0) {
        print STDERR "WARNING: Docker CLI not found inside the container image.\n";
        print STDERR "  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1\n";
        print STDERR "  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup.\n";
        $SANDBOX_ENABLED = "";
    }
}

# Apply sandbox config only if prerequisites are met.
if ($SANDBOX_ENABLED) {
    # Mount Docker socket via a dedicated compose overlay. This overlay is
    # created only after sandbox prerequisites pass, so the socket is never
    # exposed when sandbox cannot actually run.
    if (-S $DOCKER_SOCKET_PATH) {
        my $SANDBOX_COMPOSE_FILE = "$ROOT_DIR/docker-compose.sandbox.yml";
        open(my $fh, '>', $SANDBOX_COMPOSE_FILE) or fail("Cannot write to $SANDBOX_COMPOSE_FILE");
        print $fh "services:\n  openclaw-gateway:\n    volumes:\n      - ${DOCKER_SOCKET_PATH}:/var/run/docker.sock\n";
        
        if ($ENV{'DOCKER_GID'}) {
            print $fh "    group_add:\n      - \"$ENV{'DOCKER_GID'}\"\n";
        }
        close($fh);
        
        push @COMPOSE_ARGS, "-f", $SANDBOX_COMPOSE_FILE;
        print "==> Sandbox: added Docker socket mount\n";
    } else {
        print STDERR "WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at $DOCKER_SOCKET_PATH.\n";
        print STDERR "  Sandbox requires Docker socket access. Skipping sandbox setup.\n";
        $SANDBOX_ENABLED = "";
    }
}

if ($SANDBOX_ENABLED) {
    # Enable sandbox in OpenClaw config.
    my $sandbox_config_ok = 1;
    
    if (run_runtime_cli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.mode', '"non-main"') != 0) {
        print STDERR "WARNING: Failed to set agents.defaults.sandbox.mode\n";
        $sandbox_config_ok = 0;
    }
    
    if (run_runtime_cli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.scope', '"agent"') != 0) {
        print STDERR "WARNING: Failed to set agents.defaults.sandbox.scope\n";
        $sandbox_config_ok = 0;
    }
    
    if (run_runtime_cli('current', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.workspaceAccess', '"none"') != 0) {
        print STDERR "WARNING: Failed to set agents.defaults.sandbox.workspaceAccess\n";
        $sandbox_config_ok = 0;
    }

    if ($sandbox_config_ok) {
        print "Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none\n";
        print "Docs: https://docs.openclaw.ai/gateway/sandboxing\n";
        # Restart gateway with sandbox compose overlay to pick up socket mount + config.
        system('docker', 'compose', @COMPOSE_ARGS, 'up', '-d', 'openclaw-gateway') == 0
            or fail("Failed to restart gateway with sandbox");
    } else {
        print STDERR "WARNING: Sandbox config was partially applied. Check errors above.\n";
        print STDERR "  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy.\n";
        
        if (run_runtime_cli('base', 'no-deps', 'config', 'set', 'agents.defaults.sandbox.mode', '"off"') == 0) {
            print "Sandbox mode rolled back to off due to partial sandbox config failure.\n";
        } else {
            print STDERR "WARNING: Failed to roll back agents.defaults.sandbox.mode to off\n";
        }
        
        if (defined $ENV{'SANDBOX_COMPOSE_FILE'}) {
            unlink($ENV{'SANDBOX_COMPOSE_FILE'});
        }
        # Ensure gateway service definition is reset without sandbox overlay mount.
        system('docker', 'compose', @BASE_COMPOSE_ARGS, 'up', '-d', '--force-recreate', 'openclaw-gateway') == 0
            or fail("Failed to reset gateway without sandbox");
    }
} else {
    # Keep reruns deterministic: if sandbox is not active for this run, reset
    # persisted sandbox mode so future execs do not require docker.sock by stale
    # config alone.
    if (run_runtime_cli('current', 'with-deps', 'config', 'set', 'agents.defaults.sandbox.mode', '"off"') != 0) {
        print STDERR "WARNING: Failed to reset agents.defaults.sandbox.mode to off\n";
    }
    
    if (-f "$ROOT_DIR/docker-compose.sandbox.yml") {
        unlink("$ROOT_DIR/docker-compose.sandbox.yml");
    }
}

print "\n";
print "Gateway running with host port mapping.\n";
print "Access from tailnet devices via the host's tailnet IP.\n";
print "Config: $ENV{'OPENCLAW_CONFIG_DIR'}\n";
print "Workspace: $ENV{'OPENCLAW_WORKSPACE_DIR'}\n";
print "Token: $ENV{'OPENCLAW_GATEWAY_TOKEN'}\n";
print "\n";
print "Commands:\n";
print "  ${COMPOSE_HINT} logs -f openclaw-gateway\n";
print "  ${COMPOSE_HINT} exec openclaw-gateway node dist/index.js health --token \"$ENV{'OPENCLAW_GATEWAY_TOKEN'}\"\n";
