#!/bin/bash
# package_artifacts.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(realpath "$SCRIPT_DIR/../..")"
readonly PROJECT_ROOT="$(realpath "$ROOT/..")"
readonly EXCLUDED_PARTS=("__pycache__" ".gradle" ".kotlin" ".cxx" "build" "DerivedData" "xcuserdata" "Pods")
readonly EXCLUDED_SUFFIXES=(".pyc" ".aar")

# Funktionen
add_tree() {
    local archive="$1"
    local source="$2"
    local prefix="${3:-}"

    # Finde alle Dateien rekursiv im Quellverzeichnis
    find "$source" -type f | sort | while read -r file; do
        # Prüfe ob Datei in ausgeschlossenen Ordnern liegt
        local skip=false
        for part in "${EXCLUDED_PARTS[@]}"; do
            if [[ "$file" == *"/$part/"* ]] || [[ "$file" == *"/$part" ]]; then
                skip=true
                break
            fi
        done
        
        # Prüfe auf ausgeschlossene Suffixe
        if ! $skip; then
            for suffix in "${EXCLUDED_SUFFIXES[@]}"; do
                if [[ "$file" == *"$suffix" ]]; then
                    skip=true
                    break
                fi
            done
        fi
        
        if $skip; then
            continue
        fi

        # Berechne relativen Pfad
        local relative_path="${file#$source/}"
        local archive_path="$relative_path"
        if [[ -n "$prefix" ]]; then
            archive_path="$prefix/$relative_path"
        fi

        # Setze Dateiberechtigungen basierend auf Dateiname
        local permissions="644"
        if [[ "$(basename "$file")" == "gradlew" ]]; then
            permissions="755"
        fi

        # Füge Datei zum ZIP-Archiv hinzu
        zip --junk-paths --names-stdin "$archive" <<< "$archive_path" < "$file"
    done
}

# Hauptskript
main() {
    local output_dir=""
    local android_apk=""
    local android_source="$PROJECT_ROOT/mobile/android"
    local ios_source="$PROJECT_ROOT/mobile/ios"
    local native_shared_source="$PROJECT_ROOT/mobile/shared"

    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --android-apk)
                android_apk="$2"
                shift 2
                ;;
            --android-source)
                android_source="$2"
                shift 2
                ;;
            --ios-source)
                ios_source="$2"
                shift 2
                ;;
            --native-shared-source)
                native_shared_source="$2"
                shift 2
                ;;
            *)
                echo "Unbekanntes Argument: $1" >&2
                exit 1
                ;;
        esac
    done

    if [[ -z "$output_dir" ]]; then
        echo "--output-dir ist erforderlich" >&2
        exit 1
    fi

    # Ausgabeverzeichnis erstellen
    mkdir -p "$output_dir"
    output_dir="$(realpath "$output_dir")"

    # Version aus manifest.json lesen
    local manifest_file="$ROOT/browser-extension/manifest.json"
    if [[ ! -f "$manifest_file" ]]; then
        echo "manifest.json nicht gefunden: $manifest_file" >&2
        exit 1
    fi
    
    local version
    version=$(jq -r '.version' "$manifest_file")
    if [[ "$version" == "null" ]] || [[ -z "$version" ]]; then
        echo "Konnte Version aus manifest.json nicht extrahieren" >&2
        exit 1
    fi

    # Artefakte definieren
    local extension_zip="$output_dir/tiktok-live-companion-extension-$version.zip"
    local plugin_zip="$output_dir/tiktok-live-companion-plugin-$version.zip"
    local service_zip="$output_dir/tiktok-live-companion-service-$version.zip"
    local ios_source_zip="$output_dir/tiktok-live-companion-ios-$version-source.zip"
    local android_source_zip="$output_dir/tiktok-live-companion-android-$version-source.zip"
    local android_apk_file="$output_dir/tiktok-live-companion-android-$version.apk"
    local extension_dir="$output_dir/tiktok-live-companion-extension-$version"
    local checksum_file="$output_dir/tiktok-live-companion-$version-SHA256.txt"

    # Extension-Verzeichnis bereinigen und kopieren
    if [[ -d "$extension_dir" ]]; then
        rm -rf "$extension_dir"
    fi
    
    cp -r "$ROOT/browser-extension" "$extension_dir"
    cp -r "$ROOT/companion-service" "$extension_dir/companion-service"
    
    cat > "$extension_dir/Sprachdienst-reparieren.cmd" << 'EOF'
