#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "49adbf0dd0c58abbdf9970cddc9515af90eb7a52e76aa850a18f170c589cc33c", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "perl5"}
# setup.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path);
use POSIX;

# One-time host setup for rootless OpenClaw in Podman. Uses the current
# non-root user throughout, builds or pulls the image into that user's Podman
# store, writes config under ~/.openclaw by default, and uses the repo-local
# launch script at ./scripts/run-openclaw-podman.sh.
#
# Usage: ./scripts/podman/setup.sh [--quadlet|--container]
#   --quadlet   Install a Podman Quadlet as the current user's systemd service
#   --container Only install image + config; you start the container manually (default)
#   Or set OPENCLAW_PODMAN_QUADLET=1 (or 0) to choose without a flag.
#
# After this, start the gateway manually:
#   ./scripts/run-openclaw-podman.sh launch
#   ./scripts/run-openclaw-podman.sh launch setup
# Or, if you used --quadlet:
#   systemctl --user start openclaw.service

my $repo_path = $ENV{'OPENCLAW_REPO_PATH'} // do {
    my $script_dir = dirname($0);
    my $rel_path = File::Spec->catdir($script_dir, "../..");
    abs_path($rel_path);
};

my $run_script_src = File::Spec->catfile($repo_path, "scripts", "run-openclaw-podman.sh");
my $quadlet_template = File::Spec->catfile($repo_path, "scripts", "podman", "openclaw.container.in");
my $openclaw_user = getpwuid($<);
my $openclaw_home = $ENV{'HOME'} // "";
my $openclaw_config_dir = $ENV{'OPENCLAW_CONFIG_DIR'} // "";
my $openclaw_workspace_dir = $ENV{'OPENCLAW_WORKSPACE_DIR'} // "";
my $openclaw_image = $ENV{'OPENCLAW_PODMAN_IMAGE'} // $ENV{'OPENCLAW_IMAGE'} // "openclaw:local";
my $openclaw_container_name = $ENV{'OPENCLAW_PODMAN_CONTAINER'} // "openclaw";
my $platform_name = eval { `uname -s 2>/dev/null` } || "unknown";
chomp $platform_name;
my $host_gateway_port = $ENV{'OPENCLAW_PODMAN_GATEWAY_HOST_PORT'} // $ENV{'OPENCLAW_GATEWAY_PORT'} // "18789";
my $quadlet_gateway_port = "18789";

sub require_cmd {
    my ($cmd) = @_;
    system("which $cmd >/dev/null 2>&1") == 0 or die "Missing dependency: $cmd\n";
}

sub is_root {
    return $< == 0;
}

sub fail {
    my ($msg) = @_;
    warn $msg . "\n";
    exit 1;
}

sub validate_single_line_value {
    my ($label, $value) = @_;
    if ($value =~ /[\n\r]/) {
        fail "Invalid $label: control characters are not allowed.";
    }
}

sub validate_absolute_path {
    my ($label, $value) = @_;
    validate_single_line_value($label, $value);
    $value =~ m|^/| or fail "Invalid $label: expected an absolute path.";
    $value !~ m|//| or fail "Invalid $label: repeated slashes are not allowed.";
    $value !~ m|/\./| && $value !~ m|/\.\.| && $value !~ m|/\.$| && $value !~ m|/\.\.$|
        or fail "Invalid $label: dot path segments are not allowed.";
}

sub validate_mount_source_path {
    my ($label, $value) = @_;
    validate_absolute_path($label, $value);
    $value !~ /:/ or fail "Invalid $label: ':' is not allowed in Podman bind-mount source paths.";
}

sub validate_container_name {
    my ($value) = @_;
    validate_single_line_value("container name", $value);
    $value =~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/ or fail "Invalid container name: $value";
}

sub validate_image_name {
    my ($value) = @_;
    validate_single_line_value("image name", $value);
    $value !~ /^(oci-archive:|docker-archive:|dir:|oci:|containers-storage:|docker-daemon:|archive:)/
        or fail "Invalid image name: transport prefixes are not allowed: $value";
    $value =~ /^[A-Za-z0-9][A-Za-z0-9._\/:@-]*$/ or fail "Invalid image name: $value";
}

sub ensure_safe_existing_dir {
    my ($label, $dir) = @_;
    validate_absolute_path($label, $dir);
    -d $dir or fail "Missing $label: $dir";
    -l $dir and fail "Unsafe $label: symlinks are not allowed ($dir)";
}

