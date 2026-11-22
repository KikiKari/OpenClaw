#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "cd3ae5fdf083e12fd8684d7f76e9b77b0aa94c22f566e4f8102d3789516fb3a6", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "perl5"}
# run-openclaw-podman.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/run-openclaw-podman.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd 'abs_path';
use POSIX qw(strftime);

my $PLATFORM_NAME = $^O;

sub resolve_user_home {
    my ($user) = @_;
    my $home = "";
    if (-x "/usr/bin/getent") {
        my $getent_output = `getent passwd "$user" 2>/dev/null`;
        if ($getent_output =~ /^.*?:.*?:.*?:.*?:.*?:(.*?)\//) {
            $home = $1;
        }
    }
    if (!$home && -f "/etc/passwd") {
        open(my $fh, '<', '/etc/passwd') or die "Cannot open /etc/passwd: $!";
        while (my $line = <$fh>) {
            chomp $line;
            my @fields = split(':', $line);
            if (@fields >= 6 && $fields[0] eq $user) {
                $home = $fields[5];
                last;
            }
        }
        close($fh);
    }
    if (!$home) {
        $home = "/home/$user";
    }
    return $home;
}

sub fail {
    my ($msg) = @_;
    print STDERR "$msg\n";
    exit 1;
}

sub validate_single_line_value {
    my ($label, $value) = @_;
    if ($value =~ /[\n\r]/) {
        fail("Invalid $label: control characters are not allowed.");
    }
}

