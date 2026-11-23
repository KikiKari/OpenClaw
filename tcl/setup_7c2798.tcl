#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "3045c43bec161fa51fe3e3a0860a5f2e313290793ae14fb7288e3e1d21e54660", "source_sha256": "7c279836c2c2bf7bf1f0cd8868a320423a0e69387a65cec698db01e1d888a57a", "target_language": "tcl"}
# setup.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

proc fail {msg} {
    puts stderr "ERROR: $msg"
    exit 1
}

proc require_cmd {cmd} {
    if {[catch {exec which $cmd}]} {
        puts stderr "Missing dependency: $cmd"
        exit 1
    }
}

proc run_docker_build {args} {
    set env(DOCKER_BUILDKIT) 1
    if {[catch {exec docker build {*}$args} result]} {
        fail "docker build failed: $result"
    }
    return $result
}

proc is_truthy_value {raw} {
    set raw [string tolower [string trim $raw]]
    switch -exact -- $raw {
        1 - true - yes - on {
            return 1
        }
        default {
            return 0
        }
    }
}

proc read_config_gateway_token {} {
    global OPENCLAW_CONFIG_DIR
    set config_path [file join $OPENCLAW_CONFIG_DIR openclaw.json]
    if {![file exists $config_path]} {
        return
    }
    
    if {[catch {exec which python3}]} {
        set python_script {
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
        }
        
        if {[catch {exec python3 << $python_script $config_path} result]} {
            return
        }
        return $result
    }
    
    if {[catch {exec which node}]} {
        set node_script {
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
        }
        
        if {[catch {exec node << $node_script $config_path} result]} {
            return
        }
        return $result
    }
}

proc read_env_gateway_token {env_path} {
    if {![file exists $env_path]} {
        return
    }
    
    set fh [open $env_path r]
    set token ""
    while {[gets $fh line] >= 0} {
        set line [string trimright $line "\r"]
        if {[string match "OPENCLAW_GATEWAY_TOKEN=*" $line]} {
            set token [string range $line 22 end]
        }
    }
    close $fh
    
    if {$token ne ""} {
        return $token
    }
}

proc sync_gateway_config {} {
    global OPENCLAW_GATEWAY_BIND OPENCLAW_GATEWAY_PORT
    
    set allowed_origin_json ""
    set current_allowed_origins ""
    
    if {$OPENCLAW_GATEWAY_BIND ne "loopback"} {
        set allowed_origin_json [format {["http://localhost:%s","http://127.0.0.1:%s"]} $OPENCLAW_GATEWAY_PORT $OPENCLAW_GATEWAY_PORT]
        if {[catch {run_prestart_cli config get gateway.controlUi.allowedOrigins} current_allowed_origins]} {
            set current_allowed_origins ""
        }
        set current_allowed_origins [string map {"\r" ""} $current_allowed_origins]
    }
    
    set batch_json [format {{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"%s"}} $OPENCLAW_GATEWAY_BIND]
    
    if {$allowed_origin_json ne ""} {
        if {$current_allowed_origins ne "" && $current_allowed_origins ne "null" && $current_allowed_origins ne "[]"} {
            puts "Control UI allowlist already configured; leaving gateway.controlUi.allowedOrigins unchanged."
        } else {
            append batch_json ",{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":$allowed_origin_json}"
        }
    }
    
    set batch_json "\[$batch_json\]"
    
    if {[catch {run_prestart_cli config set --batch-json $batch_json}]} {
        fail "Failed to set gateway config"
    }
    
    puts "Pinned gateway.mode=local and gateway.bind=$OPENCLAW_GATEWAY_BIND for Docker setup."
    if {$allowed_origin_json ne ""} {
        if {$current_allowed_origins eq "" || $current_allowed_origins eq "null" || $current_allowed_origins eq "[]"} {
            puts "Set gateway.controlUi.allowedOrigins to $allowed_origin_json for non-loopback bind."
        }
    }
}

proc run_prestart_gateway {args} {
    global COMPOSE_ARGS
    if {[catch {exec docker compose {*}$COMPOSE_ARGS run --rm --no-deps {*}$args} result]} {
        error "docker compose run failed: $result"
    }
    return $result
}