sub stat_uid {
    my ($path) = @_;
    my $uid = (stat($path))[4];
    return defined $uid ? $uid : -1;
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
    $uid == $< or fail "Unsafe $label: not owned by current user ($dir)";
    my $mode = oct(stat_mode($dir));
    ($mode & 0022) == 0 or fail "Unsafe $label: group/other writable ($dir)";
}

sub ensure_safe_write_file_path {
    my ($label, $file) = @_;
    validate_absolute_path($label, $file);
    if (-e $file) {
        -l $file and fail "Unsafe $label: symlinks are not allowed ($file)";
        -f $file or fail "Unsafe $label: expected a regular file ($file)";
    }
    my ($volume, $directories) = File::Spec->splitpath($file);
    my @dirs = File::Spec->splitdir($directories);
    pop @dirs;
    my $dir = File::Spec->catdir($volume, @dirs);
    ensure_safe_existing_dir("$label parent directory", $dir);
}

sub write_file_atomically {
    my ($file, $mode, $content) = @_;
    ensure_safe_write_file_path("output file", $file);
    my ($volume, $directories) = File::Spec->splitpath($file);
    my @dirs = File::Spec->splitdir($directories);
    pop @dirs;
    my $dir = File::Spec->catdir($volume, @dirs);
    my $tmp = File::Spec->catfile($dir, ".tmp." . int(rand(100000)));
    open(my $fh, '>', $tmp) or die "Cannot create temporary file: $!";
    print $fh $content;
    close $fh;
    chmod(oct($mode), $tmp) or warn "Cannot chmod temporary file: $!";
    rename($tmp, $file) or die "Cannot move temporary file: $!";
}

sub validate_port {
    my ($label, $value) = @_;
    $value =~ /^\d{1,5}$/ or fail "Invalid $label: must be numeric.";
    my $numeric = int($value);
    ($numeric >= 1 && $numeric <= 65535) or fail "Invalid $label: out of range.";
}

sub escape_sed_replacement_pipe_delim {
    my ($str) = @_;
    $str =~ s/[\\&|]/\\$&/g;
    return $str;
}

sub resolve_user_home {
    my ($user) = @_;
    my $home = "";
    if (`which getent 2>/dev/null`) {
        $home = `getent passwd "$user" 2>/dev/null | cut -d: -f6`;
        chomp $home;
    }
    if (!$home && -f "/etc/passwd") {
        $home = `awk -F: -v u="$user" '\$1==u {print \$6}' /etc/passwd 2>/dev/null`;
        chomp $home;
    }
    if (!$home) {
        $home = "/home/$user";
    }
    return $home;
}

sub generate_token_hex_32 {
    if (`which openssl 2>/dev/null`) {
        my $token = `openssl rand -hex 32`;
        chomp $token;
        return $token;
    }
    if (`which python3 2>/dev/null`) {
        my $token = `python3 -c 'import secrets; print(secrets.token_hex(32))'`;
        chomp $token;
        return $token;
    }
    if (`which od 2>/dev/null`) {
        my $token = `od -An -N32 -tx1 /dev/urandom | tr -d " \\n"`;
        chomp $token;
        return $token;
    }
    warn "Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN.\n";
    exit 1;
}

sub seed_local_control_ui_origins {
    my ($file, $port) = @_;
    ensure_safe_write_file_path("config file", $file);
    unless (`which python3 2>/dev/null`) {
        warn "Warning: python3 not found; unable to seed gateway.controlUi.allowedOrigins in $file.\n";
        return;
    }
    my ($volume, $directories) = File::Spec->splitpath($file);
    my @dirs = File::Spec->splitdir($directories);
    pop @dirs;
    my $dir = File::Spec->catdir($volume, @dirs);
    my $tmp = File::Spec->catfile($dir, ".config.tmp." . int(rand(100000)));
    
    my $python_code = <<'PYTHON';
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
        f"Warning: unable to seed gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.",
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
        host_port = normalized[len("http://") :]
        host = host_port.split(":", 1)[0]
        if host in managed_localhosts:
            continue
    cleaned.append(normalized)
control_ui["allowedOrigins"] = cleaned + desired
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\\n")
PYTHON
    
    open(my $fh, '>', '/tmp/python_seed.py') or die "Cannot create python script: $!";
    print $fh $python_code;
    close $fh;
    
    my $result = system("python3 /tmp/python_seed.py '$file' '$port' '$tmp'");
    unlink('/tmp/python_seed.py');
    
    if ($result != 0) {
        unlink($tmp);
        return;
    }
    
    if (!-s $tmp) {
        unlink($tmp);
        return;
    }
    
    chmod(0600, $tmp) or warn "Cannot chmod temporary file: $!";
    rename($tmp, $file) or die "Cannot move temporary file: $!";
}

