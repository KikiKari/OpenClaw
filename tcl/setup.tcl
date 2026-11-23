#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "3da974a815b2bcd5a7785b0137078b4aa04b64ea9b4ac8d582c42152bb05e9c1", "source_sha256": "53a6908a18055c2a46b63b5da3ddbf4ea5f6b1867c1482c1dcc8903c3ab7b89a", "target_language": "tcl"}
# setup.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/podman/setup.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# One-time host setup for rootless OpenClaw in Podman. Uses the current
# non-root user throughout, builds or pulls the image into that user's Podman
# store, writes config under ~/.openclaw by default, and uses the repo-local
# launch script at ./scripts/run-openclaw-podman.sh.
#
# Usage: ./scripts/podman/setup.tcl [--quadlet|--container]
#   --quadlet   Install a Podman Quadlet as the current user's systemd service
#   --container Only install image + config; you start the container manually (default)
#   Or set OPENCLAW_PODMAN_QUADLET=1 (or 0) to choose without a flag.
#
# After this, start the gateway manually:
#   ./scripts/run-openclaw-podman.sh launch
#   ./scripts/run-openclaw-podman.sh launch setup
# Or, if you used --quadlet:
#   systemctl --user start openclaw.service

package require Tcl 8.6

# Global variables
set REPO_PATH [expr {[info exists ::env(OPENCLAW_REPO_PATH)] ? $::env(OPENCLAW_REPO_PATH) : [file normalize [file join [file dirname [file dirname [info script]]] .. ..]]}]
set RUN_SCRIPT_SRC [file join $REPO_PATH scripts run-openclaw-podman.sh]
set QUADLET_TEMPLATE [file join $REPO_PATH scripts podman openclaw.container.in]
set OPENCLAW_USER [exec id -un]
set OPENCLAW_HOME [expr {[info exists ::env(HOME)] ? $::env(HOME) : ""}]
set OPENCLAW_CONFIG_DIR [expr {[info exists ::env(OPENCLAW_CONFIG_DIR)] ? $::env(OPENCLAW_CONFIG_DIR) : ""}]
set OPENCLAW_WORKSPACE_DIR [expr {[info exists ::env(OPENCLAW_WORKSPACE_DIR)] ? $::env(OPENCLAW_WORKSPACE_DIR) : ""}]
set OPENCLAW_IMAGE [expr {[info exists ::env(OPENCLAW_PODMAN_IMAGE)] ? $::env(OPENCLAW_PODMAN_IMAGE) : ([info exists ::env(OPENCLAW_IMAGE)] ? $::env(OPENCLAW_IMAGE) : "openclaw:local")}]
set OPENCLAW_CONTAINER_NAME [expr {[info exists ::env(OPENCLAW_PODMAN_CONTAINER)] ? $::env(OPENCLAW_PODMAN_CONTAINER) : "openclaw"}]
set PLATFORM_NAME [exec uname -s]
set HOST_GATEWAY_PORT [expr {[info exists ::env(OPENCLAW_PODMAN_GATEWAY_HOST_PORT)] ? $::env(OPENCLAW_PODMAN_GATEWAY_HOST_PORT) : ([info exists ::env(OPENCLAW_GATEWAY_PORT)] ? $::env(OPENCLAW_GATEWAY_PORT) : "18789")}]
set QUADLET_GATEWAY_PORT "18789"

proc require_cmd {cmd} {
    if {[catch {exec which $cmd}]} {
        puts stderr "Missing dependency: $cmd"
        exit 1
    }
}

proc is_root {} {
    return [expr {[exec id -u] == 0}]
}

proc fail {msg} {
    puts stderr $msg
    exit 1
}

proc validate_single_line_value {label value} {
    if {[string match "*\n*" $value] || [string match "*\r*" $value]} {
        fail "Invalid $label: control characters are not allowed."
    }
}

proc validate_absolute_path {label value} {
    validate_single_line_value $label $value
    if {![string match "/*" $value]} {
        fail "Invalid $label: expected an absolute path."
    }
    if {[string match "*//*" $value]} {
        fail "Invalid $label: repeated slashes are not allowed."
    }
    if {[string match "*./.*" $value] || [string match "*/." $value] || [string match "*../.*" $value] || [string match "*/.." $value]} {
        fail "Invalid $label: dot path segments are not allowed."
    }
}