proc run_prestart_cli {args} {
    set cmd [list run --rm --entrypoint node openclaw-gateway dist/index.js {*}$args]
    return [run_prestart_gateway {*}$cmd]
}

proc run_runtime_cli {compose_scope deps_mode args} {
    global COMPOSE_ARGS BASE_COMPOSE_ARGS
    
    set compose_args {}
    set run_args [list run --rm]
    
    switch -exact -- $compose_scope {
        current {
            set compose_args $COMPOSE_ARGS
        }
        base {
            set compose_args $BASE_COMPOSE_ARGS
        }
        default {
            fail "Unknown runtime CLI compose scope: $compose_scope"
        }
    }
    
    switch -exact -- $deps_mode {
        with-deps {}
        no-deps {
            lappend run_args --no-deps
        }
        default {
            fail "Unknown runtime CLI deps mode: $deps_mode"
        }
    }
    
    if {[catch {exec docker compose {*}$compose_args {*}$run_args openclaw-cli {*}$args} result]} {
        error "docker compose run failed: $result"
    }
    return $result
}

proc contains_disallowed_chars {value} {
    return [regexp {\n|\r|\t} $value]
}

proc is_valid_timezone {value} {
    set path "/usr/share/zoneinfo/$value"
    return [file exists $path] && ![file isdirectory $path]
}

proc validate_mount_path_value {label value} {
    if {$value eq ""} {
        fail "$label cannot be empty."
    }
    if {[contains_disallowed_chars $value]} {
        fail "$label contains unsupported control characters."
    }
    if {[regexp {\s} $value]} {
        fail "$label cannot contain whitespace."
    }
}

proc validate_named_volume {value} {
    if {![regexp {^[A-Za-z0-9][A-Za-z0-9_.-]*$} $value]} {
        fail "OPENCLAW_HOME_VOLUME must match \[A-Za-z0-9\]\[A-Za-z0-9_.-\]* when using a named volume."
    }
}

proc validate_mount_spec {mount} {
    if {[contains_disallowed_chars $mount]} {
        fail "OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters."
    }
    if {![regexp {^[^[:space:],:]+:[^[:space:],:]+(:[^[:space:],:]+)?$} $mount]} {
        fail "Invalid mount format '$mount'. Expected source:target\[:options\] without spaces."
    }
}

# Main execution starts here

# Get root directory
set script_dir [file dirname [info script]]
set ROOT_DIR [file normalize [file join $script_dir ../..]]
set COMPOSE_FILE [file join $ROOT_DIR docker-compose.yml]
set EXTRA_COMPOSE_FILE [file join $ROOT_DIR docker-compose.extra.yml]

# Environment variables with defaults
set IMAGE_NAME [expr {[info exists ::env(OPENCLAW_IMAGE)] ? $::env(OPENCLAW_IMAGE) : "openclaw:local"}]
set EXTRA_MOUNTS [expr {[info exists ::env(OPENCLAW_EXTRA_MOUNTS)] ? $::env(OPENCLAW_EXTRA_MOUNTS) : ""}]
set HOME_VOLUME_NAME [expr {[info exists ::env(OPENCLAW_HOME_VOLUME)] ? $::env(OPENCLAW_HOME_VOLUME) : ""}]
set RAW_SANDBOX_SETTING [expr {[info exists ::env(OPENCLAW_SANDBOX)] ? $::env(OPENCLAW_SANDBOX) : ""}]
set DOCKER_SOCKET_PATH [expr {[info exists ::env(OPENCLAW_DOCKER_SOCKET)] ? $::env(OPENCLAW_DOCKER_SOCKET) : ""}]
set TIMEZONE [expr {[info exists ::env(OPENCLAW_TZ)] ? $::env(OPENCLAW_TZ) : ""}]

# Set SANDBOX_ENABLED based on truthy value
set SANDBOX_ENABLED [is_truthy_value $RAW_SANDBOX_SETTING]

# Handle DOCKER_HOST for socket path
if {$DOCKER_SOCKET_PATH eq "" && [info exists ::env(DOCKER_HOST)] && [string match "unix://*" $::env(DOCKER_HOST)]} {
    set DOCKER_SOCKET_PATH [string range $::env(DOCKER_HOST) 7 end]
}
if {$DOCKER_SOCKET_PATH eq ""} {
    set DOCKER_SOCKET_PATH "/var/run/docker.sock"
}

