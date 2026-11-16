#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "729fcc508d369af010e159308b0a837bac2ffa4f254f7268205c3d6c15f3a19b", "source_sha256": "c07aee6a3f0a90788cfe647dfcc79cf95df841ce0459eb8ffd9bf6aaa426ea38", "target_language": "shell"}
# build-all.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-all.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Konstanten
WINDOWS_BUILD_MAX_OLD_SPACE_MB=4096

# Funktion zur Bestimmung des pnpm-Befehls
resolve_pnpm_runner() {
    local pnpm_args=("${!1}")
    local node_exec_path="${2:-node}"
    local npm_exec_path="${3:-}"
    local comspec="${4:-}"
    local platform="${5:-$(uname -s)}"

    if [[ "$platform" == "MINGW"* ]] || [[ "$platform" == "MSYS"* ]] || [[ "$platform" == "CYGWIN"* ]]; then
        if [[ -n "${npm_exec_path}" ]]; then
            echo "command=${npm_exec_path}"$'\n'"args=run ${pnpm_args[*]}"$'\n'"shell=true"$'\n'"windows_verbatim_arguments=true"
        else
            echo "command=pnpm"${pnpm_args:+$'\n'"args=${pnpm_args[*]}"}$'\n'"shell=true"
        fi
    else
        if [[ -n "${npm_exec_path}" ]]; then
            echo "command=${npm_exec_path}"$'\n'"args=run ${pnpm_args[*]}"
        else
            echo "command=pnpm"${pnpm_args:+$'\n'"args=${pnpm_args[*]}"}
        fi
    fi
}

# Funktion zur Auflösung der Umgebungsvariablen für einen Schritt
resolve_step_env() {
    local windows_node_options="${1:-}"
    local platform="${2:-$(uname -s)}"
    local current_node_options="${NODE_OPTIONS:-}"

    if [[ "$platform" != *"NT"* ]] || [[ -z "$windows_node_options" ]]; then
        echo "$current_node_options"
        return
    fi

    if [[ "$current_node_options" == *"$windows_node_options"* ]]; then
        echo "$current_node_options"
        return
    fi

    if [[ -n "$current_node_options" ]]; then
        echo "$current_node_options $windows_node_options"
    else
        echo "$windows_node_options"
    fi
}

# Funktion zur Ausführung eines Build-Schritts
run_build_step() {
    local label="$1"; shift
    local kind="$1"; shift
    local args=("$@")
    
    # Extrahiere spezielle Parameter
    local pnpm_args=()
    local windows_node_options=""
    local is_pnpm=false
    
    case "$kind" in
        pnpm)
            is_pnpm=true
            pnpm_args=("${args[@]}")
            ;;
        node)
            # Für Node-Schritte werden die Argumente direkt verwendet
            ;;
    esac
    
    # Prüfe auf Windows-spezifische Optionen
    case "$label" in
        build:plugin-sdk:dts)
            windows_node_options="--max-old-space-size=$WINDOWS_BUILD_MAX_OLD_SPACE_MB"
            ;;
    esac
    
    echo "[build-all] $label" >&2
    
    local env_node_options
    env_node_options=$(resolve_step_env "$windows_node_options")
    
    local new_env=""
    if [[ -n "$env_node_options" ]]; then
        new_env="NODE_OPTIONS=$env_node_options"
    fi
    
    if [[ "$is_pnpm" == true ]]; then
        local runner_result
        runner_result=$(resolve_pnpm_runner pnpm_args[@] "$(which node)" "${npm_execpath:-}" "${ComSpec:-}" "$(uname -s)")
        
        local command=""
        local runner_args=()
        local shell_opt=""
        local win_verbatim=""
        
        while IFS='=' read -r key value; do
            case "$key" in
                command) command="$value" ;;
                args) 
                    IFS=' ' read -ra runner_args <<< "$value"
                    ;;
                shell) shell_opt="$value" ;;
                windows_verbatim_arguments) win_verbatim="$value" ;;
            esac
        done <<< "$runner_result"
        
        if [[ -n "$new_env" ]]; then
            export NODE_OPTIONS="$env_node_options"
        fi
        
        if [[ -n "$shell_opt" && "$shell_opt" == "true" ]]; then
            if [[ -n "$win_verbatim" && "$win_verbatim" == "true" ]]; then
                "${command}" ${runner_args[*]}
            else
                "${command}" ${runner_args[*]}
            fi
        else
            "${command}" ${runner_args[*]}
        fi
        
        local exit_code=$?
        if [[ -n "$new_env" ]]; then
            unset NODE_OPTIONS
        fi
        
        return $exit_code
    else
        if [[ -n "$new_env" ]]; then
            NODE_OPTIONS="$env_node_options" "$(which node)" "${args[@]}"
        else
            "$(which node)" "${args[@]}"
        fi
        return $?
    fi
}

# Hauptausführung
main() {
    # canvas:a2ui:bundle
    run_build_step "canvas:a2ui:bundle" "pnpm" "canvas:a2ui:bundle" || exit $?
    
    # tsdown
    run_build_step "tsdown" "node" "scripts/tsdown-build.mjs" || exit $?
    
    # runtime-postbuild
    run_build_step "runtime-postbuild" "node" "scripts/runtime-postbuild.mjs" || exit $?
    
    # write-npm-update-compat-sidecars
    run_build_step "write-npm-update-compat-sidecars" "node" "scripts/write-npm-update-compat-sidecars.mjs" || exit $?
    
    # build-stamp
    run_build_step "build-stamp" "node" "scripts/build-stamp.mjs" || exit $?
    
    # build:plugin-sdk:dts
    run_build_step "build:plugin-sdk:dts" "pnpm" "build:plugin-sdk:dts" || exit $?
    
    # write-plugin-sdk-entry-dts
    run_build_step "write-plugin-sdk-entry-dts" "node" "--import" "tsx" "scripts/write-plugin-sdk-entry-dts.ts" || exit $?
    
    # check-plugin-sdk-exports
    run_build_step "check-plugin-sdk-exports" "node" "scripts/check-plugin-sdk-exports.mjs" || exit $?
    
    # canvas-a2ui-copy
    run_build_step "canvas-a2ui-copy" "node" "--import" "tsx" "scripts/canvas-a2ui-copy.ts" || exit $?
    
    # copy-hook-metadata
    run_build_step "copy-hook-metadata" "node" "--import" "tsx" "scripts/copy-hook-metadata.ts" || exit $?
    
    # copy-export-html-templates
    run_build_step "copy-export-html-templates" "node" "--import" "tsx" "scripts/copy-export-html-templates.ts" || exit $?
    
    # write-build-info
    run_build_step "write-build-info" "node" "--import" "tsx" "scripts/write-build-info.ts" || exit $?
    
    # write-cli-startup-metadata
    run_build_step "write-cli-startup-metadata" "node" "--experimental-strip-types" "scripts/write-cli-startup-metadata.ts" || exit $?
    
    # write-cli-compat
    run_build_step "write-cli-compat" "node" "--import" "tsx" "scripts/write-cli-compat.ts" || exit $?
}

# Wenn das Skript direkt ausgeführt wird
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
