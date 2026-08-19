#!/bin/bash
# package_artifacts.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Globale Variablen
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(realpath "$SCRIPT_DIR/../..")"
readonly PROJECT_ROOT="$(realpath "$ROOT/..")"
readonly EXCLUDED_PARTS=("__pycache__" ".gradle" ".kotlin" "build" "DerivedData" "xcuserdata")

# Hilfsfunktionen
contains_element() {
    local element="$1"
    shift
    local array=("$@")
    for item in "${array[@]}"; do
        [[ "$item" == "$element" ]] && return 0
    done
    return 1
}

add_tree() {
    local archive="$1"
    local source="$2"
    local prefix="${3:-}"

    # Finde alle Dateien rekursiv im Quellverzeichnis
    find "$source" -type f | sort | while read -r file; do
        # Prüfe ob Datei in excluded parts liegt
        local skip=false
        for part in "${EXCLUDED_PARTS[@]}"; do
            if [[ "$file" == *"$part"* ]]; then
                skip=true
                break
            fi
        done

        # Überspringe .pyc und .aar Dateien
        if [[ "$file" == *.pyc ]] || [[ "$file" == *.aar ]]; then
            skip=true
        fi

        if [[ "$skip" == true ]]; then
            continue
        fi

        # Berechne relativen Pfad
        local relative_path="${file#$source/}"
        local archive_path="$prefix/$relative_path"

        # Entferne führende Schrägstriche
        archive_path="${archive_path#/}"

        # Füge Datei zum Zip-Archiv hinzu
        zip -j "$archive" "$file" 2>/dev/null || true
    done
}

# Argumente parsen
OUTPUT_DIR=""
ANDROID_APK=""
ANDROID_SOURCE="$PROJECT_ROOT/mobile/android"
IOS_SOURCE="$PROJECT_ROOT/mobile/ios"

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --android-apk)
            ANDROID_APK="$2"
            shift 2
            ;;
        --android-source)
            ANDROID_SOURCE="$2"
            shift 2
            ;;
        --ios-source)
            IOS_SOURCE="$2"
            shift 2
            ;;
        *)
            echo "Unbekanntes Argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "--output-dir ist erforderlich" >&2
    exit 1
fi

# Verzeichnisse erstellen
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(realpath "$OUTPUT_DIR")"

# Version aus manifest.json lesen
VERSION=$(jq -r '.version' "$ROOT/browser-extension/manifest.json")

# Dateinamen definieren
EXTENSION_ZIP="$OUTPUT_DIR/tiktok-live-companion-extension-$VERSION.zip"
PLUGIN_ZIP="$OUTPUT_DIR/tiktok-live-companion-plugin-$VERSION.zip"
SERVICE_ZIP="$OUTPUT_DIR/tiktok-live-companion-service-$VERSION.zip"
IOS_SOURCE_ZIP="$OUTPUT_DIR/tiktok-live-companion-ios-$VERSION-source.zip"
ANDROID_SOURCE_ZIP="$OUTPUT_DIR/tiktok-live-companion-android-$VERSION-source.zip"
ANDROID_APK_FILE="$OUTPUT_DIR/tiktok-live-companion-android-$VERSION.apk"
EXTENSION_DIR="$OUTPUT_DIR/tiktok-live-companion-extension-$VERSION"
CHECKSUM_FILE="$OUTPUT_DIR/tiktok-live-companion-$VERSION-SHA256.txt"

# Extension Verzeichnis vorbereiten
if [[ -d "$EXTENSION_DIR" ]]; then
    rm -rf "$EXTENSION_DIR"
fi

cp -r "$ROOT/browser-extension" "$EXTENSION_DIR"
cp -r "$ROOT/companion-service" "$EXTENSION_DIR/companion-service"

cat > "$EXTENSION_DIR/Sprachdienst-reparieren.cmd" << 'EOF'
@echo off
call "%~dp0companion-service\Sprachdienst-reparieren.cmd"
EOF

# package.json erstellen
cat > "$EXTENSION_DIR/package.json" << EOF
{
  "name": "tiktok-live-companion-extension-package",
  "private": true,
  "version": "$VERSION",
  "scripts": {
    "setup": "npm --prefix companion-service run setup --",
    "start": "npm --prefix companion-service start",
    "test": "npm --prefix companion-service test"
  }
}
EOF

# Zip-Dateien erstellen
zip -r "$EXTENSION_ZIP" "$EXTENSION_DIR" >/dev/null
zip -r "$PLUGIN_ZIP" "$ROOT" >/dev/null
zip -r "$SERVICE_ZIP" "$ROOT/companion-service" >/dev/null

# iOS und Android Quellcode packen
if [[ ! -d "$IOS_SOURCE" ]] || [[ ! -d "$ANDROID_SOURCE" ]]; then
    echo "--ios-source und --android-source müssen auf existierende Verzeichnisse zeigen" >&2
    exit 1
fi

zip -r "$IOS_SOURCE_ZIP" "$IOS_SOURCE" >/dev/null
zip -r "$ANDROID_SOURCE_ZIP" "$ANDROID_SOURCE" >/dev/null

# Android APK kopieren falls angegeben
if [[ -n "$ANDROID_APK" ]]; then
    if [[ ! -f "$ANDROID_APK" ]] || [[ "${ANDROID_APK##*.}" != "apk" ]]; then
        echo "--android-apk muss auf eine existierende APK-Datei zeigen" >&2
        exit 1
    fi
    
    if [[ "$(realpath "$ANDROID_APK")" != "$(realpath "$ANDROID_APK_FILE")" ]]; then
        cp "$ANDROID_APK" "$ANDROID_APK_FILE"
    fi
fi

# Checksummen berechnen
ARTIFACTS=(
    "$EXTENSION_ZIP"
    "$PLUGIN_ZIP"
    "$SERVICE_ZIP"
    "$IOS_SOURCE_ZIP"
    "$ANDROID_SOURCE_ZIP"
)

if [[ -f "$ANDROID_APK_FILE" ]]; then
    ARTIFACTS+=("$ANDROID_APK_FILE")
fi

{
    for artifact in "${ARTIFACTS[@]}"; do
        sha256sum "$artifact" | cut -d' ' -f1 | xargs -I {} echo "{}  $(basename "$artifact")"
    done
} > "$CHECKSUM_FILE"

# JSON Ausgabe erstellen
ANDROID_APK_PATH=""
if [[ -f "$ANDROID_APK_FILE" ]]; then
    ANDROID_APK_PATH="$(realpath "$ANDROID_APK_FILE")"
fi

cat << EOF
{
  "extension_dir": "$(realpath "$EXTENSION_DIR")",
  "extension_zip": "$(realpath "$EXTENSION_ZIP")",
  "plugin_zip": "$(realpath "$PLUGIN_ZIP")",
  "service_zip": "$(realpath "$SERVICE_ZIP")",
  "ios_source_zip": "$(realpath "$IOS_SOURCE_ZIP")",
  "android_source_zip": "$(realpath "$ANDROID_SOURCE_ZIP")",
  "android_apk": $([ -n "$ANDROID_APK_PATH" ] && echo "\"$ANDROID_APK_PATH\"" || echo "null"),
  "checksum_file": "$(realpath "$CHECKSUM_FILE")",
  "version": "$VERSION"
}
EOF
