#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "38ffc74c0c38b75c577c9a9b48b5140b0535921ab6823ef5c3d035d85a7eaec9", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "shell"}
# pplx-inject.mjs — portiert nach shell
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> bash pplx-inject.sh <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
#
# Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
# JSON array (Cookie-Editor / Playwright export).

PROFILE="${PERPLEXITY_PROFILE:-codespace}"
EMAIL="${PPLX_EMAIL:-KarimKiki@gmx.de}"

if [[ $# -lt 1 ]]; then
    echo "usage: bash pplx-inject.sh <cookies-file>" >&2
    exit 1
fi
file="$1"

# --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
DIST="${PPLX_DIST:-}"
if [[ -z "$DIST" || ! -d "$DIST" ]]; then
    DIST=$(find "$HOME/.npm/_npx" -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1 || true)
    DIST="${DIST%%$'\n'*}"
fi
if [[ -z "$DIST" || ! -d "$DIST" ]]; then
    echo "cannot locate perplexity-user-mcp/dist (set PPLX_DIST)" >&2
    exit 1
fi

# Resolve chunks by following the package's own imports in a stable entry file.
# esbuild minifies class/function names, so we trust the runner's import map.
chunkFor() {
    local symbol="$1"
    shift
    local entries=("$@")
    if [[ ${#entries[@]} -eq 0 ]]; then
        entries=("manual-login-runner.mjs" "login-runner.mjs" "cli.mjs")
    fi
    
    for entry in "${entries[@]}"; do
        if [[ ! -f "$DIST/$entry" ]]; then
            continue
        fi
        
        local src
        src=$(<"$DIST/$entry")
        while IFS= read -r line; do
            if [[ "$line" =~ import\ *\{([^}]*)\}\ *from\ *\"(\./chunk-[^\"]+\.mjs)\" ]]; then
                local names_str="${BASH_REMATCH[1]}"
                local chunk_path="${BASH_REMATCH[2]}"
                IFS=',' read -ra names <<< "$names_str"
                for name in "${names[@]}"; do
                    name="${name// /}"
                    name="${name%%as*}"
                    name="${name//\"/}"
                    if [[ "$name" == "$symbol" ]]; then
                        echo "$DIST/${chunk_path#./}"
                        return 0
                    fi
                done
            fi
        done <<< "$src"
    done
    return 1
}

vaultChunk=$(chunkFor "Vault") || true
profChunk=$(chunkFor "getProfilePaths") || true
if [[ -z "$vaultChunk" || -z "$profChunk" ]]; then
    echo "could not locate Vault/profile chunks in dist" >&2
    exit 1
fi

# --- parse the cookie input (token / header / JSON) ---
text=$(<"$file")
text="${text//$'\r'/}"
text="${text%%[[:space:]]*}"
text="${text##*[[:space:]]}"

if [[ "$text" =~ ^[\[\{] ]]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required for JSON parsing" >&2
        exit 1
    fi
    
    if [[ "$text" =~ ^\{ ]]; then
        raw=$(jq -c '.cookies // .' <<< "$text")
    else
        raw="$text"
    fi
    
    if ! jq -e 'type == "array"' <<< "$raw" >/dev/null 2>&1; then
        echo "expected a JSON array of cookies" >&2
        exit 1
    fi
    
    cookie_count=$(jq 'length' <<< "$raw")
    cookies_json="$raw"
    
elif [[ "$text" =~ ^eyJ && ! "$text" =~ = && ! "$text" =~ \; ]]; then
    cookie_count=1
    cookies_json="[{\"name\":\"__Secure-next-auth.session-token\",\"value\":\"$text\"}]"
else
    IFS=';' read -ra cookie_parts <<< "$text"
    cookie_array=()
    for part in "${cookie_parts[@]}"; do
        part="${part// /}"
        if [[ "$part" =~ = ]]; then
            IFS='=' read -r name value <<< "$part"
            cookie_array+=("{\"name\":\"$name\",\"value\":\"$value\"}")
        fi
    done
    cookie_count="${#cookie_array[@]}"
    cookies_json="[$(IFS=,; echo "${cookie_array[*]}")]"
fi

# Filter and normalize cookies
filtered_cookies=$(jq -c '
    map(select(.name and .value))
    | map(select((.domain | contains("perplexity.ai")) or (.domain | not)))
    | map({
        name: .name,
        value: .value,
        domain: (if (.domain and (.domain | contains("perplexity"))) then .domain else ".perplexity.ai" end),
        path: (.path // "/"),
        expires: (if (.expires | type == "number") then (.expires | floor) else (if (.expirationDate | type == "number") then (.expirationDate | floor) else -1 end) end),
        httpOnly: (if .httpOnly then true else false end),
        secure: (if (.secure == false) then false else true end),
        sameSite: (
            if (.sameSite | type == "string") then 
                (if (.sameSite | ascii_downcase == "no_restriction" or .sameSite | ascii_downcase == "none") then "None"
                else if (.sameSite | ascii_downcase == "strict") then "Strict"
                else "Lax" end end)
            else "Lax" end
        )
    })
' <<< "$cookies_json")

cookie_names=$(jq -r '.[].name' <<< "$filtered_cookies")
echo "Parsed $cookie_count perplexity.ai cookies: $(tr '\n' ',' <<< "$cookie_names" | sed 's/,$//')"

if ! grep -q "__Secure-next-auth.session-token" <<< "$cookie_names"; then
    echo "WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate." >&2
fi

# Get profile paths using node to execute the chunk
get_profile_paths() {
    node -e "
        import('$profChunk').then(({ getProfilePaths }) => {
            const paths = getProfilePaths('$PROFILE');
            console.log(JSON.stringify(paths));
        }).catch(console.error);
    "
}

paths_json=$(get_profile_paths)
profile_dir=$(jq -r '.dir' <<< "$paths_json")
models_cache=$(jq -r '.modelsCache' <<< "$paths_json")
reinit_file=$(jq -r '.reinit' <<< "$paths_json")

mkdir -p "$profile_dir"

# Initialize vault and set values using node
node -e "
import('$vaultChunk').then(({ Vault }) => {
    const vault = new Vault();
    return vault.set('$PROFILE', 'cookies', '$filtered_cookies')
        .then(() => vault.set('$PROFILE', 'email', '$EMAIL'))
        .then(() => {
            const fs = require('fs');
            if (!fs.existsSync('$models_cache')) {
                fs.writeFileSync('$models_cache', JSON.stringify({ models: {} }, null, 2));
            }
            
            const { recordLoginSuccess } = require('$profChunk');
            recordLoginSuccess('$PROFILE', { 
                tier: 'pro', 
                loginMode: 'manual', 
                lastLogin: new Date().toISOString() 
            });
            
            fs.writeFileSync('$reinit_file', Date.now().toString());
            console.log('OK: injected $cookie_count cookie(s) into vault profile \\'$PROFILE\\'.');
        });
}).catch(err => {
    console.error(err);
    process.exit(1);
});
"