proc validate_mount_source_path {label value} {
    validate_absolute_path $label $value
    if {[string match "*:*" $value]} {
        fail "Invalid $label: ':' is not allowed in Podman bind-mount source paths."
    }
}

proc validate_container_name {value} {
    validate_single_line_value "container name" $value
    if {![regexp {^[A-Za-z0-9][A-Za-z0-9_.-]*$} $value]} {
        fail "Invalid container name: $value"
    }
}

proc validate_image_name {value} {
    validate_single_line_value "image name" $value
    set transport_prefixes {oci-archive: docker-archive: dir: oci: containers-storage: docker-daemon: archive:}
    foreach prefix $transport_prefixes {
        if {[string match "${prefix}*" $value]} {
            fail "Invalid image name: transport prefixes are not allowed: $value"
        }
    }
    if {![regexp {^[A-Za-z0-9][A-Za-z0-9._/:@-]*$} $value]} {
        fail "Invalid image name: $value"
    }
}

proc ensure_safe_existing_dir {label dir} {
    validate_absolute_path $label $dir
    if {![file isdirectory $dir]} {
        fail "Missing $label: $dir"
    }
    if {[file type $dir] eq "link"} {
        fail "Unsafe $label: symlinks are not allowed ($dir)"
    }
}

proc stat_uid {path} {
    if {[catch {exec stat -f %u $path} result]} {
        set result [exec stat -Lc %u $path]
    }
    return $result
}

proc stat_mode {path} {
    if {[catch {exec stat -f %Lp $path} result]} {
        set result [exec stat -Lc %a $path]
    }
    return $result
}

proc ensure_private_existing_dir_owned_by_user {label dir} {
    ensure_safe_existing_dir $label $dir
    set uid [stat_uid $dir]
    if {$uid ne [exec id -u]} {
        fail "Unsafe $label: not owned by current user ($dir)"
    }
    set mode [stat_mode $dir]
    if {([scan $mode %o] & 0022) != 0} {
        fail "Unsafe $label: group/other writable ($dir)"
    }
}

proc ensure_safe_write_file_path {label file} {
    validate_absolute_path $label $file
    if {[file exists $file]} {
        if {[file type $file] eq "link"} {
            fail "Unsafe $label: symlinks are not allowed ($file)"
        }
        if {![file isfile $file]} {
            fail "Unsafe $label: expected a regular file ($file)"
        }
    }
    set dir [file dirname $file]
    ensure_safe_existing_dir "${label} parent directory" $dir
}

proc write_file_atomically {file mode content} {
    ensure_safe_write_file_path "output file" $file
    set dir [file dirname $file]
    set tmp [exec mktemp "$dir/.tmp.XXXXXX"]
    set fh [open $tmp w]
    puts -nonewline $fh $content
    close $fh
    exec chmod $mode $tmp
    file rename -force $tmp $file
}

proc validate_port {label value} {
    if {![regexp {^[0-9]{1,5}$} $value]} {
        fail "Invalid $label: must be numeric."
    }
    set numeric [scan $value %d]
    if {$numeric < 1 || $numeric > 65535} {
        fail "Invalid $label: out of range."
    }
}

proc escape_sed_replacement_pipe_delim {str} {
    regsub -all {([\\&|])} $str {\\\1} escaped
    return $escaped
}

proc resolve_user_home {user} {
    set home ""
    if {[catch {exec getent passwd $user} result] eq ""} {
        set parts [split $result :]
        set home [lindex $parts 5]
    }
    if {$home eq "" && [file exists /etc/passwd]} {
        if {[catch {exec awk -F: [list v $user] {$1==$v {print $6}} /etc/passwd} result] eq ""} {
            set home $result
        }
    }
    if {$home eq ""} {
        set home "/home/$user"
    }
    return $home
}

