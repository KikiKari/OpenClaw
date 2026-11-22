#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "5eae9fd9abc4291eeba1eda9d56517e4dc34c4ccf58f3f894c0a1aa93a00d499", "source_sha256": "9b573d1d5f5751c3fe5bb1eb243725ffb174987da9e458632a295c541458b2a0", "target_language": "tcl"}
# run-openclaw-podman.sh — portiert nach tcl
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

proc resolve_user_home {user} {
    set home ""
    if {[catch {exec getent passwd $user} result] == 0} {
        set fields [split $result ":"]
        if {[llength $fields] >= 6} {
            set home [lindex $fields 5]
        }
    }
    if {$home eq "" && [file exists "/etc/passwd"]} {
        if {[catch {exec awk -F: [subst -n {$1=="$user" {print $6}}] /etc/passwd} result] == 0} {
            set home $result
        }
    }
    if {$home eq ""} {
        set home "/home/$user"
    }
    return $home
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
    if {[string match "*./.*" $value] || [string match "*/." $value] || 
        [string match "*../.*" $value] || [string match "*/.." $value]} {
        fail "Invalid $label: dot path segments are not allowed."
    }
}

proc validate_mount_source_path {label value} {
    validate_absolute_path $label $value
    if {[string match "*:*" $value]} {
        fail "Invalid $label: ':' is not allowed in Podman bind-mount source paths."
    }
}

proc ensure_safe_existing_regular_file {label file} {
    validate_absolute_path $label $file
    if {![file exists $file]} {
        fail "Missing $label: $file"
    }
    if {[file type $file] ne "file"} {
        fail "Unsafe $label: expected a regular file ($file)"
    }
    if {[file lstat $file sb] == 0 && $sb(type) eq "link"} {
        fail "Unsafe $label: symlinks are not allowed ($file)"
    }
}

proc ensure_safe_existing_dir {label dir} {
    validate_absolute_path $label $dir
    if {![file isdirectory $dir]} {
        fail "Missing $label: $dir"
    }
    if {[file lstat $dir sb] == 0 && $sb(type) eq "link"} {
        fail "Unsafe $label: symlinks are not allowed ($dir)"
    }
}

proc stat_uid {path} {
    if {[catch {exec id -u} uid] == 0} {
        return $uid
    }
    return 0
}

proc stat_mode {path} {
    if {[catch {exec stat -c %a $path} mode] == 0} {
        return $mode
    }
    return "600"
}

proc ensure_private_existing_dir_owned_by_user {label dir} {
    ensure_safe_existing_dir $label $dir
    set uid [stat_uid $dir]
    if {$uid ne [exec id -u]} {
        fail "Unsafe $label: not owned by current user ($dir)"
    }
    set mode [stat_mode $dir]
    set mode_num [expr {0o$mode}]
    if {($mode_num & 0o022) != 0} {
        fail "Unsafe $label: group/other writable ($dir)"
    }
}

proc ensure_private_existing_regular_file_owned_by_user {label file} {
    ensure_safe_existing_regular_file $label $file
    set uid [stat_uid $file]
    if {$uid ne [exec id -u]} {
        fail "Unsafe $label: not owned by current user ($file)"
    }
    set mode [stat_mode $file]
    set mode_num [expr {0o$mode}]
    if {($mode_num & 0o077) != 0} {
        fail "Unsafe $label: expected owner-only permissions ($file)"
    }
}