sub validate_absolute_path {
    my ($label, $value) = @_;
    validate_single_line_value($label, $value);
    unless ($value =~ m{^/}) {
        fail("Invalid $label: expected an absolute path.");
    }
    if ($value =~ m{//}) {
        fail("Invalid $label: repeated slashes are not allowed.");
    }
    if ($value =~ m{/\.\/} || $value =~ m{/\.$} || $value =~ m{/\.\./} || $value =~ m{/\.\.$}) {
        fail("Invalid $label: dot path segments are not allowed.");
    }
}

sub validate_mount_source_path {
    my ($label, $value) = @_;
    validate_absolute_path($label, $value);
    if ($value =~ /:/) {
        fail("Invalid $label: ':' is not allowed in Podman bind-mount source paths.");
    }
}

sub ensure_safe_existing_regular_file {
    my ($label, $file) = @_;
    validate_absolute_path($label, $file);
    unless (-e $file) {
        fail("Missing $label: $file");
    }
    if (-l $file) {
        fail("Unsafe $label: symlinks are not allowed ($file)");
    }
    unless (-f $file) {
        fail("Unsafe $label: expected a regular file ($file)");
    }
}

sub ensure_safe_existing_dir {
    my ($label, $dir) = @_;
    validate_absolute_path($label, $dir);
    unless (-d $dir) {
        fail("Missing $label: $dir");
    }
    if (-l $dir) {
        fail("Unsafe $label: symlinks are not allowed ($dir)");
    }
}

sub stat_uid {
    my ($path) = @_;
    my $uid = (stat($path))[4];
    return defined $uid ? $uid : 0;
}

sub stat_mode {
    my ($path) = @_;
    my $mode = (stat($path))[2] & 07777;
    return sprintf("%04o", $mode);
}

sub ensure_private_existing_dir_owned_by_user {
    my ($label, $dir) = @_;
    ensure_safe_existing_dir($label, $dir);
    my $uid = stat_uid($dir);
    my $current_uid = $<;
    unless ($uid == $current_uid) {
        fail("Unsafe $label: not owned by current user ($dir)");
    }
    my $mode = oct(stat_mode($dir));
    if (($mode & 0022) != 0) {
        fail("Unsafe $label: group/other writable ($dir)");
    }
}

sub ensure_private_existing_regular_file_owned_by_user {
    my ($label, $file) = @_;
    ensure_safe_existing_regular_file($label, $file);
    my $uid = stat_uid($file);
    my $current_uid = $<;
    unless ($uid == $current_uid) {
        fail("Unsafe $label: not owned by current user ($file)");
    }
    my $mode = oct(stat_mode($file));
    if (($mode & 0077) != 0) {
        fail("Unsafe $label: expected owner-only permissions ($file)");
    }
}

sub ensure_safe_write_file_path {
    my ($label, $file) = @_;
    validate_absolute_path($label, $file);
    if (-e $file) {
        if (-l $file) {
            fail("Unsafe $label: symlinks are not allowed ($file)");
        }
        unless (-f $file) {
            fail("Unsafe $label: expected a regular file ($file)");
        }
    }
    my $dir = dirname($file);
    ensure_safe_existing_dir("${label} parent directory", $dir);
}

sub write_file_atomically {
    my ($file, $mode, $content) = @_;
    ensure_safe_write_file_path("output file", $file);
    my $dir = dirname($file);
    my $tmp = "$dir/.tmp." . int(rand(100000));
    open(my $fh, '>', $tmp) or fail("Cannot create temporary file: $!");
    print $fh $content;
    close($fh);
    chmod(oct($mode), $tmp);
    rename($tmp, $file) or fail("Cannot move temporary file: $!");
}

sub load_podman_env_file {
    my ($file) = @_;
    ensure_private_existing_regular_file_owned_by_user("Podman env file", $file);
    my $dir = dirname($file);
    ensure_private_existing_dir_owned_by_user("Podman env directory", $dir);
    open(my $fh, '<', $file) or fail("Unable to open Podman env file: $file");
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;
        next if !$line || $line =~ /^#/;
        next unless $line =~ /=/;
        my ($key, $value) = split('=', $line, 2);
        $key =~ s/^\s+|\s+$//g;
        next unless $key =~ /^[A-Za-z_][A-Za-z0-9_]*$/;
        next unless $key =~ /^(OPENCLAW_GATEWAY_TOKEN|OPENCLAW_PODMAN_CONTAINER|OPENCLAW_PODMAN_IMAGE|OPENCLAW_IMAGE|OPENCLAW_PODMAN_PULL|OPENCLAW_PODMAN_GATEWAY_HOST_PORT|OPENCLAW_GATEWAY_PORT|OPENCLAW_PODMAN_BRIDGE_HOST_PORT|OPENCLAW_BRIDGE_PORT|OPENCLAW_GATEWAY_BIND|OPENCLAW_PODMAN_USERNS|OPENCLAW_BIND_MOUNT_OPTIONS|OPENCLAW_PODMAN_PUBLISH_HOST)$/;
        if ($value =~ /^(['"]).*\1$/) {
            $value = substr($value, 1, length($value)-2);
        }
        $ENV{$key} = $value;
    }
    close($fh);
}

sub validate_port {
    my ($label, $value) = @_;
    unless ($value =~ /^\d{1,5}$/) {
        fail("Invalid $label: must be numeric.");
    }
    my $numeric = int($value);
    if ($numeric < 1 || $numeric > 65535) {
        fail("Invalid $label: out of range.");
    }
}

my $EFFECTIVE_USER = getpwuid($<);
my $EFFECTIVE_HOME = $ENV{'HOME'} // "";
if (!$EFFECTIVE_HOME) {
    $EFFECTIVE_HOME = resolve_user_home($EFFECTIVE_USER);
}
if ($< == 0) {
    fail("Run run-openclaw-podman.sh as your normal user so Podman stays rootless.");
}

if (@ARGV && $ARGV[0] eq "setup-host") {
    shift @ARGV;
    my $script_dir = dirname(abs_path($0));
    my $repo_root = dirname(dirname($script_dir));
    my $setup_podman = "$repo_root/scripts/podman/setup.sh";
    if (-f $setup_podman) {
        system("bash", $setup_podman, @ARGV) == 0 or die "Failed to execute setup script: $!";
        exit 0;
    }
    $setup_podman = "$repo_root/setup-podman.sh";
    if (-f $setup_podman) {
        system("bash", $setup_podman, @ARGV) == 0 or die "Failed to execute setup script: $!";
        exit 0;
    }
    print STDERR "Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh\n";
    exit 1;
}

if (@ARGV && $ARGV[0] eq "launch") {
    shift @ARGV;
}

if (!$EFFECTIVE_HOME) {
    $EFFECTIVE_HOME = "/tmp";
}
validate_absolute_path("effective home", $EFFECTIVE_HOME);

my $CONFIG_DIR = $ENV{'OPENCLAW_CONFIG_DIR'} // "$EFFECTIVE_HOME/.openclaw";
my $ENV_FILE = $ENV{'OPENCLAW_PODMAN_ENV'} // "$CONFIG_DIR/.env";
if (-f $ENV_FILE) {
    load_podman_env_file($ENV_FILE);
}

$CONFIG_DIR = $ENV{'OPENCLAW_CONFIG_DIR'} // "$EFFECTIVE_HOME/.openclaw";
$ENV_FILE = $ENV{'OPENCLAW_PODMAN_ENV'} // "$CONFIG_DIR/.env";
my $WORKSPACE_DIR = $ENV{'OPENCLAW_WORKSPACE_DIR'} // "$CONFIG_DIR/workspace";
my $CONTAINER_NAME = $ENV{'OPENCLAW_PODMAN_CONTAINER'} // "openclaw";
my $OPENCLAW_IMAGE = $ENV{'OPENCLAW_PODMAN_IMAGE'} // ($ENV{'OPENCLAW_IMAGE'} // "openclaw:local");
my $PODMAN_PULL = $ENV{'OPENCLAW_PODMAN_PULL'} // "never";
my $HOST_GATEWAY_PORT = $ENV{'OPENCLAW_PODMAN_GATEWAY_HOST_PORT'} // ($ENV{'OPENCLAW_GATEWAY_PORT'} // "18789");
my $HOST_BRIDGE_PORT = $ENV{'OPENCLAW_PODMAN_BRIDGE_HOST_PORT'} // ($ENV{'OPENCLAW_BRIDGE_PORT'} // "18790");
my $PUBLISH_HOST = $ENV{'OPENCLAW_PODMAN_PUBLISH_HOST'} // "127.0.0.1";

validate_mount_source_path("config directory", $CONFIG_DIR);
validate_mount_source_path("workspace directory", $WORKSPACE_DIR);
validate_absolute_path("env file path", $ENV_FILE);
validate_single_line_value("container name", $CONTAINER_NAME);
validate_single_line_value("image name", $OPENCLAW_IMAGE);
validate_single_line_value("publish host", $PUBLISH_HOST);
validate_port("gateway host port", $HOST_GATEWAY_PORT);
validate_port("bridge host port", $HOST_BRIDGE_PORT);

chdir($EFFECTIVE_HOME) or chdir("/tmp") or die "Cannot change directory";

my $RUN_SETUP = 0;
if (@ARGV && ($ARGV[0] eq "setup" || $ARGV[0] eq "onboard")) {
    $RUN_SETUP = 1;
    shift @ARGV;
}

unless (-d $CONFIG_DIR) {
    mkdir $CONFIG_DIR or die "Cannot create config directory: $!";
}
unless (-d $WORKSPACE_DIR) {
    mkdir $WORKSPACE_DIR or die "Cannot create workspace directory: $!";
}
unless (-d "$CONFIG_DIR/canvas") {
    mkdir "$CONFIG_DIR/canvas" or die "Cannot create canvas directory: $!";
}
unless (-d "$CONFIG_DIR/cron") {
    mkdir "$CONFIG_DIR/cron" or die "Cannot create cron directory: $!";
}
chmod 0700, $CONFIG_DIR;
chmod 0700, $WORKSPACE_DIR;
ensure_private_existing_dir_owned_by_user("config directory", $CONFIG_DIR);
ensure_private_existing_dir_owned_by_user("workspace directory", $WORKSPACE_DIR);

sub resolve_config_gateway_bind {
    my ($config_dir) = @_;
    unless (`which openclaw 2>/dev/null`) {
        return "";
    }
    my $result = `OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR="$config_dir" openclaw config get gateway.bind 2>/dev/null`;
    chomp $result;
    return $result;
}

my $CONFIG_GATEWAY_BIND = resolve_config_gateway_bind($CONFIG_DIR);
my $GATEWAY_BIND = $ENV{'OPENCLAW_GATEWAY_BIND'} // ($CONFIG_GATEWAY_BIND // "lan");

sub upsert_env_var {
    my ($file, $key, $value) = @_;
    ensure_safe_write_file_path("env file", $file);
    my $dir = dirname($file);
    my $tmp = "$dir/.env.tmp." . int(rand(100000));
    if (-f $file) {
        open(my $fh_in, '<', $file) or fail("Cannot read env file: $!");
        open(my $fh_out, '>', $tmp) or fail("Cannot create temp file: $!");
        my $found = 0;
        while (my $line = <$fh_in>) {
            if ($line =~ /^$key=/) {
                print $fh_out "$key=$value\n";
                $found = 1;
            } else {
                print $fh_out $line;
            }
        }
        unless ($found) {
            print $fh_out "$key=$value\n";
        }
        close($fh_in);
        close($fh_out);
    } else {
        open(my $fh, '>', $tmp) or fail("Cannot create temp file: $!");
        print $fh "$key=$value\n";
        close($fh);
    }
    rename($tmp, $file) or fail("Cannot move temp file: $!");
    chmod(0600, $file);
}

sub generate_token_hex_32 {
    if (`which openssl 2>/dev/null`) {
        my $output = `openssl rand -hex 32`;
        chomp $output;
        return $output;
    }
    if (`which python3 2>/dev/null`) {
        my $output = `python3 -c "import secrets; print(secrets.token_hex(32))"`;
        chomp $output;
        return $output;
    }
    if (`which od 2>/dev/null`) {
        my $output = `od -An -N32 -tx1 /dev/urandom | tr -d ' \\n'`;
        chomp $output;
        return $output;
    }
    fail("Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.");
}

sub create_token_env_file {
    my ($file, $token) = @_;
    my $dir = dirname($file);
    ensure_private_existing_dir_owned_by_user("token env directory", $dir);
    my $tmp = "$dir/.token.env." . int(rand(100000));
    chmod(0600, $tmp);
    open(my $fh, '>', $tmp) or fail("Cannot create token env file: $!");
    print $fh "OPENCLAW_GATEWAY_TOKEN=$token\n";
    close($fh);
    return $tmp;
}

sub sync_local_control_ui_origins_via_cli {
    my ($file, $port) = @_;
    my $config_dir = dirname($file);
    unless (`which openclaw 2>/dev/null`) {
        warn "Warning: openclaw not found; unable to sync gateway.controlUi.allowedOrigins in $file.\n";
        return;
    }
    unless (`which python3 2>/dev/null`) {
        system("OPENCLAW_CONTAINER=\"\" OPENCLAW_CONFIG_DIR=\"$config_dir\" openclaw config set gateway.controlUi.allowedOrigins \"[\\\"http://127.0.0.1:${port}\\\",\\\"http://localhost:${port}\\\"]\" --strict-json >/dev/null");
        return;
    }
    my $allowed_json = `OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR="$config_dir" openclaw config get gateway.controlUi.allowedOrigins --json 2>/dev/null`;
    chomp $allowed_json;
    my $merged_json = `python3 - "$port" "$allowed_json" <<'PY'
import json
import sys

port = sys.argv[1]
raw = sys.argv[2] if len(sys.argv) > 2 else ""
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
allowed = []
if raw:
    try:
        parsed = json.loads(raw)
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
print(json.dumps(cleaned))
PY`;
    chomp $merged_json;
    system("OPENCLAW_CONTAINER=\"\" OPENCLAW_CONFIG_DIR=\"$config_dir\" openclaw config set gateway.controlUi.allowedOrigins \"$merged_json\" --strict-json >/dev/null");
}

sub sync_local_control_ui_origins {
    my ($file, $port) = @_;
    ensure_safe_write_file_path("config file", $file);
    unless (`which python3 2>/dev/null`) {
        warn "Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in $file.\n";
        return;
    }
    my $dir = dirname($file);
    ensure_private_existing_dir_owned_by_user("config file directory", $dir);
    my $tmp = "$dir/.config.tmp." . int(rand(100000));
    my $python_script = <<'PYTHON_CODE';
import json
import sys

path = sys.argv[1]
port = sys.argv[2]
tmp = sys.argv[3]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f"Warning: unable to sync gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.",
        file=sys.stderr,
    )
    raise SystemExit(1)
if not isinstance(data, dict):
    raise SystemExit(f"{path}: expected top-level object")
gateway = data.setdefault("gateway", {})
if not isinstance(gateway, dict):
    raise SystemExit(f"{path}: expected gateway object")
gateway.setdefault("mode", "local")
control_ui = gateway.setdefault("controlUi", {})
if not isinstance(control_ui, dict):
    raise SystemExit(f"{path}: expected gateway.controlUi object")
allowed = control_ui.get("allowedOrigins")
desired = [
    f"http://127.0.0.1:{port}",
    f"http://localhost:{port}",
]
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
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\\n")
PYTHON_CODE
    open(my $fh_py, '>', '/tmp/sync_script.py') or die "Cannot create Python script: $!";
    print $fh_py $python_script;
    close($fh_py);
    my $exit_code = system("python3 /tmp/sync_script.py \"$file\" \"$port\" \"$tmp\"");
    unlink('/tmp/sync_script.py');
    if ($exit_code != 0) {
        unlink($tmp);
        sync_local_control_ui_origins_via_cli($file, $port);
        return;
    }
    unless (-s $tmp) {
        unlink($tmp);
        return;
    }
    chmod(0600, $tmp);
    rename($tmp, $file) or fail("Cannot move temp file: $!");
}

my $TOKEN_ENV_FILE = "";

sub cleanup_token_env_file {
    if ($TOKEN_ENV_FILE && -f $TOKEN_ENV_FILE) {
        unlink($TOKEN_ENV_FILE);
    }
}

$SIG{INT} = \&cleanup_token_env_file;
$SIG{TERM} = \&cleanup_token_env_file;

unless ($ENV{'OPENCLAW_GATEWAY_TOKEN'}) {
    $ENV{'OPENCLAW_GATEWAY_TOKEN'} = generate_token_hex_32();
    unless (-d dirname($ENV_FILE)) {
        mkdir dirname($ENV_FILE) or die "Cannot create env file directory: $!";
    }
    ensure_safe_existing_dir("env file directory", dirname($ENV_FILE));
    upsert_env_var($ENV_FILE, "OPENCLAW_GATEWAY_TOKEN", $ENV{'OPENCLAW_GATEWAY_TOKEN'});
    warn "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to $ENV_FILE.\n";
}

my $CONFIG_JSON = "$CONFIG_DIR/openclaw.json";
if (!-f $CONFIG_JSON) {
    my $content = "{ \"gateway\": { \"mode\": \"local\" } }\n";
    write_file_atomically($CONFIG_JSON, "600", $content);
    warn "Created $CONFIG_JSON (minimal gateway.mode=local).\n";
}
sync_local_control_ui_origins($CONFIG_JSON, $HOST_GATEWAY_PORT);

my $PODMAN_USERNS = $ENV{'OPENCLAW_PODMAN_USERNS'} // "keep-id";
my @USERNS_ARGS = ();
my @RUN_USER_ARGS = ();
if ($PODMAN_USERNS eq "keep-id") {
    @USERNS_ARGS = ("--userns=keep-id");
} elsif ($PODMAN_USERNS eq "host") {
    @USERNS_ARGS = ("--userns=host");
} elsif ($PODMAN_USERNS ne "auto" && $PODMAN_USERNS ne "") {
    fail("Unsupported OPENCLAW_PODMAN_USERNS=$PODMAN_USERNS (expected: keep-id, auto, host).");
}

my $RUN_UID = $<;
my $RUN_GID = $(;
if ($PODMAN_USERNS eq "keep-id") {
    @RUN_USER_ARGS = ("--user", "${RUN_UID}:${RUN_GID}");
} else {
    warn "Starting container without --user (OPENCLAW_PODMAN_USERNS=$PODMAN_USERNS), mounts may require ownership fixes.\n";
}

my $SELINUX_MOUNT_OPTS = "";
unless ($ENV{'OPENCLAW_BIND_MOUNT_OPTIONS'}) {
    if ($^O eq "linux" && `which getenforce 2>/dev/null`) {
        my $selinux_mode = `getenforce 2>/dev/null`;
        chomp $selinux_mode;
        if ($selinux_mode eq "Enforcing" || $selinux_mode eq "Permissive") {
            $SELINUX_MOUNT_OPTS = ",Z";
        }
    }
} else {
    $SELINUX_MOUNT_OPTS = $ENV{'OPENCLAW_BIND_MOUNT_OPTIONS'};
    $SELINUX_MOUNT_OPTS =~ s/^://;
    if ($SELINUX_MOUNT_OPTS) {
        $SELINUX_MOUNT_OPTS = ",$SELINUX_MOUNT_OPTS";
    }
}

if ($RUN_SETUP) {
    $TOKEN_ENV_FILE = create_token_env_file($ENV_FILE, $ENV{'OPENCLAW_GATEWAY_TOKEN'});
    my @cmd = (
        "podman", "run", "--pull=$PODMAN_PULL", "--rm", "-it",
        "--init",
        @USERNS_ARGS, @RUN_USER_ARGS,
        "-e", "HOME=/home/node", "-e", "TERM=xterm-256color", "-e", "BROWSER=echo",
        "-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
        "-e", "OPENCLAW_NO_RESPAWN=1",
        "--env-file", $TOKEN_ENV_FILE,
        "-v", "$CONFIG_DIR:/home/node/.openclaw:rw${SELINUX_MOUNT_OPTS}",
        "-v", "$WORKSPACE_DIR:/home/node/.openclaw/workspace:rw${SELINUX_MOUNT_OPTS}",
        $OPENCLAW_IMAGE,
        "node", "dist/index.js", "onboard", @ARGV
    );
    system(@cmd) == 0 or fail("Failed to run podman command: $!");
    exit 0;
}

$TOKEN_ENV_FILE = create_token_env_file($ENV_FILE, $ENV{'OPENCLAW_GATEWAY_TOKEN'});
my @cmd = (
    "podman", "run", "--pull=$PODMAN_PULL", "-d", "--replace",
    "--name", $CONTAINER_NAME,
    "--init",
    @USERNS_ARGS, @RUN_USER_ARGS,
    "-e", "HOME=/home/node", "-e", "TERM=xterm-256color",
    "-e", "NPM_CONFIG_CACHE=/home/node/.openclaw/.npm",
    "-e", "OPENCLAW_NO_RESPAWN=1",
    "--env-file", $TOKEN_ENV_FILE,
    "-v", "$CONFIG_DIR:/home/node/.openclaw:rw${SELINUX_MOUNT_OPTS}",
    "-v", "$WORKSPACE_DIR:/home/node/.openclaw/workspace:rw${SELINUX_MOUNT_OPTS}",
    "-p", "${PUBLISH_HOST}:${HOST_GATEWAY_PORT}:18789",
    "-p", "${PUBLISH_HOST}:${HOST_BRIDGE_PORT}:18790",
    $OPENCLAW_IMAGE,
    "node", "dist/index.js", "gateway", "--bind", $GATEWAY_BIND, "--port", "18789"
);
open(my $null, '>', '/dev/null') or die "Cannot open /dev/null: $!";
open(STDOUT, '>&', $null) or die "Cannot redirect stdout: $!";
system(@cmd) == 0 or fail("Failed to run podman command: $!");
close($null);

print "Container $CONTAINER_NAME started: http://127.0.0.1:${HOST_GATEWAY_PORT}/\n";
print "podman exec -it $CONTAINER_NAME openclaw dashboard --no-open\n";
print "podman exec -it $CONTAINER_NAME openclaw devices approve --latest  # if pairing required\n";
print "podman logs -f $CONTAINER_NAME\n";
if ($PLATFORM_NAME eq "linux") {
    print "For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service).\n";
}