proc generate_token_hex_32 {} {
    if {[catch {exec which openssl}]} {
        if {[catch {exec which python3}]} {
            if {[catch {exec which od}]} {
                puts stderr "Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN."
                exit 1
            } else {
                return [string map {" " "" "\n" ""} [exec od -An -N32 -tx1 /dev/urandom]]
            }
        } else {
            set pycode {
import secrets
print(secrets.token_hex(32))
            }
            return [exec python3 << $pycode]
        }
    } else {
        return [exec openssl rand -hex 32]
    }
}

proc seed_local_control_ui_origins {file port} {
    ensure_safe_write_file_path "config file" $file
    if {[catch {exec which python3}]} {
        puts stderr "Warning: python3 not found; unable to seed gateway.controlUi.allowedOrigins in $file."
        return
    }
    set dir [file dirname $file]
    set tmp [exec mktemp "$dir/.config.tmp.XXXXXX"]
    set pycode "
import json
import sys

path = sys.argv[1]
port = sys.argv[2]
tmp = sys.argv[3]
try:
    with open(path, \"r\", encoding=\"utf-8\") as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f\"Warning: unable to seed gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.\",
        file=sys.stderr,
    )
    raise SystemExit(1)
if not isinstance(data, dict):
    raise SystemExit(f\"{path}: expected top-level object\")
gateway = data.setdefault(\"gateway\", {})
if not isinstance(gateway, dict):
    raise SystemExit(f\"{path}: expected gateway object\")
gateway.setdefault(\"mode\", \"local\")
control_ui = gateway.setdefault(\"controlUi\", {})
if not isinstance(control_ui, dict):
    raise SystemExit(f\"{path}: expected gateway.controlUi object\")
allowed = control_ui.get(\"allowedOrigins\")
managed_localhosts = {\"127.0.0.1\", \"localhost\"}
desired = [
    f\"http://127.0.0.1:{port}\",
    f\"http://localhost:{port}\",
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
    if normalized.startswith(\"http://\"):
        host_port = normalized[len(\"http://\") :]
        host = host_port.split(\":\", 1)[0]
        if host in managed_localhosts:
            continue
    cleaned.append(normalized)
control_ui[\"allowedOrigins\"] = cleaned + desired
with open(tmp, \"w\", encoding=\"utf-8\") as fh:
    json.dump(data, fh, indent=2)
    fh.write(\"\\n\")
"
    if {[catch {exec python3 [list $file $port $tmp] << $pycode}]} {
        file delete $tmp
        return
    }
    if {![file size $tmp]} {
        file delete $tmp
        return
    }
    catch {exec chmod 600 $tmp}
    file rename -force $tmp $file
}

proc upsert_env_var {file key value} {
    ensure_safe_write_file_path "env file" $file
    set dir [file dirname $file]
    set tmp [exec mktemp "$dir/.env.tmp.XXXXXX"]
    if {[file exists $file]} {
        set fh [open $file r]
        set lines [split [read $fh] "\n"]
        close $fh
        set found 0
        set new_lines {}
        foreach line $lines {
            if {[regexp "^${key}=" $line]} {
                lappend new_lines "${key}=${value}"
                set found 1
            } else {
                lappend new_lines $line
            }
        }
        if {!$found} {
            lappend new_lines "${key}=${value}"
        }
        set fh [open $tmp w]
        puts $fh [join $new_lines "\n"]
        close $fh
    } else {
        set fh [open $tmp w]
        puts $fh "${key}=${value}"
        close $fh
    }
    file rename -force $tmp $file
    catch {exec chmod 600 $file}
}

# Parse arguments
set INSTALL_QUADLET false
foreach arg $argv {
    switch -- $arg {
        --quadlet {
            set INSTALL_QUADLET true
        }
        --container {
            set INSTALL_QUADLET false
        }
    }
}

if {[info exists ::env(OPENCLAW_PODMAN_QUADLET)]} {
    set quadlet_val [string tolower $::env(OPENCLAW_PODMAN_QUADLET)]
    switch -- $quadlet_val {
        1 - yes - true {
            set INSTALL_QUADLET true
        }
        0 - no - false {
            set INSTALL_QUADLET false
        }
    }
}

if {$INSTALL_QUADLET eq "true" && $PLATFORM_NAME ne "Linux"} {
    fail "--quadlet is only supported on Linux with systemd user services."
}

set SEED_GATEWAY_PORT $HOST_GATEWAY_PORT
if {$INSTALL_QUADLET eq "true"} {
    set SEED_GATEWAY_PORT $QUADLET_GATEWAY_PORT
}

require_cmd podman
if {[is_root]} {
    puts stderr "Run scripts/podman/setup.tcl as your normal user so Podman stays rootless."
    exit 1
}
if {$OPENCLAW_IMAGE eq "openclaw:local" && ![file exists [file join $REPO_PATH Dockerfile]]} {
    puts stderr "Dockerfile not found at $REPO_PATH. Set OPENCLAW_REPO_PATH to the repo root."
    exit 1
}
if {![file exists $RUN_SCRIPT_SRC]} {
    puts stderr "Launch script not found at $RUN_SCRIPT_SRC."
    exit 1
}

if {$OPENCLAW_HOME eq ""} {
    set OPENCLAW_HOME [resolve_user_home $OPENCLAW_USER]
}
if {$OPENCLAW_HOME eq ""} {
    puts stderr "Unable to resolve HOME for user $OPENCLAW_USER."
    exit 1
}
if {$OPENCLAW_CONFIG_DIR eq ""} {
    set OPENCLAW_CONFIG_DIR [file join $OPENCLAW_HOME .openclaw]
}
if {$OPENCLAW_WORKSPACE_DIR eq ""} {
    set OPENCLAW_WORKSPACE_DIR [file join $OPENCLAW_CONFIG_DIR workspace]
}
validate_absolute_path "home directory" $OPENCLAW_HOME
validate_mount_source_path "config directory" $OPENCLAW_CONFIG_DIR
validate_mount_source_path "workspace directory" $OPENCLAW_WORKSPACE_DIR
validate_container_name $OPENCLAW_CONTAINER_NAME
validate_image_name $OPENCLAW_IMAGE
validate_port "gateway host port" $HOST_GATEWAY_PORT
validate_port "seed gateway port" $SEED_GATEWAY_PORT

file mkdir $OPENCLAW_CONFIG_DIR
file mkdir $OPENCLAW_WORKSPACE_DIR
catch {exec chmod 700 $OPENCLAW_CONFIG_DIR}
catch {exec chmod 700 $OPENCLAW_WORKSPACE_DIR}
ensure_private_existing_dir_owned_by_user "config directory" $OPENCLAW_CONFIG_DIR
ensure_private_existing_dir_owned_by_user "workspace directory" $OPENCLAW_WORKSPACE_DIR

set BUILD_ARGS {}
if {[info exists ::env(OPENCLAW_DOCKER_APT_PACKAGES)] && $::env(OPENCLAW_DOCKER_APT_PACKAGES) ne ""} {
    lappend BUILD_ARGS --build-arg "OPENCLAW_DOCKER_APT_PACKAGES=$::env(OPENCLAW_DOCKER_APT_PACKAGES)"
}
if {[info exists ::env(OPENCLAW_EXTENSIONS)] && $::env(OPENCLAW_EXTENSIONS) ne ""} {
    lappend BUILD_ARGS --build-arg "OPENCLAW_EXTENSIONS=$::env(OPENCLAW_EXTENSIONS)"
}

if {$OPENCLAW_IMAGE eq "openclaw:local"} {
    puts "Building image $OPENCLAW_IMAGE ..."
    set cmd [list exec podman build -t $OPENCLAW_IMAGE -f [file join $REPO_PATH Dockerfile]]
    eval $cmd $BUILD_ARGS $REPO_PATH
} else {
    if {[catch {exec podman image exists $OPENCLAW_IMAGE}]} {
        puts "Pulling image $OPENCLAW_IMAGE ..."
        exec podman pull $OPENCLAW_IMAGE
    } else {
        puts "Using existing image $OPENCLAW_IMAGE"
    }
}

set ENV_FILE [file join $OPENCLAW_CONFIG_DIR .env]
if {![file exists $ENV_FILE]} {
    set TOKEN [generate_token_hex_32]
    set content "OPENCLAW_GATEWAY_TOKEN=$TOKEN\n"
    write_file_atomically $ENV_FILE 600 $content
    puts "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to $ENV_FILE"
}
upsert_env_var $ENV_FILE "OPENCLAW_PODMAN_CONTAINER" $OPENCLAW_CONTAINER_NAME
upsert_env_var $ENV_FILE "OPENCLAW_PODMAN_IMAGE" $OPENCLAW_IMAGE

set CONFIG_JSON [file join $OPENCLAW_CONFIG_DIR openclaw.json]
if {![file exists $CONFIG_JSON]} {
    set content "{\n  \"gateway\": {\n    \"mode\": \"local\",\n        \"controlUi\": {\n          \"allowedOrigins\": [\n        \"http://127.0.0.1:${SEED_GATEWAY_PORT}\",\n        \"http://localhost:${SEED_GATEWAY_PORT}\"\n      ]\n    }\n  }\n}\n"
    write_file_atomically $CONFIG_JSON 600 $content
    puts "Wrote minimal config to $CONFIG_JSON"
}
seed_local_control_ui_origins $CONFIG_JSON $SEED_GATEWAY_PORT

if {$INSTALL_QUADLET eq "true"} {
    set QUADLET_DIR [file join $OPENCLAW_HOME .config containers systemd]
    set QUADLET_DST [file join $QUADLET_DIR openclaw.container]
    puts "Installing Quadlet to $QUADLET_DST ..."
    file mkdir $QUADLET_DIR
    ensure_safe_existing_dir "quadlet directory" $QUADLET_DIR
    set OPENCLAW_HOME_ESCAPED [escape_sed_replacement_pipe_delim $OPENCLAW_HOME]
    set OPENCLAW_CONFIG_ESCAPED [escape_sed_replacement_pipe_delim $OPENCLAW_CONFIG_DIR]
    set OPENCLAW_WORKSPACE_ESCAPED [escape_sed_replacement_pipe_delim $OPENCLAW_WORKSPACE_DIR]
    set OPENCLAW_IMAGE_ESCAPED [escape_sed_replacement_pipe_delim $OPENCLAW_IMAGE]
    set OPENCLAW_CONTAINER_ESCAPED [escape_sed_replacement_pipe_delim $OPENCLAW_CONTAINER_NAME]
    
    set template_fh [open $QUADLET_TEMPLATE r]
    set template_content [read $template_fh]
    close $template_fh
    
    set processed_content [string map [list \
        "{{OPENCLAW_HOME}}" $OPENCLAW_HOME_ESCAPED \
        "{{OPENCLAW_CONFIG_DIR}}" $OPENCLAW_CONFIG_ESCAPED \
        "{{OPENCLAW_WORKSPACE_DIR}}" $OPENCLAW_WORKSPACE_ESCAPED \
        "{{IMAGE_NAME}}" $OPENCLAW_IMAGE_ESCAPED \
        "{{CONTAINER_NAME}}" $OPENCLAW_CONTAINER_ESCAPED] $template_content]
    
    write_file_atomically $QUADLET_DST 644 $processed_content

    if {![catch {exec which systemctl}]} {
        puts "Reloading and starting user service..."
        if {![catch {exec systemctl --user daemon-reload}] && ![catch {exec systemctl --user start openclaw.service}]} {
            puts "Quadlet installed and service started."
        } else {
            puts stderr "Quadlet installed, but automatic start failed."
            puts stderr "Try: systemctl --user daemon-reload && systemctl --user start openclaw.service"
            if {![catch {exec which loginctl}]} {
                puts stderr "For boot persistence on headless hosts, you may also need: sudo loginctl enable-linger [exec whoami]"
            }
        }
    } else {
        puts stderr "systemctl not found; Quadlet installed but not started."
    }
} else {
    puts "Container setup complete."
}

puts ""
puts "Next:"
puts "  ./scripts/run-openclaw-podman.sh launch"
puts "  ./scripts/run-openclaw-podman.sh launch setup"
puts "  openclaw --container $OPENCLAW_CONTAINER_NAME dashboard --no-open"
