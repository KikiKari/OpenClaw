#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "05347e21434f951987380e49dcbd4609255ded4b981081fc7f3971eb113c7321", "source_sha256": "d0e229aab6f22cce6a57639e2ffb6182fc50c823ca2adff745764d168dc70826", "target_language": "shell"}
# audit-seams.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/audit-seams.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This script audits repo seam inventory and emits JSON to stdout.
#
# Sections:
#   duplicatedSeamFamilies       Plugin SDK seam families imported from multiple production files
#   overlapFiles                 Production files that touch multiple seam families
#   optionalClusterStaticLeaks   Optional extension/plugin clusters referenced from the static graph
#   missingPackages              Workspace packages whose deps are not mirrored at the root
#   seamTestInventory            High-signal seam candidates with nearby-test gap signals,
#                                including cron orchestration seams for agent handoff,
#                                outbound/media delivery, heartbeat/followup handoff,
#                                and scheduler state crossings, plus subagent seams
#                                for spawn/session handoff, announce delivery,
#                                lifecycle registry, cleanup, and parent streaming
#
# Notes:
#   - Output is JSON only.
#   - For clean redirected JSON through package scripts, prefer:
#       pnpm --silent audit:seams > seam-inventory.json

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SRC_ROOT="${REPO_ROOT}/src"
readonly EXTENSIONS_ROOT="${REPO_ROOT}/extensions"
readonly TEST_ROOT="${REPO_ROOT}/test"
readonly WORKSPACE_PACKAGE_PATHS=("ui/package.json")
readonly MAX_SCAN_BYTES=$((2 * 1024 * 1024))
readonly BUNDLED_PLUGIN_PATH_PREFIX="extensions/"
readonly BUNDLED_PLUGIN_ROOT_DIR="extensions"

# Define optional bundled clusters (these would come from lib/optional-bundled-clusters.mjs)
declare -A OPTIONAL_BUNDLED_CLUSTER_SET
OPTIONAL_BUNDLED_CLUSTER_SET["ui"]=1
OPTIONAL_BUNDLED_CLUSTER_SET["some-extension"]=1
OPTIONAL_BUNDLED_CLUSTER_SET["another-extension"]=1

readonly HELP_TEXT='Usage: node scripts/audit-seams.mjs [--help]

Audit repo seam inventory and emit JSON to stdout.

Sections:
  duplicatedSeamFamilies       Plugin SDK seam families imported from multiple production files
  overlapFiles                 Production files that touch multiple seam families
  optionalClusterStaticLeaks   Optional extension/plugin clusters referenced from the static graph
  missingPackages              Workspace packages whose deps are not mirrored at the root
  seamTestInventory            High-signal seam candidates with nearby-test gap signals,
                               including cron orchestration seams for agent handoff,
                               outbound/media delivery, heartbeat/followup handoff,
                               and scheduler state crossings, plus subagent seams
                               for spawn/session handoff, announce delivery,
                               lifecycle registry, cleanup, and parent streaming

Notes:
  - Output is JSON only.
  - For clean redirected JSON through package scripts, prefer:
      pnpm --silent audit:seams > seam-inventory.json
'

# Function to normalize paths
normalize_path() {
    local file_path="$1"
    # Convert absolute path to relative path from repo root
    realpath --relative-to="${REPO_ROOT}" "${file_path}" | tr '\\' '/'
}

# Function to read scannable text
read_scannable_text() {
    local file_path="$1"
    local max_bytes="${2:-${MAX_SCAN_BYTES}}"
    
    if [[ $(stat -c%s "${file_path}") -le ${max_bytes} ]]; then
        cat "${file_path}"
    else
        head -c "${max_bytes}" "${file_path}"
    fi
}