# Set config and workspace directories
set OPENCLAW_CONFIG_DIR [expr {[info exists ::env(OPENCLAW_CONFIG_DIR)] ? $::env(OPENCLAW_CONFIG_DIR) : [file join $::env(HOME) .openclaw]}]
set OPENCLAW_WORKSPACE_DIR [expr {[info exists ::env(OPENCLAW_WORKSPACE_DIR)] ? $::env(OPENCLAW_WORKSPACE_DIR) : [file join $::env(HOME) .openclaw workspace]}]

# Validate paths
validate_mount_path_value "OPENCLAW_CONFIG_DIR" $OPENCLAW_CONFIG_DIR
validate_mount_path_value "OPENCLAW_WORKSPACE_DIR" $OPENCLAW_WORKSPACE_DIR
if {$HOME_VOLUME_NAME ne ""} {
    if {[string match "*/*" $HOME_VOLUME_NAME]} {
        validate_mount_path_value "OPENCLAW_HOME_VOLUME" $HOME_VOLUME_NAME
    } else {
        validate_named_volume $HOME_VOLUME_NAME
    }
}
if {[contains_disallowed_chars $EXTRA_MOUNTS]} {
    fail "OPENCLAW_EXTRA_MOUNTS cannot contain control characters."
}
if {$SANDBOX_ENABLED ne ""} {
    validate_mount_path_value "OPENCLAW_DOCKER_SOCKET" $DOCKER_SOCKET_PATH
}
if {$TIMEZONE ne ""} {
    if {[contains_disallowed_chars $TIMEZONE]} {
        fail "OPENCLAW_TZ contains unsupported control characters."
    }
    if {![regexp {^[A-Za-z0-9/_+-]+$} $TIMEZONE]} {
        fail "OPENCLAW_TZ must be a valid IANA timezone string (e.g. Asia/Shanghai)."
    }
    if {![is_valid_timezone $TIMEZONE]} {
        fail "OPENCLAW_TZ must match a timezone in /usr/share/zoneinfo (e.g. Asia/Shanghai)."
    }
}

# Create directories
file mkdir $OPENCLAW_CONFIG_DIR
file mkdir $OPENCLAW_WORKSPACE_DIR
file mkdir [file join $OPENCLAW_CONFIG_DIR identity]
file mkdir [file join $OPENCLAW_CONFIG_DIR agents main agent]
file mkdir [file join $OPENCLAW_CONFIG_DIR agents main sessions]

# Export environment variables
set ::env(OPENCLAW_CONFIG_DIR) $OPENCLAW_CONFIG_DIR
set ::env(OPENCLAW_WORKSPACE_DIR) $OPENCLAW_WORKSPACE_DIR
set ::env(OPENCLAW_GATEWAY_PORT) [expr {[info exists ::env(OPENCLAW_GATEWAY_PORT)] ? $::env(OPENCLAW_GATEWAY_PORT) : "18789"}]
set ::env(OPENCLAW_BRIDGE_PORT) [expr {[info exists ::env(OPENCLAW_BRIDGE_PORT)] ? $::env(OPENCLAW_BRIDGE_PORT) : "18790"}]
set ::env(OPENCLAW_GATEWAY_BIND) [expr {[info exists ::env(OPENCLAW_GATEWAY_BIND)] ? $::env(OPENCLAW_GATEWAY_BIND) : "lan"}]
set ::env(OPENCLAW_IMAGE) $IMAGE_NAME
set ::env(OPENCLAW_DOCKER_APT_PACKAGES) [expr {[info exists ::env(OPENCLAW_DOCKER_APT_PACKAGES)] ? $::env(OPENCLAW_DOCKER_APT_PACKAGES) : ""}]
set ::env(OPENCLAW_EXTENSIONS) [expr {[info exists ::env(OPENCLAW_EXTENSIONS)] ? $::env(OPENCLAW_EXTENSIONS) : ""}]
set ::env(OPENCLAW_EXTRA_MOUNTS) $EXTRA_MOUNTS
set ::env(OPENCLAW_HOME_VOLUME) $HOME_VOLUME_NAME
set ::env(OPENCLAW_ALLOW_INSECURE_PRIVATE_WS) [expr {[info exists ::env(OPENCLAW_ALLOW_INSECURE_PRIVATE_WS)] ? $::env(OPENCLAW_ALLOW_INSECURE_PRIVATE_WS) : ""}]
set ::env(OPENCLAW_SANDBOX) $SANDBOX_ENABLED
set ::env(OPENCLAW_DOCKER_SOCKET) $DOCKER_SOCKET_PATH
set ::env(OPENCLAW_TZ) $TIMEZONE

