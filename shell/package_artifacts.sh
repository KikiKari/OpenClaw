#!/bin/bash
# package_artifacts.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(dirname "$SCRIPT_DIR")"
readonly PROJECT_ROOT="$(dirname "$ROOT")"
readonly EXCLUDED_PARTS="__pycache__ .gradle .kotlin .cxx build DerivedData xcuserdata Pods"
readonly EXCLUDED_SUFFIXES=".pyc .aar"

# Funktion zur Bestimmung des relativen Pfads
relpath() {
    local target="$1"
    local base="${2:-$PWD}"
    python3 -c "import os.path; print(os.path.relpath('$target', '$base'))"
}

# Funktion zum Hinzufügen eines Verzeichnisbaums zum ZIP-Archiv
add_tree() {
    local archive="$1"
    local source="$2"
    local prefix="${3:-}"

    # Finde alle Dateien im Quellverzeichnis
    find "$source" -type f | while IFS= read -r file; do
        # Überprüfe ausgeschlossene Teile im Pfad
        local exclude_file=false
        for part in $EXCLUDED_PARTS; do
            if [[ "$file" == *"/$part/"* ]] || [[ "$file" == *"/$part" ]]; then
                exclude_file=true
                break
            fi
        done

        # Überprüfe ausgeschlossene Suffixe
        if [ "$exclude_file" = false ]; then
            for suffix in $EXCLUDED_SUFFIXES; do
                if [[ "$file" == *"$suffix" ]]; then
                    exclude_file=true
                    break
                fi
            done
        fi

        # Überspringe ausgeschlossene Dateien
        if [ "$exclude_file" = true ]; then
            continue
        fi

        # Berechne den relativen Pfad
        local relative_path
        relative_path=$(relpath "$file" "$source")
        local archive_path="${prefix:+$prefix/}$relative_path"

        # Entferne führende Schrägstriche
        archive_path="${archive_path#/}"

        # Setze die Zugriffsrechte basierend auf dem Dateinamen
        local permissions="644"
        if [[ "$(basename "$file")" == "gradlew" ]]; then
            permissions="755"
        fi

        # Füge die Datei zum ZIP-Archiv hinzu
        zip -j "$archive" "$file" -X -9 >/dev/null
        # Setze die externen Attribute manuell (Unix-Zugriffsrechte)
        # Dies ist eine Vereinfachung, da Bash keine direkte Möglichkeit bietet,
        # die externen Attribute wie in Python zu setzen.
        # In einer produktiven Umgebung könnte dies durch eine spezielle ZIP-Bibliothek verbessert werden.
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

    # Überprüfe erforderliche Argumente
    if [[ -z "$output_dir" ]]; then
        echo "--output-dir ist erforderlich" >&2
        exit 1
    fi

    # Erstelle das Ausgabeverzeichnis
    mkdir -p "$output_dir"
    output_dir="$(realpath "$output_dir")"

    # Lese die Version aus der Manifestdatei
    local manifest="$ROOT/browser-extension/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        echo "Manifestdatei nicht gefunden: $manifest" >&2
        exit 1
    fi
    local version
    version=$(jq -r '.version' "$manifest")

    # Definiere die Artefaktpfade
    local extension_zip="$output_dir/tiktok-live-companion-extension-$version.zip"
    local plugin_zip="$output_dir/tiktok-live-companion-plugin-$version.zip"
    local service_zip="$output_dir/tiktok-live-companion-service-$version.zip"
    local ios_source_zip="$output_dir/tiktok-live-companion-ios-$version-source.zip"
    local android_source_zip="$output_dir/tiktok-live-companion-android-$version-source.zip"
    local android_apk_out="$output_dir/tiktok-live-companion-android-$version.apk"
    local extension_dir="$output_dir/tiktok-live-companion-extension-$version"
    local checksum_file="$output_dir/tiktok-live-companion-$version-SHA256.txt"

    # Überprüfe, ob das Erweiterungsverzeichnis im Ausgabeverzeichnis liegt
    local resolved_extension_dir
    resolved_extension_dir="$(realpath "$extension_dir" 2>/dev/null || echo "$extension_dir")"
    if [[ "$(dirname "$resolved_extension_dir")" != "$output_dir" ]]; then
        echo "Refusing to package outside the requested output directory" >&2
        exit 1
    fi

    # Entferne vorhandenes Erweiterungsverzeichnis
    if [[ -d "$extension_dir" ]]; then
        rm -rf "$extension_dir"
    fi

    # Kopiere Browser-Erweiterung
    cp -r "$ROOT/browser-extension" "$extension_dir"

    # Kopiere Begleitdienst
    cp -r "$ROOT/companion-service" "$extension_dir/companion-service"

    # Erstelle Reparatur-Skript für Sprachdienst
    cat > "$extension_dir/Sprachdienst-reparieren.cmd" << 'EOF'
@echo off
call "%~dp0companion-service\Sprachdienst-reparieren.cmd"
EOF

    # Erstelle package.json
    jq -n \
        --arg name "tiktok-live-companion-extension-package" \
        --arg version "$version" \
        '{
            name: $name,
            private: true,
            version: $version,
            scripts: {
                setup: "npm --prefix companion-service run setup --",
                start: "npm --prefix companion-service start",
                test: "npm --prefix companion-service test"
            }
        }' > "$extension_dir/package.json"

    # Erstelle ZIP-Archive
    # Extension ZIP
    (
        cd "$extension_dir" || exit 1
        zip -r "$extension_zip" . -X -9 >/dev/null
    )

    # Plugin ZIP
    (
        cd "$ROOT" || exit 1
        zip -r "$plugin_zip" . -X -9 >/dev/null
        # Entferne unerwünschte Dateien aus dem Plugin-Archiv
        zip -d "$plugin_zip" "*/__pycache__/*" "__pycache__/*" "*/.gradle/*" ".gradle/*" "*/.kotlin/*" ".kotlin/*" "*/.cxx/*" ".cxx/*" "*/build/*" "build/*" "*/DerivedData/*" "DerivedData/*" "*/xcuserdata/*" "xcuserdata/*" "*/Pods/*" "Pods/*" "*.pyc" "*.aar" >/dev/null
    )

    # Service ZIP
    (
        cd "$ROOT/companion-service" || exit 1
        zip -r "$service_zip" . -X -9 >/dev/null
        # Entferne unerwünschte Dateien aus dem Service-Archiv
        zip -d "$service_zip" "*/__pycache__/*" "__pycache__/*" "*/.gradle/*" ".gradle/*" "*/.kotlin/*" ".kotlin/*" "*/.cxx/*" ".cxx/*" "*/build/*" "build/*" "*/DerivedData/*" "DerivedData/*" "*/xcuserdata/*" "xcuserdata/*" "*/Pods/*" "Pods/*" "*.pyc" "*.aar" >/dev/null
    )

    # Überprüfe Quellverzeichnisse
    if [[ ! -d "$ios_source" ]] || [[ ! -d "$android_source" ]]; then
        echo "--ios-source and --android-source must point to existing source directories" >&2
        exit 1
    fi

    # Überprüfe gemeinsame native Quelle
    if [[ ! -f "$native_shared_source/native/tlc_peak_limiter.h" ]]; then
        echo "Shared native limiter source is required for both mobile source packages" >&2
        exit 1
    fi

    # iOS Source ZIP
    (
        cd "$(dirname "$ios_source")" || exit 1
        zip -r "$ios_source_zip" "$(basename "$ios_source")" -X -9 >/dev/null
        # Entferne unerwünschte Dateien aus dem iOS-Quellarchiv
        zip -d "$ios_source_zip" "*/__pycache__/*" "__pycache__/*" "*/.gradle/*" ".gradle/*" "*/.kotlin/*" ".kotlin/*" "*/.cxx/*" ".cxx/*" "*/build/*" "build/*" "*/DerivedData/*" "DerivedData/*" "*/xcuserdata/*" "xcuserdata/*" "*/Pods/*" "Pods/*" "*.pyc" "*.aar" >/dev/null
    )
    # Füge gemeinsame native Quelle hinzu
    (
        cd "$(dirname "$native_shared_source")" || exit 1
        zip -r "$ios_source_zip" "$(basename "$native_shared_source")" -X -9 >/dev/null
        # Entferne unerwünschte Dateien aus dem gemeinsamen Archiv
        zip -d "$ios_source_zip" "*/__pycache__/*" "__pycache__/*" "*/.gradle/*" ".gradle/*" "*/.kotlin/*" ".kotlin/*" "*/.cxx/*" ".cxx/*" "*/build/*" "build/*" "*/DerivedData/*" "DerivedData/*" "*/xcuserdata/*" "xcuserdata/*" "*/Pods/*" "Pods/*" "*.pyc" "*.aar" >/dev/null
    )

    # Android Source ZIP
    (
        cd "$(dirname "$android_source")" || exit 1
        zip -r "$android_source_zip" "$(basename "$android_source")" -X -9 >/dev/null
        # Entferne unerwünschte Dateien aus dem Android-Quellarchiv
        zip -d "$android_source_zip" "*/__pycache__/*" "__pycache__/*" "*/.gradle/*" ".gradle/*" "*/.kotlin/*" ".kotlin/*" "*/.cxx/*" ".cxx/*" "*/build/*" "build/*" "*/DerivedData/*" "DerivedData/*" "*/xcuserdata/*" "xcuserdata/*" "*/Pods/*" "Pods/*" "*.pyc" "*.aar" >/dev/null
    )
    # Füge gemeinsame native Quelle hinzu
    (
        cd "$(dirname "$native_shared_source")" || exit 1
        zip -r "$android_source_zip" "$(basename "$native_shared_source")" -X -9 >/dev/null
        # Entferne unerwünschte Dateien aus dem gemeinsamen Archiv
        zip -d "$android_source_zip" "*/__pycache__/*" "__pycache__/*" "*/.gradle/*" ".gradle/*" "*/.kotlin/*" ".kotlin/*" "*/.cxx/*" ".cxx/*" "*/build/*" "build/*" "*/DerivedData/*" "DerivedData/*" "*/xcuserdata/*" "xcuserdata/*" "*/Pods/*" "Pods/*" "*.pyc" "*.aar" >/dev/null
    )

    # Behandle Android APK
    if [[ -n "$android_apk" ]]; then
        if [[ ! -f "$android_apk" ]] || [[ "${android_apk##*.}" != "apk" ]]; then
            echo "--android-apk must point to an existing APK" >&2
            exit 1
        fi
        if [[ "$(realpath "$android_apk")" != "$(realpath "$android_apk_out")" ]]; then
            cp "$android_apk" "$android_apk_out"
        fi
    fi

    # Erstelle Prüfsummen
    local artifacts=("$extension_zip" "$plugin_zip" "$service_zip" "$ios_source_zip" "$android_source_zip")
    if [[ -f "$android_apk_out" ]]; then
        artifacts+=("$android_apk_out")
    fi

    local checksums=()
    for artifact in "${artifacts[@]}"; do
        if [[ -f "$artifact" ]]; then
            local digest
            digest=$(sha256sum "$artifact" | cut -d' ' -f1)
            local filename
            filename=$(basename "$artifact")
            checksums+=("$digest  $filename")
        fi
    done

    printf '%s\n' "${checksums[@]}" > "$checksum_file"

    # Gib JSON-Ausgabe aus
    jq -n \
        --arg extension_dir "$extension_dir" \
        --arg extension_zip "$extension_zip" \
        --arg plugin_zip "$plugin_zip" \
        --arg service_zip "$service_zip" \
        --arg ios_source_zip "$ios_source_zip" \
        --arg android_source_zip "$android_source_zip" \
        --arg android_apk "$android_apk_out" \
        --arg checksum_file "$checksum_file" \
        --arg version "$version" \
        '{
            extension_dir: $extension_dir,
            extension_zip: $extension_zip,
            plugin_zip: $plugin_zip,
            service_zip: $service_zip,
            ios_source_zip: $ios_source_zip,
            android_source_zip: $android_source_zip,
            android_apk: (if ($android_apk | test("/dev/null")) then null else $android_apk end),
            checksum_file: $checksum_file,
            version: $version
        }'
}

# Skript ausführen
main "$@"