sub upsert_env_var {
    my ($file, $key, $value) = @_;
    ensure_safe_write_file_path("env file", $file);
    my ($volume, $directories) = File::Spec->splitpath($file);
    my @dirs = File::Spec->splitdir($directories);
    pop @dirs;
    my $dir = File::Spec->catdir($volume, @dirs);
    my $tmp = File::Spec->catfile($dir, ".env.tmp." . int(rand(100000)));
    
    my @lines = ();
    if (-f $file) {
        open(my $fh, '<', $file) or die "Cannot read env file: $!";
        while (my $line = <$fh>) {
            chomp $line;
            push @lines, $line;
        }
        close $fh;
    }
    
    my $found = 0;
    my @new_lines = ();
    for my $line (@lines) {
        if ($line =~ /^$key=/) {
            push @new_lines, "$key=$value";
            $found = 1;
        } else {
            push @new_lines, $line;
        }
    }
    
    unless ($found) {
        push @new_lines, "$key=$value";
    }
    
    open(my $fh, '>', $tmp) or die "Cannot create temporary env file: $!";
    for my $line (@new_lines) {
        print $fh "$line\n";
    }
    close $fh;
    
    rename($tmp, $file) or die "Cannot move temporary env file: $!";
    chmod(0600, $file) or warn "Cannot chmod env file: $!";
}

my $install_quadlet = 0;
for my $arg (@ARGV) {
    if ($arg eq "--quadlet") {
        $install_quadlet = 1;
    } elsif ($arg eq "--container") {
        $install_quadlet = 0;
    }
}

if (exists $ENV{'OPENCLAW_PODMAN_QUADLET'}) {
    my $val = lc($ENV{'OPENCLAW_PODMAN_QUADLET'});
    if ($val eq "1" || $val eq "yes" || $val eq "true") {
        $install_quadlet = 1;
    } elsif ($val eq "0" || $val eq "no" || $val eq "false") {
        $install_quadlet = 0;
    }
}

if ($install_quadlet && $platform_name ne "Linux") {
    fail "--quadlet is only supported on Linux with systemd user services.";
}

my $seed_gateway_port = $host_gateway_port;
if ($install_quadlet) {
    $seed_gateway_port = $quadlet_gateway_port;
}

require_cmd("podman");
if (is_root()) {
    warn "Run scripts/podman/setup.sh as your normal user so Podman stays rootless.\n";
    exit 1;
}

if ($openclaw_image eq "openclaw:local" && !-f File::Spec->catfile($repo_path, "Dockerfile")) {
    warn "Dockerfile not found at $repo_path. Set OPENCLAW_REPO_PATH to the repo root.\n";
    exit 1;
}

if (!-f $run_script_src) {
    warn "Launch script not found at $run_script_src.\n";
    exit 1;
}

if (!$openclaw_home) {
    $openclaw_home = resolve_user_home($openclaw_user);
}

if (!$openclaw_home) {
    warn "Unable to resolve HOME for user $openclaw_user.\n";
    exit 1;
}

if (!$openclaw_config_dir) {
    $openclaw_config_dir = File::Spec->catdir($openclaw_home, ".openclaw");
}

if (!$openclaw_workspace_dir) {
    $openclaw_workspace_dir = File::Spec->catdir($openclaw_config_dir, "workspace");
}

validate_absolute_path("home directory", $openclaw_home);
validate_mount_source_path("config directory", $openclaw_config_dir);
validate_mount_source_path("workspace directory", $openclaw_workspace_dir);
validate_container_name($openclaw_container_name);
validate_image_name($openclaw_image);
validate_port("gateway host port", $host_gateway_port);
validate_port("seed gateway port", $seed_gateway_port);

system("install -d -m 700 '$openclaw_config_dir' '$openclaw_workspace_dir'") == 0
    or die "Failed to create directories\n";

ensure_private_existing_dir_owned_by_user("config directory", $openclaw_config_dir);
ensure_private_existing_dir_owned_by_user("workspace directory", $openclaw_workspace_dir);

my @build_args = ();
if ($ENV{'OPENCLAW_DOCKER_APT_PACKAGES'}) {
    push @build_args, "--build-arg", "OPENCLAW_DOCKER_APT_PACKAGES=" . $ENV{'OPENCLAW_DOCKER_APT_PACKAGES'};
}
if ($ENV{'OPENCLAW_EXTENSIONS'}) {
    push @build_args, "--build-arg", "OPENCLAW_EXTENSIONS=" . $ENV{'OPENCLAW_EXTENSIONS'};
}