# Detect Docker socket GID
set DOCKER_GID ""
if {$SANDBOX_ENABLED ne "" && [file exists $DOCKER_SOCKET_PATH] && [file type $DOCKER_SOCKET_PATH] eq "socket"} {
    if {[catch {exec stat -c {%g} $DOCKER_SOCKET_PATH} gid_result] || $gid_result eq ""} {
        if {[catch {exec stat -f {%g} $DOCKER_SOCKET_PATH} gid_result] || $gid_result eq ""} {
            set gid_result ""
        }
    }
    set DOCKER_GID $gid_result
}
set ::env(DOCKER_GID) $DOCKER_GID

# Handle gateway token
if {![info exists ::env(OPENCLAW_GATEWAY_TOKEN)] || $::env(OPENCLAW_GATEWAY_TOKEN) eq ""} {
    set EXISTING_CONFIG_TOKEN [read_config_gateway_token]
    if {$EXISTING_CONFIG_TOKEN ne ""} {
        set ::env(OPENCLAW_GATEWAY_TOKEN) $EXISTING_CONFIG_TOKEN
        puts "Reusing gateway token from $OPENCLAW_CONFIG_DIR/openclaw.json"
    } else {
        set DOTENV_GATEWAY_TOKEN [read_env_gateway_token [file join $ROOT_DIR .env]]
        if {$DOTENV_GATEWAY_TOKEN ne ""} {
            set ::env(OPENCLAW_GATEWAY_TOKEN) $DOTENV_GATEWAY_TOKEN
            puts "Reusing gateway token from $ROOT_DIR/.env"
        } elseif {![catch {exec which openssl}]} {
            set ::env(OPENCLAW_GATEWAY_TOKEN) [exec openssl rand -hex 32]
        } else {
            set python_script {
import secrets
print(secrets.token_hex(32))
            }
            set ::env(OPENCLAW_GATEWAY_TOKEN) [exec python3 << $python_script]
        }
    }
}

# Setup compose files
set COMPOSE_FILES [list $COMPOSE_FILE]
set COMPOSE_ARGS {}

proc write_extra_compose {home_volume args} {
    global EXTRA_COMPOSE_FILE OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE_DIR
    
    set fh [open $EXTRA_COMPOSE_FILE w]
    
    puts $fh {services:
  openclaw-gateway:
    volumes:}
    
    if {$home_volume ne ""} {
        set gateway_home_mount "${home_volume}:/home/node"
        set gateway_config_mount "${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw"
        set gateway_workspace_mount "${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace"
        validate_mount_spec $gateway_home_mount
        validate_mount_spec $gateway_config_mount
        validate_mount_spec $gateway_workspace_mount
        puts $fh "      - $gateway_home_mount"
        puts $fh "      - $gateway_config_mount"
        puts $fh "      - $gateway_workspace_mount"
    }
    
    foreach mount $args {
        validate_mount_spec $mount
        puts $fh "      - $mount"
    }
    
    puts $fh {  openclaw-cli:
    volumes:}
    
    if {$home_volume ne ""} {
        puts $fh "      - $gateway_home_mount"
        puts $fh "      - $gateway_config_mount"
        puts $fh "      - $gateway_workspace_mount"
    }
    
    foreach mount $args {
        validate_mount_spec $mount
        puts $fh "      - $mount"
    }
    
    if {$home_volume ne "" && ![string match "*/*" $home_volume]} {
        validate_named_volume $home_volume
        puts $fh "volumes:\n  ${home_volume}:"
    }
    
    close $fh
}

