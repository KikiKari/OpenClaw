#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "0b4f7c5d0ea44de135fa0a3a967a968b736af64cb8697bad39d38f0e94d33b23", "source_sha256": "cff712785adbfe2fa94661b7b8457fbc21ec0b21bc3bc77e5cfa7018f473e486", "target_language": "javascript"}
// build_icon.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build_icon.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import { execSync } from 'child_process';
import { mkdirSync, cpSync, dirname } from 'fs';
import { resolve } from 'path';

// Render the macOS .icon bundle to a padded .icns like Trimmy's pipeline.
// Defaults target the OpenClaw assets so you can just run the script from repo root.

const ROOT_DIR = resolve(import.meta.url.replace('file://', ''), '../../..');

const ICON_FILE = process.argv[2] || `${ROOT_DIR}/apps/macos/Icon.icon`;
const BASENAME = process.argv[3] || 'OpenClaw';
const OUT_ROOT = process.argv[4] || `${ROOT_DIR}/apps/macos/build/icon`;
const XCODE_APP = process.env.XCODE_APP || '/Applications/Xcode.app';
// Where the final .icns should live; override DEST_ICNS to change.
const DEST_ICNS = process.env.DEST_ICNS || `${ROOT_DIR}/apps/macos/Sources/OpenClaw/Resources/OpenClaw.icns`;

let ICTOOL = `${XCODE_APP}/Contents/Applications/Icon Composer.app/Contents/Executables/ictool`;
try {
  execSync(`test -x "${ICTOOL}"`);
} catch {
  ICTOOL = `${XCODE_APP}/Contents/Applications/Icon Composer.app/Contents/Executables/icontool`;
  try {
    execSync(`test -x "${ICTOOL}"`);
  } catch {
    console.error("ictool/icontool not found. Set XCODE_APP if Xcode is elsewhere.");
    process.exit(1);
  }
}

const ICONSET_DIR = `${OUT_ROOT}/${BASENAME}.iconset`;
const TMP_DIR = `${OUT_ROOT}/tmp`;
mkdirSync(ICONSET_DIR, { recursive: true });
mkdirSync(TMP_DIR, { recursive: true });

const MASTER_ART = `${TMP_DIR}/icon_art_824.png`;
const MASTER_1024 = `${TMP_DIR}/icon_1024.png`;

// Render inner art (no margin) with macOS Default appearance
execSync(`"${ICTOOL}" "${ICON_FILE}" --export-preview macOS Default 824 824 1 -45 "${MASTER_ART}"`);

// Pad to 1024x1024 with transparent border
execSync(`sips --padToHeightWidth 1024 1024 "${MASTER_ART}" --out "${MASTER_1024}" >/dev/null`);

// Generate required sizes
const sizes = [16, 32, 64, 128, 256, 512, 1024];
for (const sz of sizes) {
  const out = `${ICONSET_DIR}/icon_${sz}x${sz}.png`;
  execSync(`sips -z ${sz} ${sz} "${MASTER_1024}" --out "${out}" >/dev/null`);
  if (sz !== 1024) {
    const dbl = sz * 2;
    const out2 = `${ICONSET_DIR}/icon_${sz}x${sz}@2x.png`;
    execSync(`sips -z ${dbl} ${dbl} "${MASTER_1024}" --out "${out2}" >/dev/null`);
  }
}

// 512x512@2x already covered by 1024; ensure it exists
cpSync(MASTER_1024, `${ICONSET_DIR}/icon_512x512@2x.png`);

execSync(`iconutil -c icns "${ICONSET_DIR}" -o "${OUT_ROOT}/${BASENAME}.icns"`);

mkdirSync(dirname(DEST_ICNS), { recursive: true });
cpSync(`${OUT_ROOT}/${BASENAME}.icns`, DEST_ICNS);

console.log(`Icon.icns generated at ${DEST_ICNS}`);