@echo off
call "%~dp0companion-service\Sprachdienst-reparieren.cmd"
EOF

    # package.json erstellen
    jq -n --arg version "$version" '{
        name: "tiktok-live-companion-extension-package",
        private: true,
        version: $version,
        scripts: {
            setup: "npm --prefix companion-service run setup --",
            start: "npm --prefix companion-service start",
            test: "npm --prefix companion-service test"
        }
    }' > "$extension_dir/package.json"

    # ZIP-Dateien erstellen
    zip -rq "$extension_zip" "$extension_dir"
    zip -rq "$plugin_zip" "$ROOT" --exclude "*/.*/*" "*/build/*" "*/node_modules/*" "*/dist/*" "*/out/*"
    zip -rq "$service_zip" "$ROOT/companion-service" --exclude "*/.*/*" "*/node_modules/*" "*/dist/*"

    # Mobile Source ZIPs erstellen
    ios_source="$(realpath "$ios_source")"
    android_source="$(realpath "$android_source")"
    native_shared_source="$(realpath "$native_shared_source")"
    
    if [[ ! -d "$ios_source" ]] || [[ ! -d "$android_source" ]]; then
        echo "--ios-source und --android-source müssen auf existierende Verzeichnisse zeigen" >&2
        exit 1
    fi
    
    if [[ ! -f "$native_shared_source/native/tlc_peak_limiter.h" ]]; then
        echo "Gemeinsame native Limiter-Quelle ist für beide mobilen Quellpakete erforderlich" >&2
        exit 1
    fi

    # iOS Source ZIP
    temp_ios_dir=$(mktemp -d)
    trap 'rm -rf "$temp_ios_dir"' EXIT
    cp -r "$ios_source" "$temp_ios_dir/TikTokLiveCompanion-iOS"
    cp -r "$native_shared_source" "$temp_ios_dir/shared"
    zip -rq "$ios_source_zip" "$temp_ios_dir"/*
    rm -rf "$temp_ios_dir"

    # Android Source ZIP
    temp_android_dir=$(mktemp -d)
    trap 'rm -rf "$temp_android_dir"' EXIT
    cp -r "$android_source" "$temp_android_dir/TikTokLiveCompanion-Android"
    cp -r "$native_shared_source" "$temp_android_dir/shared"
    zip -rq "$android_source_zip" "$temp_android_dir"/*
    rm -rf "$temp_android_dir"

    # Android APK kopieren falls angegeben
    if [[ -n "$android_apk" ]]; then
        android_apk="$(realpath "$android_apk")"
        if [[ ! -f "$android_apk" ]] || [[ "${android_apk##*.}" != "apk" ]]; then
            echo "--android-apk muss auf eine vorhandene APK-Datei verweisen" >&2
            exit 1
        fi
        
        if [[ "$(realpath "$android_apk")" != "$(realpath "$android_apk_file")" ]]; then
            cp "$android_apk" "$android_apk_file"
        fi
    fi

    # Checksummen berechnen
    local artifacts=("$extension_zip" "$plugin_zip" "$service_zip" "$ios_source_zip" "$android_source_zip")
    if [[ -f "$android_apk_file" ]]; then
        artifacts+=("$android_apk_file")
    fi
    
    {
        for artifact in "${artifacts[@]}"; do
            local sha256_hash
            sha256_hash=$(sha256sum "$artifact" | cut -d' ' -f1)
            echo "$sha256_hash  $(basename "$artifact")"
        done
    } > "$checksum_file"

    # JSON-Ausgabe erstellen
    local android_apk_json_value="null"
    if [[ -f "$android_apk_file" ]]; then
        android_apk_json_value="\"$(realpath "$android_apk_file")\""
    fi
    
    jq -n \
        --arg extension_dir "$(realpath "$extension_dir")" \
        --arg extension_zip "$(realpath "$extension_zip")" \
        --arg plugin_zip "$(realpath "$plugin_zip")" \
        --arg service_zip "$(realpath "$service_zip")" \
        --arg ios_source_zip "$(realpath "$ios_source_zip")" \
        --arg android_source_zip "$(realpath "$android_source_zip")" \
        --arg android_apk "$android_apk_json_value" \
        --arg checksum_file "$(realpath "$checksum_file")" \
        --arg version "$version" \
        '{
            extension_dir: $extension_dir,
            extension_zip: $extension_zip,
            plugin_zip: $plugin_zip,
            service_zip: $service_zip,
            ios_source_zip: $ios_source_zip,
            android_source_zip: $android_source_zip,
            android_apk: ($android_apk | fromjson),
            checksum_file: $checksum_file,
            version: $version
        }'
}

main "$@"