# When sandbox is requested, ensure Docker CLI build arg is set for local builds.
if {$SANDBOX_ENABLED ne ""} {
    if {![info exists ::env(OPENCLAW_INSTALL_DOCKER_CLI)] || $::env(OPENCLAW_INSTALL_DOCKER_CLI) eq ""} {
        set ::env(OPENCLAW_INSTALL_DOCKER_CLI) 1
    }
}

# Process extra mounts
set VALID_MOUNTS {}
if {$EXTRA_MOUNTS ne ""} {
    set mounts [split $EXTRA_MOUNTS ","]
    foreach mount $mounts {
        set mount [string trim $mount]
        if {$mount ne ""} {
            lappend VALID_MOUNTS $mount
        }
    }
}

if {$HOME_VOLUME_NAME ne "" || [llength $VALID_MOUNTS] > 0} {
    if {[llength $VALID_MOUNTS] > 0} {
        write_extra_compose $HOME_VOLUME_NAME {*}$VALID_MOUNTS
    } else {
        write_extra_compose $HOME_VOLUME_NAME
    }
    lappend COMPOSE_FILES $EXTRA_COMPOSE_FILE
}

foreach compose_file $COMPOSE_FILES {
    lappend COMPOSE_ARGS "-f" $compose_file
}

# Keep a base compose arg set without sandbox overlay
set BASE_COMPOSE_ARGS $COMPOSE_ARGS
set COMPOSE_HINT "docker compose"
foreach compose_file $COMPOSE_FILES {
    append COMPOSE_HINT " -f $compose_file"
}

# Update .env file
set ENV_FILE [file join $ROOT_DIR .env]

proc upsert_env {file keys} {
    global ::env
    
    set tmp_file [exec mktemp]
    
    # Read existing file
    set lines {}
    if {[file exists $file]} {
        set fh [open $file r]
        while {[gets $fh line] >= 0} {
            lappend lines $line
        }
        close $fh
    }
    
    # Process lines and update keys
    set seen {}
    set output_lines {}
    
    foreach line $lines {
        set key [lindex [split $line "="] 0]
        set replaced 0
        
        foreach k $keys {
            if {$key eq $k} {
                if {[info exists ::env($k)]} {
                    lappend output_lines "$k=$::env($k)"
                } else {
                    lappend output_lines "$k="
                }
                lappend seen $k
                set replaced 1
                break
            }
        }
        
        if {!$replaced} {
            lappend output_lines $line
        }
    }
    
    # Add missing keys
    foreach k $keys {
        if {$k ni $seen} {
            if {[info exists ::env($k)]} {
                lappend output_lines "$k=$::env($k)"
            } else {
                lappend output_lines "$k="
            }
        }
    }
    
    # Write to temp file
    set fh [open $tmp_file w]
    foreach line $output_lines {
        puts $fh $line
    }
    close $fh
    
    # Move temp file to target
    file rename -force $tmp_file $file
}

upsert_env $ENV_FILE [list \
    OPENCLAW_CONFIG_DIR \
    OPENCLAW_WORKSPACE_DIR \
    OPENCLAW_GATEWAY_PORT \
    OPENCLAW_BRIDGE_PORT \
    OPENCLAW_GATEWAY_BIND \
    OPENCLAW_GATEWAY_TOKEN \
    OPENCLAW_IMAGE \
    OPENCLAW_EXTRA_MOUNTS \
    OPENCLAW_HOME_VOLUME \
    OPENCLAW_DOCKER_APT_PACKAGES \
    OPENCLAW_EXTENSIONS \
    OPENCLAW_SANDBOX \
    OPENCLAW_DOCKER_SOCKET \
    DOCKER_GID \
    OPENCLAW_INSTALL_DOCKER_CLI \
    OPENCLAW_ALLOW_INSECURE_PRIVATE_WS \
    OPENCLAW_TZ]

