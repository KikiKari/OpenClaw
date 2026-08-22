#!/usr/bin/env bash
# process-pond-textures.py — portiert nach shell
# Quelle: python, Onboarding@main:scripts/process-pond-textures.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Chroma-key pond textures to add a clean alpha channel.
#
# The leaf/blossom source webps ship on solid backgrounds (dark green or white)
# rather than transparency, so `alphaTest` clipping in three.js has nothing to
# key on. This produces RGBA PNGs with a soft alpha mask so the R3F planes clip
# to the real silhouette.

BASE="public/media/pond"
OUT="$BASE/processed"

mkdir -p "$OUT"

# Function to key out background and create alpha channel
key_out() {
    local path="$1"
    local out="$2"
    local mode="$3"
    local feather="${4:-2}"

    # Convert WebP to PNG for processing
    local temp_png
    temp_png=$(mktemp --suffix=.png)
    convert "$path" "$temp_png"

    # Create alpha mask based on mode
    local temp_alpha
    temp_alpha=$(mktemp --suffix=.png)
    
    if [[ "$mode" == "green" ]]; then
        # Dark-green background: low overall brightness AND green-dominant-but-dark
        # Create mask where dark green background becomes transparent
        convert "$temp_png" \
            -colorspace RGB \
            -channel R -separate +channel \
            \( "$temp_png" -channel G -separate +channel \) \
            \( "$temp_png" -channel B -separate +channel \) \
            -evaluate-sequence mean \
            -threshold 35% \
            -negate \
            "$temp_alpha"
    elif [[ "$mode" == "white" ]]; then
        # White background: near-white, low saturation
        # Create mask where white background becomes transparent
        convert "$temp_png" \
            -colorspace RGB \
            -channel R -separate +channel \
            \( "$temp_png" -channel G -separate +channel \) \
            \( "$temp_png" -channel B -separate +channel \) \
            -evaluate-sequence min \
            -threshold 218 \
            \( "$temp_png" -colorspace HSL -channel R -separate +channel -threshold 28% -negate \) \
            -compose multiply -composite \
            "$temp_alpha"
    else
        echo "Error: Unknown mode '$mode'" >&2
        rm -f "$temp_png" "$temp_alpha"
        return 1
    fi

    # Feather the mask edges
    convert "$temp_alpha" -blur 0x"$feather" "$temp_alpha"

    # Apply alpha mask to original image
    convert "$temp_png" "$temp_alpha" -alpha off -compose copy-opacity -composite \
        -trim +repage "$out"

    echo "$(basename "$path") -> $(basename "$out") ($(identify -format "%wx%h" "$out")) ($mode)"

    # Cleanup temp files
    rm -f "$temp_png" "$temp_alpha"
}

# Process lily pads
key_out "$BASE/blaetter/12130585.webp" "$OUT/leaf-a.png" "green"
key_out "$BASE/blaetter/48178242.webp" "$OUT/leaf-b.png" "white"

# Process blossoms with white backgrounds
key_out "$BASE/blueten/78370994.webp" "$OUT/blossom-a.png" "white" 3
key_out "$BASE/blueten/70017289.webp" "$OUT/blossom-b.png" "white" 3

echo "done"