proc ensure_safe_write_file_path {label file} {
    validate_absolute_path $label $file
    if {[file exists $file]} {
        if {[file type $file] ne "file"} {
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

proc load_podman_env_file {file} {
    ensure_private_existing_regular_file_owned_by_user "Podman env file" $file
    set dir [file dirname $file]
    ensure_private_existing_dir_owned_by_user "Podman env directory" $dir
    
    set fh [open $file r]
    while {[gets $fh line] >= 0} {
        set trimmed [string trim $line]
        if {$trimmed eq "" || [string index $trimmed 0] eq "#"} {
            continue
        }
        if {[string first "=" $line] != -1} {
            set parts [split $line "="]
            set key [string trim [lindex $parts 0]]
            set value [join [lrange $parts 1 end] "="]
            
            if {[regexp {^[A-Za-z_][A-Za-z0-9_]*$} $key]} {
                switch -exact $key {
                    OPENCLAW_GATEWAY_TOKEN -
                    OPENCLAW_PODMAN_CONTAINER -
                    OPENCLAW_PODMAN_IMAGE -
                    OPENCLAW_IMAGE -
                    OPENCLAW_PODMAN_PULL -
                    OPENCLAW_PODMAN_GATEWAY_HOST_PORT -
                    OPENCLAW_GATEWAY_PORT -
                    OPENCLAW_PODMAN_BRIDGE_HOST_PORT -
                    OPENCLAW_BRIDGE_PORT -
                    OPENCLAW_GATEWAY_BIND -
                    OPENCLAW_PODMAN_USERNS -
                    OPENCLAW_BIND_MOUNT_OPTIONS -
                    OPENCLAW_PODMAN_PUBLISH_HOST {
                        if {[regexp {^".*"$|^'.*'$} $value]} {
                            set value [string range $value 1 end-1]
                        }
                        set ::env($key) $value
                    }
                }
            }
        }
    }
    close $fh
}

proc validate_port {label value} {
    if {![regexp {^[0-9]{1,5}$} $value]} {
        fail "Invalid $label: must be numeric."
    }
    set numeric [expr {int($value)}]
    if {$numeric < 1 || $numeric > 65535} {
        fail "Invalid $label: out of range."
    }
}

set PLATFORM_NAME [exec uname -s]

set EFFECTIVE_USER [exec id -un]
if {[info exists ::env(HOME)] && $::env(HOME) ne ""} {
    set EFFECTIVE_HOME $::env(HOME)
} else {
    set EFFECTIVE_HOME [resolve_user_home $EFFECTIVE_USER]
}

if {[exec id -u] eq "0"} {
    fail "Run run-openclaw-podman.sh as your normal user so Podman stays rootless."
}

# Handle command line arguments
set argv_copy $argv
set argc_copy [llength $argv_copy]

if {$argc_copy > 0 && [lindex $argv_copy 0] eq "setup-host"} {
    set argv_copy [lrange $argv_copy 1 end]
    
    set REPO_ROOT [file normalize [file join [file dirname [info script]] ..]]
    set SETUP_PODMAN [file join $REPO_ROOT scripts podman setup.sh]
    
    if {[file exists $SETUP_PODMAN]} {
        eval exec $SETUP_PODMAN $argv_copy &
        exit 0
    }
    
    set SETUP_PODMAN [file join $REPO_ROOT setup-podman.sh]
    if {[file exists $SETUP_PODMAN]} {
        eval exec $SETUP_PODMAN $argv_copy &
        exit 0
    }
    
    puts stderr "Podman setup script not found. Run from repo root: ./scripts/podman/setup.sh"
    exit 1
}

set LAUNCH_MODE false
if {$argc_copy > 0 && [lindex $argv_copy 0] eq "launch"} {
    set LAUNCH_MODE true
    set argv_copy [lrange $argv_copy 1 end]
}

if {![info exists EFFECTIVE_HOME] || $EFFECTIVE_HOME eq ""} {
    set EFFECTIVE_HOME "/tmp"
}
validate_absolute_path "effective home" $EFFECTIVE_HOME

set CONFIG_DIR [expr {[info exists ::env(OPENCLAW_CONFIG_DIR)] ? $::env(OPENCLAW_CONFIG_DIR) : "$EFFECTIVE_HOME/.openclaw"}]
set ENV_FILE [expr {[info exists ::env(OPENCLAW_PODMAN_ENV)] ? $::env(OPENCLAW_PODMAN_ENV) : "$CONFIG_DIR/.env"}]

if {[file exists $ENV_FILE]} {
    load_podman_env_file $ENV_FILE
}

set CONFIG_DIR [expr {[info exists ::env(OPENCLAW_CONFIG_DIR)] ? $::env(OPENCLAW_CONFIG_DIR) : "$EFFECTIVE_HOME/.openclaw"}]
set ENV_FILE [expr {[info exists ::env(OPENCLAW_PODMAN_ENV)] ? $::env(OPENCLAW_PODMAN_ENV) : "$CONFIG_DIR/.env"}]
set WORKSPACE_DIR [expr {[info exists ::env(OPENCLAW_WORKSPACE_DIR)] ? $::env(OPENCLAW_WORKSPACE_DIR) : "$CONFIG_DIR/workspace"}]
set CONTAINER_NAME [expr {[info exists ::env(OPENCLAW_PODMAN_CONTAINER)] ? $::env(OPENCLAW_PODMAN_CONTAINER) : "openclaw"}]
set OPENCLAW_IMAGE [expr {[info exists ::env(OPENCLAW_PODMAN_IMAGE)] ? $::env(OPENCLAW_PODMAN_IMAGE) : [expr {[info exists ::env(OPENCLAW_IMAGE)] ? $::env(OPENCLAW_IMAGE) : "openclaw:local"}]}]
set PODMAN_PULL [expr {[info exists ::env(OPENCLAW_PODMAN_PULL)] ? $::env(OPENCLAW_PODMAN_PULL) : "never"}]
set HOST_GATEWAY_PORT [expr {[info exists ::env(OPENCLAW_PODMAN_GATEWAY_HOST_PORT)] ? $::env(OPENCLAW_PODMAN_GATEWAY_HOST_PORT) : [expr {[info exists ::env(OPENCLAW_GATEWAY_PORT)] ? $::env(OPENCLAW_GATEWAY_PORT) : "18789"}]}]
set HOST_BRIDGE_PORT [expr {[info exists ::env(OPENCLAW_PODMAN_BRIDGE_HOST_PORT)] ? $::env(OPENCLAW_PODMAN_BRIDGE_HOST_PORT) : [expr {[info exists ::env(OPENCLAW_BRIDGE_PORT)] ? $::env(OPENCLAW_BRIDGE_PORT) : "18790"}]}]
set PUBLISH_HOST [expr {[info exists ::env(OPENCLAW_PODMAN_PUBLISH_HOST)] ? $::env(OPENCLAW_PODMAN_PUBLISH_HOST) : "127.0.0.1"}]

validate_mount_source_path "config directory" $CONFIG_DIR
validate_mount_source_path "workspace directory" $WORKSPACE_DIR
validate_absolute_path "env file path" $ENV_FILE
validate_single_line_value "container name" $CONTAINER_NAME
validate_single_line_value "image name" $OPENCLAW_IMAGE
validate_single_line_value "publish host" $PUBLISH_HOST
validate_port "gateway host port" $HOST_GATEWAY_PORT
validate_port "bridge host port" $HOST_BRIDGE_PORT

if {[catch {cd $EFFECTIVE_HOME}]} {
    if {[catch {cd /tmp}]} {
        # ignore error
    }
}

set RUN_SETUP false
if {[llength $argv_copy] > 0 && ([lindex $argv_copy 0] eq "setup" || [lindex $argv_copy 0] eq "onboard")} {
    set RUN_SETUP true
    set argv_copy [lrange $argv_copy 1 end]
}

file mkdir $CONFIG_DIR $WORKSPACE_DIR
file mkdir $CONFIG_DIR/canvas $CONFIG_DIR/cron
catch {exec chmod 700 $CONFIG_DIR $WORKSPACE_DIR}
ensure_private_existing_dir_owned_by_user "config directory" $CONFIG_DIR
ensure_private_existing_dir_owned_by_user "workspace directory" $WORKSPACE_DIR

proc resolve_config_gateway_bind {config_dir} {
    if {[catch {exec which openclaw}]} {
        return ""
    }
    
    if {[catch {exec env OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR=$config_dir openclaw config get gateway.bind} result]} {
        return ""
    }
    return $result
}

set CONFIG_GATEWAY_BIND [resolve_config_gateway_bind $CONFIG_DIR]
set GATEWAY_BIND [expr {[info exists ::env(OPENCLAW_GATEWAY_BIND)] ? $::env(OPENCLAW_GATEWAY_BIND) : [expr {$CONFIG_GATEWAY_BIND ne "" ? $CONFIG_GATEWAY_BIND : "lan"}]}]

proc upsert_env_var {file key value} {
    ensure_safe_write_file_path "env file" $file
    set dir [file dirname $file]
    set tmp [exec mktemp "$dir/.env.tmp.XXXXXX"]
    
    if {[file exists $file]} {
        set content [exec awk [list -v k=$key -v v=$value {BEGIN { found = 0 } $0 ~ ("^" k "=") { print k "=" v; found = 1; next } { print } END { if (!found) print k "=" v }}] $file]
        set fh [open $tmp w]
        puts -nonewline $fh $content
        close $fh
    } else {
        set fh [open $tmp w]
        puts $fh "$key=$value"
        close $fh
    }
    
    file rename -force $tmp $file
    catch {exec chmod 600 $file}
}

proc generate_token_hex_32 {} {
    if {[catch {exec which openssl}]} {
        if {[catch {exec which python3}]} {
            if {[catch {exec which od}]} {
                puts stderr "Missing dependency: need openssl or python3 (or od) to generate OPENCLAW_GATEWAY_TOKEN."
                exit 1
            }
            return [string map {" " "" "\n" ""} [exec od -An -N32 -tx1 /dev/urandom]]
        }
        return [exec python3 << "import secrets; print(secrets.token_hex(32))"]
    }
    return [exec openssl rand -hex 32]
}

proc create_token_env_file {file token} {
    set dir [file dirname $file]
    ensure_private_existing_dir_owned_by_user "token env directory" $dir
    set tmp [exec mktemp "$dir/.token.env.XXXXXX"]
    catch {exec chmod 600 $tmp}
    set fh [open $tmp w]
    puts $fh "OPENCLAW_GATEWAY_TOKEN=$token"
    close $fh
    return $tmp
}

proc sync_local_control_ui_origins_via_cli {file port} {
    set config_dir [file dirname $file]
    if {[catch {exec which openclaw}]} {
        puts stderr "Warning: openclaw not found; unable to sync gateway.controlUi.allowedOrigins in $file."
        return
    }
    
    if {[catch {exec which python3}]} {
        catch {exec env OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR=$config_dir openclaw config set gateway.controlUi.allowedOrigins \[\"http://127.0.0.1:${port}\",\"http://localhost:${port}\"\] --strict-json}
        return
    }
    
    set allowed_json ""
    if {[catch {exec env OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR=$config_dir openclaw config get gateway.controlUi.allowedOrigins --json} result] == 0} {
        set allowed_json $result
    }
    
    set merged_json [exec python3 << "
import json
import sys

port = '$port'
raw = '''$allowed_json'''
desired = [
    f'http://127.0.0.1:{port}',
    f'http://localhost:{port}',
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
"]
    
    catch {exec env OPENCLAW_CONTAINER="" OPENCLAW_CONFIG_DIR=$config_dir openclaw config set gateway.controlUi.allowedOrigins $merged_json --strict-json}
}

proc sync_local_control_ui_origins {file port} {
    ensure_safe_write_file_path "config file" $file
    if {[catch {exec which python3}]} {
        puts stderr "Warning: python3 not found; unable to sync gateway.controlUi.allowedOrigins in $file."
        return
    }
    
    set dir [file dirname $file]
    ensure_private_existing_dir_owned_by_user "config file directory" $dir
    set tmp [exec mktemp "$dir/.config.tmp.XXXXXX"]
    
    set script "
import json
import sys

path = '$file'
port = '$port'
tmp = '$tmp'
try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except json.JSONDecodeError as exc:
    print(
        f'Warning: unable to sync gateway.controlUi.allowedOrigins in {path}: existing config is not strict JSON ({exc}). Leaving file unchanged.',
        file=sys.stderr,
    )
    raise SystemExit(1)
if not isinstance(data, dict):
    raise SystemExit(f'{path}: expected top-level object')
gateway = data.setdefault('gateway', {})
if not isinstance(gateway, dict):
    raise SystemExit(f'{path}: expected gateway object')
gateway.setdefault('mode', 'local')
control_ui = gateway.setdefault('controlUi', {})
if not isinstance(control_ui, dict):
    raise SystemExit(f'{path}: expected gateway.controlUi object')
allowed = control_ui.get('allowedOrigins')
desired = [
    f'http://127.0.0.1:{port}',
    f'http://localhost:{port}',
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
control_ui['allowedOrigins'] = cleaned
with open(tmp, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
    fh.write('\\n')
"
    
    if {[catch {exec python3 << $script}]} {
        file delete -force $tmp
        sync_local_control_ui_origins_via_cli $file $port
        return
    }
    
    if {![file exists $tmp] || [file size $tmp] == 0} {
        file delete -force $tmp
        return
    }
    
    catch {exec chmod 600 $tmp}
    file rename -force $tmp $file
}

set TOKEN_ENV_FILE ""

proc cleanup_token_env_file {} {
    global TOKEN_ENV_FILE
    if {$TOKEN_ENV_FILE ne "" && [file exists $TOKEN_ENV_FILE]} {
        file delete -force $TOKEN_ENV_FILE
    }
}

proc trap_handler {args} {
    cleanup_token_env_file
}

if {![info exists ::env(OPENCLAW_GATEWAY_TOKEN)] || $::env(OPENCLAW_GATEWAY_TOKEN) eq ""} {
    set ::env(OPENCLAW_GATEWAY_TOKEN) [generate_token_hex_32]
    file mkdir [file dirname $ENV_FILE]
    ensure_safe_existing_dir "env file directory" [file dirname $ENV_FILE]
    upsert_env_var $ENV_FILE "OPENCLAW_GATEWAY_TOKEN" $::env(OPENCLAW_GATEWAY_TOKEN)
    puts stderr "Generated OPENCLAW_GATEWAY_TOKEN and wrote it to $ENV_FILE."
}

set CONFIG_JSON "$CONFIG_DIR/openclaw.json"
if {![file exists $CONFIG_JSON]} {
    set content "{ \"gateway\": { \"mode\": \"local\" } }\n"
    write_file_atomically $CONFIG_JSON 600 $content
    puts stderr "Created $CONFIG_JSON (minimal gateway.mode=local)."
}

sync_local_control_ui_origins $CONFIG_JSON $HOST_GATEWAY_PORT

set PODMAN_USERNS [expr {[info exists ::env(OPENCLAW_PODMAN_USERNS)] ? $::env(OPENCLAW_PODMAN_USERNS) : "keep-id"}]
set USERNS_ARGS {}
set RUN_USER_ARGS {}

switch -exact $PODMAN_USERNS {
    "" -
    "auto" {}
    "keep-id" {
        lappend USERNS_ARGS "--userns=keep-id"
    }
    "host" {
        lappend USERNS_ARGS "--userns=host"
    }
    default {
        puts stderr "Unsupported OPENCLAW_PODMAN_USERNS=$PODMAN_USERNS (expected: keep-id, auto, host)."
        exit 2
    }
}

set RUN_UID [exec id -u]
set RUN_GID [exec id -g]

if {$PODMAN_USERNS eq "keep-id"} {
    lappend RUN_USER_ARGS "--user" "${RUN_UID}:${RUN_GID}"
} else {
    puts stderr "Starting container without --user (OPENCLAW_PODMAN_USERNS=$PODMAN_USERNS), mounts may require ownership fixes."
}

set SELINUX_MOUNT_OPTS ""
if {![info exists ::env(OPENCLAW_BIND_MOUNT_OPTIONS)] || $::env(OPENCLAW_BIND_MOUNT_OPTIONS) eq ""} {
    if {[exec uname -s] eq "Linux" && [catch {exec which getenforce}]} {
        set selinux_mode ""
        if {[catch {exec getenforce} result] == 0} {
            set selinux_mode $result
        }
        if {$selinux_mode eq "Enforcing" || $selinux_mode eq "Permissive"} {
            set SELINUX_MOUNT_OPTS ",Z"
        }
    }
} else {
    set SELINUX_MOUNT_OPTS [string range $::env(OPENCLAW_BIND_MOUNT_OPTIONS) 1 end]
    if {$SELINUX_MOUNT_OPTS ne ""} {
        set SELINUX_MOUNT_OPTS ",$SELINUX_MOUNT_OPTS"
    }
}

set TOKEN_ENV_FILE [create_token_env_file $ENV_FILE $::env(OPENCLAW_GATEWAY_TOKEN)]

if {$RUN_SETUP} {
    set cmd [list exec podman run --pull=$PODMAN_PULL --rm -it --init]
    foreach arg $USERNS_ARGS {
        lappend cmd $arg
    }
    foreach arg $RUN_USER_ARGS {
        lappend cmd $arg
    }
    lappend cmd -e HOME=/home/node -e TERM=xterm-256color -e BROWSER=echo
    lappend cmd -e NPM_CONFIG_CACHE=/home/node/.openclaw/.npm
    lappend cmd -e OPENCLAW_NO_RESPAWN=1
    lappend cmd --env-file $TOKEN_ENV_FILE
    lappend cmd -v "$CONFIG_DIR:/home/node/.openclaw:rw$SELINUX_MOUNT_OPTS"
    lappend cmd -v "$WORKSPACE_DIR:/home/node/.openclaw/workspace:rw$SELINUX_MOUNT_OPTS"
    lappend cmd $OPENCLAW_IMAGE
    lappend cmd node dist/index.js onboard {*}$argv_copy
    eval $cmd
    exit 0
}

set cmd [list exec podman run --pull=$PODMAN_PULL -d --replace]
lappend cmd --name $CONTAINER_NAME
lappend cmd --init
foreach arg $USERNS_ARGS {
    lappend cmd $arg
}
foreach arg $RUN_USER_ARGS {
    lappend cmd $arg
}
lappend cmd -e HOME=/home/node -e TERM=xterm-256color
lappend cmd -e NPM_CONFIG_CACHE=/home/node/.openclaw/.npm
lappend cmd -e OPENCLAW_NO_RESPAWN=1
lappend cmd --env-file $TOKEN_ENV_FILE
lappend cmd -v "$CONFIG_DIR:/home/node/.openclaw:rw$SELINUX_MOUNT_OPTS"
lappend cmd -v "$WORKSPACE_DIR:/home/node/.openclaw/workspace:rw$SELINUX_MOUNT_OPTS"
lappend cmd -p "${PUBLISH_HOST}:${HOST_GATEWAY_PORT}:18789"
lappend cmd -p "${PUBLISH_HOST}:${HOST_BRIDGE_PORT}:18790"
lappend cmd $OPENCLAW_IMAGE
lappend cmd node dist/index.js gateway --bind $GATEWAY_BIND --port 18789

eval $cmd >@stdout 2>@stderr

puts "Container $CONTAINER_NAME started: http://127.0.0.1:${HOST_GATEWAY_PORT}/"
puts "podman exec -it $CONTAINER_NAME openclaw dashboard --no-open"
puts "podman exec -it $CONTAINER_NAME openclaw devices approve --latest  # if pairing required"
puts "podman logs -f $CONTAINER_NAME"

if {$PLATFORM_NAME eq "Linux"} {
    puts "For auto-start/restarts, use: ./scripts/podman/setup.sh --quadlet (Quadlet + systemd user service)."
}