# Build or pull image
if {$IMAGE_NAME eq "openclaw:local"} {
    puts "==> Building Docker image: $IMAGE_NAME"
    run_docker_build \
        --build-arg "OPENCLAW_DOCKER_APT_PACKAGES=${::env(OPENCLAW_DOCKER_APT_PACKAGES)}" \
        --build-arg "OPENCLAW_EXTENSIONS=${::env(OPENCLAW_EXTENSIONS)}" \
        --build-arg "OPENCLAW_INSTALL_DOCKER_CLI=${::env(OPENCLAW_INSTALL_DOCKER_CLI)}" \
        -t "$IMAGE_NAME" \
        -f "[file join $ROOT_DIR Dockerfile]" \
        $ROOT_DIR
} else {
    puts "==> Pulling Docker image: $IMAGE_NAME"
    if {[catch {exec docker pull $IMAGE_NAME}]} {
        puts stderr "ERROR: Failed to pull image $IMAGE_NAME. Please check the image name and your access permissions."
        exit 1
    }
}

# Fix permissions
puts ""
puts "==> Fixing data-directory permissions"
if {[catch {run_prestart_gateway --user root --entrypoint sh openclaw-gateway -c {
find /home/node/.openclaw -xdev -exec chown node:node {} +; 
[ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true
}}]} {
    puts stderr "Warning: Could not fix permissions"
}

# Onboarding
puts ""
puts "==> Onboarding (interactive)"
puts "Docker setup pins Gateway mode to local."
puts "Gateway runtime bind comes from OPENCLAW_GATEWAY_BIND (default: lan)."
puts "Current runtime bind: $::env(OPENCLAW_GATEWAY_BIND)"
puts "Gateway token: $::env(OPENCLAW_GATEWAY_TOKEN)"
puts "Tailscale exposure: Off (use host-level tailnet/Tailscale setup separately)."
puts "Install Gateway daemon: No (managed by Docker Compose)"
puts ""

if {[catch {run_prestart_cli onboard --mode local --no-install-daemon}]} {
    puts stderr "Onboarding failed"
}

# Docker gateway defaults
puts ""
puts "==> Docker gateway defaults"
sync_gateway_config

# Provider setup
puts ""
puts "==> Provider setup (optional)"
puts "WhatsApp (QR):"
puts "  ${COMPOSE_HINT} run --rm openclaw-cli channels login"
puts "Telegram (bot token):"
puts "  ${COMPOSE_HINT} run --rm openclaw-cli channels add --channel telegram --token <token>"
puts "Discord (bot token):"
puts "  ${COMPOSE_HINT} run --rm openclaw-cli channels add --channel discord --token <token>"
puts "Docs: https://docs.openclaw.ai/channels"

# Start gateway
puts ""
puts "==> Starting gateway"
if {[catch {exec docker compose {*}$COMPOSE_ARGS up -d openclaw-gateway}]} {
    fail "Failed to start gateway"
}

# Sandbox setup
if {$SANDBOX_ENABLED ne ""} {
    puts ""
    puts "==> Sandbox setup"
    
    # Build sandbox image if Dockerfile.sandbox exists
    set sandbox_file [file join $ROOT_DIR Dockerfile.sandbox]
    if {[file exists $sandbox_file]} {
        puts "Building sandbox image: openclaw-sandbox:bookworm-slim"
        run_docker_build \
            -t "openclaw-sandbox:bookworm-slim" \
            -f $sandbox_file \
            $ROOT_DIR
    } else {
        puts stderr "WARNING: Dockerfile.sandbox not found in $ROOT_DIR"
        puts stderr "  Sandbox config will be applied but no sandbox image will be built."
        puts stderr "  Agent exec may fail if the configured sandbox image does not exist."
    }
    
    # Verify Docker CLI in the running image
    set sandbox_enabled_temp $SANDBOX_ENABLED
    if {[catch {exec docker compose {*}$COMPOSE_ARGS run --rm --entrypoint docker openclaw-gateway --version}]} {
        puts stderr "WARNING: Docker CLI not found inside the container image."
        puts stderr "  Sandbox requires Docker CLI. Rebuild with --build-arg OPENCLAW_INSTALL_DOCKER_CLI=1"
        puts stderr "  or use a local build (OPENCLAW_IMAGE=openclaw:local). Skipping sandbox setup."
        set sandbox_enabled_temp ""
    }
    
    if {$sandbox_enabled_temp ne ""} {
        # Mount Docker socket via a dedicated compose overlay
        if {[file exists $DOCKER_SOCKET_PATH] && [file type $DOCKER_SOCKET_PATH] eq "socket"} {
            set SANDBOX_COMPOSE_FILE [file join $ROOT_DIR docker-compose.sandbox.yml]
            set fh [open $SANDBOX_COMPOSE_FILE w]
            puts $fh "services:\n  openclaw-gateway:\n    volumes:\n      - ${DOCKER_SOCKET_PATH}:/var/run/docker.sock"
            if {$DOCKER_GID ne ""} {
                puts $fh "    group_add:\n      - \"${DOCKER_GID}\""
            }
            close $fh
            
            lappend COMPOSE_ARGS "-f" $SANDBOX_COMPOSE_FILE
            puts "==> Sandbox: added Docker socket mount"
        } else {
            puts stderr "WARNING: OPENCLAW_SANDBOX enabled but Docker socket not found at $DOCKER_SOCKET_PATH."
            puts stderr "  Sandbox requires Docker socket access. Skipping sandbox setup."
            set sandbox_enabled_temp ""
        }
    }
    
    if {$sandbox_enabled_temp ne ""} {
        # Enable sandbox in OpenClaw config
        set sandbox_config_ok 1
        if {[catch {run_runtime_cli current no-deps config set agents.defaults.sandbox.mode "non-main"}]} {
            puts stderr "WARNING: Failed to set agents.defaults.sandbox.mode"
            set sandbox_config_ok 0
        }
        if {[catch {run_runtime_cli current no-deps config set agents.defaults.sandbox.scope "agent"}]} {
            puts stderr "WARNING: Failed to set agents.defaults.sandbox.scope"
            set sandbox_config_ok 0
        }
        if {[catch {run_runtime_cli current no-deps config set agents.defaults.sandbox.workspaceAccess "none"}]} {
            puts stderr "WARNING: Failed to set agents.defaults.sandbox.workspaceAccess"
            set sandbox_config_ok 0
        }
        
        if {$sandbox_config_ok} {
            puts "Sandbox enabled: mode=non-main, scope=agent, workspaceAccess=none"
            puts "Docs: https://docs.openclaw.ai/gateway/sandboxing"
            # Restart gateway with sandbox compose overlay
            if {[catch {exec docker compose {*}$COMPOSE_ARGS up -d openclaw-gateway}]} {
                puts stderr "Failed to restart gateway with sandbox"
            }
        } else {
            puts stderr "WARNING: Sandbox config was partially applied. Check errors above."
            puts stderr "  Skipping gateway restart to avoid exposing Docker socket without a full sandbox policy."
            
            if {[catch {run_runtime_cli base no-deps config set agents.defaults.sandbox.mode "off"}]} {
                puts stderr "WARNING: Failed to roll back agents.defaults.sandbox.mode to off"
            } else {
                puts "Sandbox mode rolled back to off due to partial sandbox config failure."
            }
            
            if {[info exists SANDBOX_COMPOSE_FILE] && [file exists $SANDBOX_COMPOSE_FILE]} {
                file delete $SANDBOX_COMPOSE_FILE
            }
            
            # Reset gateway service definition
            if {[catch {exec docker compose {*}$BASE_COMPOSE_ARGS up -d --force-recreate openclaw-gateway}]} {
                puts stderr "Failed to recreate gateway without sandbox"
            }
        }
    } else {
        # Reset persisted sandbox mode
        if {[catch {run_runtime_cli current with-deps config set agents.defaults.sandbox.mode "off"}]} {
            puts stderr "WARNING: Failed to reset agents.defaults.sandbox.mode to off"
        }
        set sandbox_file [file join $ROOT_DIR docker-compose.sandbox.yml]
        if {[file exists $sandbox_file]} {
            file delete $sandbox_file
        }
    }
}

puts ""
puts "Gateway running with host port mapping."
puts "Access from tailnet devices via the host's tailnet IP."
puts "Config: $OPENCLAW_CONFIG_DIR"
puts "Workspace: $OPENCLAW_WORKSPACE_DIR"
puts "Token: $::env(OPENCLAW_GATEWAY_TOKEN)"
puts ""
puts "Commands:"
puts "  ${COMPOSE_HINT} logs -f openclaw-gateway"
puts "  ${COMPOSE_HINT} exec openclaw-gateway node dist/index.js health --token \"$::env(OPENCLAW_GATEWAY_TOKEN)\""
