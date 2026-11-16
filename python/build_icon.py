#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "c355e6c72cdeb455f866db9f9986948fe370b125c8840f82b52d624e13c4acf5", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "python"}
# build_icon.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
from pathlib import Path

# Render the macOS .icon bundle to a padded .icns like Trimmy's pipeline.
# Defaults target the OpenClaw assets so you can just run the script from repo root.

def main():
    root_dir = Path(__file__).parent.parent.resolve()
    
    icon_file = sys.argv[1] if len(sys.argv) > 1 else root_dir / "apps/macos/Icon.icon"
    basename = sys.argv[2] if len(sys.argv) > 2 else "OpenClaw"
    out_root = Path(sys.argv[3]) if len(sys.argv) > 3 else root_dir / "apps/macos/build/icon"
    xcode_app = os.environ.get("XCODE_APP", "/Applications/Xcode.app")
    # Where the final .icns should live; override DEST_ICNS to change.
    dest_icns = os.environ.get("DEST_ICNS", root_dir / "apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns")
    if isinstance(dest_icns, str):
        dest_icns = Path(dest_icns)

    ictool = Path(xcode_app) / "Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
    if not ictool.is_file():
        ictool = Path(xcode_app) / "Contents/Applications/Icon Composer.app/Contents/Executables/icontool"
    if not ictool.is_file():
        print("ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere.", file=sys.stderr)
        sys.exit(1)

    iconset_dir = out_root / f"{basename}.iconset"
    tmp_dir = out_root / "tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    iconset_dir.mkdir(parents=True, exist_ok=True)

    master_art = tmp_dir / "icon_art_824.png"
    master_1024 = tmp_dir / "icon_1024.png"

    # Render inner art (no margin) with macOS Default appearance
    subprocess.run([
        str(ictool), str(icon_file),
        "--export-preview", "macOS", "Default", "824", "824", "1", "-45", str(master_art)
    ], check=True)

    # Pad to 1024x1024 with transparent border
    subprocess.run([
        "sips", "--padToHeightWidth", "1024", "1024", str(master_art), "--out", str(master_1024)
    ], check=True, stdout=subprocess.DEVNULL)

    # Generate required sizes
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for sz in sizes:
        out = iconset_dir / f"icon_{sz}x{sz}.png"
        subprocess.run(["sips", "-z", str(sz), str(sz), str(master_1024), "--out", str(out)], 
                      check=True, stdout=subprocess.DEVNULL)
        if sz != 1024:
            dbl = sz * 2
            out2 = iconset_dir / f"icon_{sz}x{sz}@2x.png"
            subprocess.run(["sips", "-z", str(dbl), str(dbl), str(master_1024), "--out", str(out2)], 
                          check=True, stdout=subprocess.DEVNULL)

    # 512x512@2x already covered by 1024; ensure it exists
    import shutil
    shutil.copy2(master_1024, iconset_dir / "icon_512x512@2x.png")

    subprocess.run(["iconutil", "-c", "icns", str(iconset_dir), "-o", str(out_root / f"{basename}.icns")], 
                  check=True)

    dest_icns.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(out_root / f"{basename}.icns", dest_icns)

    print(f"Icon.icns generated at {dest_icns}")

if __name__ == "__main__":
    main()