if ($openclaw_image eq "openclaw:local") {
    print "Building image $openclaw_image ...\n";
    system("podman build -t '$openclaw_image' -f '" . File::Spec->catfile($repo_path, "Dockerfile") . "' " . join(" ", map { "'$_'" } @build_args) . " '$repo_path'") == 0
        or die "Failed to build image\n";
} else {
    if (system("podman image exists '$openclaw_image' >/dev/null 2>&1") == 0) {
        print "Using existing image $openclaw_image\n";
    } else {
        print "Pulling image $openclaw_image ...\n";
        system("podman pull '$openclaw_image'") == 0 or die "Failed to pull image\n";
    }
}

my $env_file = File::Spec->catfile($openclaw_config_dir, ".env");
if (!-f $env_file) {
    my $token = generate_token_hex_32();
    my $content = "OPENCLAW_GATEWAY_TOKEN=$token\n";
    write_file_atomically($env_file, "600", $content);
    print "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to $env_file\n";
}

upsert_env_var($env_file, "OPENCLAW_PODMAN_CONTAINER", $openclaw_container_name);
upsert_env_var($env_file, "OPENCLAW_PODMAN_IMAGE", $openclaw_image);

my $config_json = File::Spec->catfile($openclaw_config_dir, "openclaw.json");
if (!-f $config_json) {
    my $content = <<JSON;
{
  "gateway": {
    "mode": "local",
        "controlUi": {
          "allowedOrigins": [
        "http://127.0.0.1:${seed_gateway_port}",
        "http://localhost:${seed_gateway_port}"
      ]
    }
  }
}
JSON
    write_file_atomically($config_json, "600", $content);
    print "Wrote minimal config to $config_json\n";
}

seed_local_control_ui_origins($config_json, $seed_gateway_port);

if ($install_quadlet) {
    my $quadlet_dir = File::Spec->catdir($openclaw_home, ".config", "containers", "systemd");
    my $quadlet_dst = File::Spec->catfile($quadlet_dir, "openclaw.container");
    print "Installing Quadlet to $quadlet_dst ...\n";
    system("mkdir -p '$quadlet_dir'") == 0 or die "Failed to create quadlet directory\n";
    ensure_safe_existing_dir("quadlet directory", $quadlet_dir);
    
    my $openclaw_home_escaped = escape_sed_replacement_pipe_delim($openclaw_home);
    my $openclaw_config_escaped = escape_sed_replacement_pipe_delim($openclaw_config_dir);
    my $openclaw_workspace_escaped = escape_sed_replacement_pipe_delim($openclaw_workspace_dir);
    my $openclaw_image_escaped = escape_sed_replacement_pipe_delim($openclaw_image);
    my $openclaw_container_escaped = escape_sed_replacement_pipe_delim($openclaw_container_name);
    
    my $template_content = do {
        open(my $fh, '<', $quadlet_template) or die "Cannot read template: $!";
        local $/;
        my $content = <$fh>;
        close $fh;
        $content;
    };
    
    $template_content =~ s|\{\{OPENCLAW_HOME\}\}|$openclaw_home_escaped|g;
    $template_content =~ s|\{\{OPENCLAW_CONFIG_DIR\}\}|$openclaw_config_escaped|g;
    $template_content =~ s|\{\{OPENCLAW_WORKSPACE_DIR\}\}|$openclaw_workspace_escaped|g;
    $template_content =~ s|\{\{IMAGE_NAME\}\}|$openclaw_image_escaped|g;
    $template_content =~ s|\{\{CONTAINER_NAME\}\}|$openclaw_container_escaped|g;
    
    write_file_atomically($quadlet_dst, "644", $template_content);
    
    if (`which systemctl 2>/dev/null`) {
        print "Reloading and starting user service...\n";
        if (system("systemctl --user daemon-reload") == 0 && system("systemctl --user start openclaw.service") == 0) {
            print "Quadlet installed and service started.\n";
        } else {
            warn "Quadlet installed, but automatic start failed.\n";
            warn "Try: systemctl --user daemon-reload && systemctl --user start openclaw.service\n";
            if (`which loginctl 2>/dev/null`) {
                warn "For boot persistence on headless hosts, you may also need: sudo loginctl enable-linger " . getpwuid($<) . "\n";
            }
        }
    } else {
        warn "systemctl not found; Quadlet installed but not started.\n";
    }
} else {
    print "Container setup complete.\n";
}

print "\n";
print "Next:\n";
print "  ./scripts/run-openclaw-podman.sh launch\n";
print "  ./scripts/run-openclaw-podman.sh launch setup\n";
print "  openclaw --container $openclaw_container_name dashboard --no-open\n";