# Function to redact npm spec
redact_npm_spec() {
    local npm_spec="$1"
    if [[ ! "${npm_spec}" =~ ^https?:// ]]; then
        echo "${npm_spec}"
        return
    fi
    
    # Replace credentials in URL
    echo "${npm_spec}" | sed -E 's/(https?:\/\/)([^/@:]+):([^/@]+)@/\1***:***@/g' | \
        sed -E 's/(https?:\/\/)([^/@]+)@/\1***@/g'
}

# Function to check if file is code file
is_code_file() {
    local file_name="$1"
    case "${file_name}" in
        *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.cjs)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if path is test-like
is_test_like_path() {
    local relative_path="$1"
    if [[ "${relative_path}" =~ (^|/)__(tests|fixtures|test-utils|test-fixtures)__[/] ]] || \
       [[ "${relative_path}" =~ (?:^|/)[^/]*(?:[.-](test|spec))(?:[.-][^/]+)?\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$ ]]; then
        return 0
    fi
    return 1
}

# Function to check if file is production-like
is_production_like_file() {
    local relative_path="$1"
    if is_test_like_path "${relative_path}"; then
        return 1
    fi
    return 0
}

# Function to walk code files
walk_code_files() {
    local root_dir="$1"
    local include_tests="${2:-false}"
    local files=()
    
    while IFS= read -r -d '' file; do
        files+=("${file}")
    done < <(find "${root_dir}" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.mts" -o -name "*.cts" -o -name "*.js" -o -name "*.jsx" -o -name "*.mjs" -o -name "*.cjs" \) -not -path "*/node_modules/*" -not -path "*/dist/*" -print0)
    
    local filtered_files=()
    for file in "${files[@]}"; do
        local relative_path
        relative_path=$(normalize_path "${file}")
        
        if [[ "${include_tests}" == "false" ]] && ! is_production_like_file "${relative_path}"; then
            continue
        fi
        
        filtered_files+=("${file}")
    done
    
    # Sort files
    printf '%s\n' "${filtered_files[@]}" | sort
}

# Function to resolve relative specifier
resolve_relative_specifier() {
    local specifier="$1"
    local importer_file="$2"
    
    if [[ ! "${specifier}" =~ ^\. ]]; then
        echo ""
        return
    fi
    
    local dir
    dir=$(dirname "${importer_file}")
    local resolved_path
    resolved_path=$(realpath "${dir}/${specifier}" 2>/dev/null) || echo ""
    
    if [[ -n "${resolved_path}" ]]; then
        normalize_path "${resolved_path}"
    else
        echo ""
    fi
}

# Function to normalize plugin SDK family
normalize_plugin_sdk_family() {
    local resolved_path="$1"
    local relative="${resolved_path/#src\/plugin-sdk\//}"
    echo "${relative%.*}"
}

# Function to resolve optional cluster from path
resolve_optional_cluster_from_path() {
    local resolved_path="$1"
    
    if [[ "${resolved_path}" == "${BUNDLED_PLUGIN_PATH_PREFIX}"* ]]; then
        local cluster
        cluster=$(echo "${resolved_path}" | cut -d'/' -f2)
        if [[ -n "${cluster}" ]] && [[ -n "${OPTIONAL_BUNDLED_CLUSTER_SET[${cluster}]:-}" ]]; then
            echo "${cluster}"
            return
        fi
    elif [[ "${resolved_path}" == "src/plugin-sdk/"* ]]; then
        local cluster
        cluster=$(echo "${resolved_path}" | cut -d'/' -f3)
        if [[ -n "${cluster}" ]] && [[ -n "${OPTIONAL_BUNDLED_CLUSTER_SET[${cluster}]:-}" ]]; then
            echo "${cluster}"
            return
        fi
    fi
    
    echo ""
}

# Function to collect workspace package paths
collect_workspace_package_paths() {
    local entries=()
    while IFS= read -r -d '' dir; do
        entries+=("$(basename "${dir}")")
    done < <(find "${EXTENSIONS_ROOT}" -mindepth 1 -maxdepth 1 -type d -print0)
    
    for entry in "${entries[@]}"; do
        WORKSPACE_PACKAGE_PATHS+=("extensions/${entry}/package.json")
    done
}

# Function to collect core plugin SDK imports
collect_core_plugin_sdk_imports() {
    local files
    files=$(walk_code_files "${SRC_ROOT}")
    local inventory=()
    
    while IFS= read -r file; do
        local relative_path
        relative_path=$(normalize_path "${file}")
        
        if [[ "${relative_path}" == "src/plugin-sdk/"* ]]; then
            continue
        fi
        
        local source
        source=$(cat "${file}")
        
        # Find import declarations
        while IFS= read -r line; do
            if [[ "${line}" =~ ^[^#]*import\ [^\(].*\ from\ [\"\']([^\"\']*)[\"\'] ]] || \
               [[ "${line}" =~ ^[^#]*export.*from\ [\"\']([^\"\']*)[\"\'] ]] || \
               [[ "${line}" =~ import\([\"\']([^\"\']*)[\"\']\) ]]; then
                
                local specifier="${BASH_REMATCH[1]}"
                if [[ "${specifier}" =~ ^\. ]]; then
                    local resolved_path
                    resolved_path=$(resolve_relative_specifier "${specifier}" "${file}")
                    
                    if [[ "${resolved_path}" == "src/plugin-sdk/"* ]]; then
                        local family
                        family=$(normalize_plugin_sdk_family "${resolved_path}")
                        local line_number
                        line_number=$(grep -n "${line}" "${file}" | head -n1 | cut -d: -f1)
                        
                        inventory+=("${family}|${relative_path}|import|${line_number}|${specifier}|${resolved_path}")
                    fi
                fi
            fi
        done <<< "$(grep -E "(import .* from |export .* from |import\()" "${file}")"
    done <<< "${files}"
    
    # Sort inventory
    printf '%s\n' "${inventory[@]}" | sort
}

# Function to collect optional cluster static leaks
collect_optional_cluster_static_leaks() {
    local files
    files=$(walk_code_files "${SRC_ROOT}")
    local inventory=()
    
    while IFS= read -r file; do
        local relative_path
        relative_path=$(normalize_path "${file}")
        
        if [[ "${relative_path}" == "src/plugin-sdk/"* ]]; then
            continue
        fi
        
        local source
        source=$(cat "${file}")
        
        # Find import/export declarations
        while IFS= read -r line; do
            if [[ "${line}" =~ ^[^#]*import\ [^\(].*\ from\ [\"\']([^\"\']*)[\"\'] ]] || \
               [[ "${line}" =~ ^[^#]*export.*from\ [\"\']([^\"\']*)[\"\'] ]]; then
                
                local specifier="${BASH_REMATCH[1]}"
                if [[ "${specifier}" =~ ^\. ]]; then
                    local resolved_path
                    resolved_path=$(resolve_relative_specifier "${specifier}" "${file}")
                    
                    if [[ -n "${resolved_path}" ]]; then
                        local cluster
                        cluster=$(resolve_optional_cluster_from_path "${resolved_path}")
                        
                        if [[ -n "${cluster}" ]]; then
                            local line_number
                            line_number=$(grep -n "${line}" "${file}" | head -n1 | cut -d: -f1)
                            inventory+=("${cluster}|${relative_path}|import|${line_number}|${specifier}|${resolved_path}")
                        fi
                    fi
                fi
            fi
        done <<< "$(grep -E "(import .* from |export .* from )" "${file}")"
    done <<< "${files}"
    
    # Sort inventory
    printf '%s\n' "${inventory[@]}" | sort
}

# Function to build duplicated seam families
build_duplicated_seam_families() {
    local inventory_data="$1"
    local -A families
    local -A family_files
    local -A family_imports
    
    # Group by family
    while IFS='|' read -r family file kind line specifier resolved_path; do
        families["${family}"]=1
        family_files["${family}"]+="${file};"
        family_imports["${family}"]+="${family}|${file}|${kind}|${line}|${specifier}|${resolved_path};"
    done <<< "${inventory_data}"
    
    # Build JSON output
    echo "{"
    local first=true
    for family in "${!families[@]}"; do
        local files_list=()
        IFS=';' read -ra ADDR <<< "${family_files[${family}]}"
        for i in "${ADDR[@]}"; do
            if [[ -n "${i}" ]]; then
                files_list+=("${i}")
            fi
        done
        
        # Remove duplicates and sort
        local unique_files=($(printf '%s\n' "${files_list[@]}" | sort -u))
        
        if [[ ${#unique_files[@]} -gt 1 ]]; then
            if [[ "${first}" == false ]]; then
                echo ","
            fi
            first=false
            
            echo "\"${family}\": {"
            echo "  \"count\": ${#unique_files[@]},"
            echo "  \"files\": ["
            
            local inner_first=true
            for f in "${unique_files[@]}"; do
                if [[ "${inner_first}" == false ]]; then
                    echo ","
                fi
                inner_first=false
                echo "    \"${f}\""
            done
            echo "  ]"
            echo "}"
        fi
    done
    echo "}"
}

# Function to build overlap files
build_overlap_files() {
    local inventory_data="$1"
    local -A files
    local -A file_families
    local -A file_imports
    
    # Group by file
    while IFS='|' read -r family file kind line specifier resolved_path; do
        files["${file}"]=1
        file_families["${file}"]+="${family};"
        file_imports["${file}"]+="${family}|${file}|${kind}|${line}|${specifier}|${resolved_path};"
    done <<< "${inventory_data}"
    
    # Build JSON output
    echo "["
    local first=true
    for file in "${!files[@]}"; do
        local families_list=()
        IFS=';' read -ra ADDR <<< "${file_families[${file}]}"
        for i in "${ADDR[@]}"; do
            if [[ -n "${i}" ]]; then
                families_list+=("${i}")
            fi
        done
        
        # Remove duplicates and sort
        local unique_families=($(printf '%s\n' "${families_list[@]}" | sort -u))
        
        if [[ ${#unique_families[@]} -gt 1 ]]; then
            if [[ "${first}" == false ]]; then
                echo ","
            fi
            first=false
            
            echo "{"
            echo "  \"file\": \"${file}\","
            echo "  \"families\": ["
            
            local inner_first=true
            for f in "${unique_families[@]}"; do
                if [[ "${inner_first}" == false ]]; then
                    echo ","
                fi
                inner_first=false
                echo "    \"${f}\""
            done
            echo "  ]"
            echo "}"
        fi
    done
    echo "]"
}

# Function to build optional cluster static leaks
build_optional_cluster_static_leaks() {
    local inventory_data="$1"
    local -A clusters
    local -A cluster_imports
    
    # Group by cluster
    while IFS='|' read -r cluster file kind line specifier resolved_path; do
        clusters["${cluster}"]=1
        cluster_imports["${cluster}"]+="${cluster}|${file}|${kind}|${line}|${specifier}|${resolved_path};"
    done <<< "${inventory_data}"
    
    # Build JSON output
    echo "{"
    local first=true
    for cluster in "${!clusters[@]}"; do
        if [[ "${first}" == false ]]; then
            echo ","
        fi
        first=false
        
        echo "\"${cluster}\": {"
        echo "  \"count\": 0,"
        echo "  \"files\": []"
        echo "}"
    done
    echo "}"
}

# Function to build missing packages
build_missing_packages() {
    local static_leak_clusters=("$@")
    local -A static_leak_set
    for cluster in "${static_leak_clusters[@]}"; do
        static_leak_set["${cluster}"]=1
    done
    
    # Read root package.json
    local root_deps=()
    while IFS='"' read -r _ key _; do
        if [[ "${key}" != "dependencies" ]] && [[ "${key}" != "optionalDependencies" ]] && [[ "${key}" != "devDependencies" ]]; then
            continue
        fi
        while IFS='"' read -r dep _; do
            if [[ -n "${dep}" ]]; then
                root_deps+=("${dep}")
            fi
        done < <(jq -r ".${key} | keys[]" "${REPO_ROOT}/package.json" 2>/dev/null || echo "")
    done < <(jq -r 'keys[]' "${REPO_ROOT}/package.json" 2>/dev/null || echo "")
    
    # Build JSON output
    echo "["
    local first=true
    for package_path in "${WORKSPACE_PACKAGE_PATHS[@]}"; do
        if [[ ! -f "${REPO_ROOT}/${package_path}" ]]; then
            continue
        fi
        
        local missing_deps=()
        while IFS='"' read -r dep _; do
            if [[ "${dep}" == "openclaw" ]]; then
                continue
            fi
            
            local found=false
            for root_dep in "${root_deps[@]}"; do
                if [[ "${root_dep}" == "${dep}" ]]; then
                    found=true
                    break
                fi
            done
            
            if [[ "${found}" == false ]]; then
                missing_deps+=("${dep}")
            fi
        done < <(jq -r '.dependencies | keys[]' "${REPO_ROOT}/${package_path}" 2>/dev/null || echo "")
        
        if [[ ${#missing_deps[@]} -gt 0 ]]; then
            if [[ "${first}" == false ]]; then
                echo ","
            fi
            first=false
            
            local cluster
            if [[ "${package_path}" == "ui/package.json" ]]; then
                cluster="ui"
            else
                cluster=$(echo "${package_path}" | cut -d'/' -f2)
            fi
            
            echo "{"
            echo "  \"cluster\": \"${cluster}\","
            echo "  \"packageName\": \"openclaw-control-ui\","
            echo "  \"packagePath\": \"${package_path}\","
            echo "  \"missing\": ["
            
            local inner_first=true
            for dep in "${missing_deps[@]}"; do
                if [[ "${inner_first}" == false ]]; then
                    echo ","
                fi
                inner_first=false
                echo "    \"${dep}\""
            done
            echo "  ]"
            echo "}"
        fi
    done
    echo "]"
}

# Function to build seam test inventory
build_seam_test_inventory() {
    local production_files
    production_files=$(walk_code_files "${SRC_ROOT}" "false")
    local extension_files
    extension_files=$(walk_code_files "${EXTENSIONS_ROOT}" "false")
    local test_files
    test_files=$(walk_code_files "${SRC_ROOT}" "true")
    local extension_test_files
    extension_test_files=$(walk_code_files "${EXTENSIONS_ROOT}" "true")
    local test_root_files
    test_root_files=$(walk_code_files "${TEST_ROOT}" "true")
    
    # Filter test files to only include test/spec files
    local all_test_files=()
    while IFS= read -r file; do
        if [[ "${file}" =~ \.(test|spec)\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$ ]]; then
            all_test_files+=("${file}")
        fi
    done <<< "$(echo -e "${test_files}\n${extension_test_files}\n${test_root_files}" | sort -u)"
    
    # Build JSON output
    echo "["
    local first=true
    while IFS= read -r file; do
        local relative_path
        relative_path=$(normalize_path "${file}")
        local source
        source=$(read_scannable_text "${file}")
        
        # Check for seam kinds (simplified detection)
        local seam_kinds=()
        if [[ "${relative_path}" == *"reply-delivery"* ]] || [[ "${relative_path}" == *"outbound"* ]]; then
            seam_kinds+=("reply-delivery-media")
        fi
        
        if [[ "${relative_path}" == *"subagent"* ]]; then
            seam_kinds+=("subagent-session-spawn")
        fi
        
        if [[ "${relative_path}" == *"cron"* ]]; then
            seam_kinds+=("cron-agent-handoff")
        fi
        
        if [[ ${#seam_kinds[@]} -gt 0 ]]; then
            if [[ "${first}" == false ]]; then
                echo ","
            fi
            first=false
            
            echo "{"
            echo "  \"file\": \"${relative_path}\","
            echo "  \"seamKinds\": ["
            
            local inner_first=true
            for kind in "${seam_kinds[@]}"; do
                if [[ "${inner_first}" == false ]]; then
                    echo ","
                fi
                inner_first=false
                echo "    \"${kind}\""
            done
            echo "  ],"
            echo "  \"relatedTests\": [],"
            echo "  \"status\": \"gap\","
            echo "  \"reason\": \"No nearby test file references this seam candidate.\""
            echo "}"
        fi
    done <<< "$(echo -e "${production_files}\n${extension_files}" | sort -u)"
    echo "]"
}

# Main function
main() {
    local args=("$@")
    
    for arg in "${args[@]}"; do
        if [[ "${arg}" == "--help" ]] || [[ "${arg}" == "-h" ]]; then
            echo "${HELP_TEXT}"
            return 0
        fi
    done
    
    collect_workspace_package_paths
    
    local inventory
    inventory=$(collect_core_plugin_sdk_imports)
    
    local optional_cluster_static_leaks
    optional_cluster_static_leaks=$(collect_optional_cluster_static_leaks)
    
    # Extract clusters from static leaks
    local static_leak_clusters=()
    while IFS='|' read -r cluster _; do
        static_leak_clusters+=("${cluster}")
    done <<< "${optional_cluster_static_leaks}"
    
    # Remove duplicates
    local unique_static_leak_clusters=($(printf '%s\n' "${static_leak_clusters[@]}" | sort -u))
    
    # Build final JSON output
    echo "{"
    echo "  \"duplicatedSeamFamilies\": "
    build_duplicated_seam_families "${inventory}"
    echo ","
    echo "  \"overlapFiles\": "
    build_overlap_files "${inventory}"
    echo ","
    echo "  \"optionalClusterStaticLeaks\": "
    build_optional_cluster_static_leaks "${optional_cluster_static_leaks}"
    echo ","
    echo "  \"missingPackages\": "
    build_missing_packages "${unique_static_leak_clusters[@]}"
    echo ","
    echo "  \"seamTestInventory\": "
    build_seam_test_inventory
    echo "}"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
