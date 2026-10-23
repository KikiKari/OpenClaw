#!/usr/bin/env node
// package_artifacts.py — portiert nach javascript
// Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/package_artifacts.py
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yargs = require('yargs');
const { exit } = require('process');

const { mkdirSync, writeFileSync, readFileSync, copyFileSync, copySync, removeSync, existsSync } = require('fs-extra');
const AdmZip = require('adm-zip');

const __filename = require('url').fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(__filename), '..');
const PROJECT_ROOT = path.resolve(ROOT, '..');
const EXCLUDED_PARTS = new Set(["__pycache__", ".gradle", ".kotlin", ".cxx", "build", "DerivedData", "xcuserdata", "Pods"]);

function addTree(archive, source, prefix = "") {
    const walkDir = (dir) => {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        let files = [];

        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                files = files.concat(walkDir(fullPath));
            } else {
                files.push(fullPath);
            }
        }

        return files;
    };

    const allFiles = walkDir(source);

    for (const filePath of allFiles) {
        const relativePath = path.relative(source, filePath);
        const parts = relativePath.split(path.sep);
        
        if (!fs.statSync(filePath).isFile() || 
            EXCLUDED_PARTS.has(parts[0]) || 
            path.extname(filePath) === '.pyc' || 
            path.extname(filePath) === '.aar') {
            continue;
        }

        const archivePath = path.posix.join(prefix, relativePath);
        const fileData = fs.readFileSync(filePath);
        
        archive.addFile(archivePath, fileData);
        
        // Set executable permissions for gradlew
        if (path.basename(filePath) === 'gradlew') {
            const entry = archive.getEntry(archivePath);
            if (entry) {
                entry.header.attr = 0o100755 << 16;
            }
        }
    }
}

const argv = yargs
    .usage('Usage: $0 [options]')
    .describe('output-dir', 'Output directory')
    .demandOption('output-dir')
    .describe('android-apk', 'Optional verified mockDebug or shazamDebug APK')
    .describe('android-source', 'Verified Android source root')
    .default('android-source', path.join(PROJECT_ROOT, 'mobile', 'android'))
    .describe('ios-source', 'Verified iOS source root')
    .default('ios-source', path.join(PROJECT_ROOT, 'mobile', 'ios'))
    .describe('native-shared-source', 'Shared native audio source root')
    .default('native-shared-source', path.join(PROJECT_ROOT, 'mobile', 'shared'))
    .argv;

const outputDir = path.resolve(argv.outputDir);
mkdirSync(outputDir, { recursive: true });

const manifest = JSON.parse(readFileSync(path.join(ROOT, 'browser-extension', 'manifest.json'), 'utf8'));
const version = manifest.version;
const extensionZip = path.join(outputDir, `tiktok-live-companion-extension-${version}.zip`);
const pluginZip = path.join(outputDir, `tiktok-live-companion-plugin-${version}.zip`);
const serviceZip = path.join(outputDir, `tiktok-live-companion-service-${version}.zip`);
const iosSourceZip = path.join(outputDir, `tiktok-live-companion-ios-${version}-source.zip`);
const androidSourceZip = path.join(outputDir, `tiktok-live-companion-android-${version}-source.zip`);
const androidApk = path.join(outputDir, `tiktok-live-companion-android-${version}.apk`);
const extensionDir = path.join(outputDir, `tiktok-live-companion-extension-${version}`);
const checksumFile = path.join(outputDir, `tiktok-live-companion-${version}-SHA256.txt`);

if (path.resolve(extensionDir, '..') !== outputDir) {
    throw new Error("Refusing to package outside the requested output directory");
}

if (existsSync(extensionDir)) {
    removeSync(extensionDir);
}

copySync(path.join(ROOT, 'browser-extension'), extensionDir);
copySync(path.join(ROOT, 'companion-service'), path.join(extensionDir, 'companion-service'));

writeFileSync(
    path.join(extensionDir, 'Sprachdienst-reparieren.cmd'),
    '@echo off\r\ncall "%~dp0companion-service\\Sprachdienst-reparieren.cmd"\r\n',
    'utf-8'
);

writeFileSync(
    path.join(extensionDir, 'package.json'),
    JSON.stringify({
        name: 'tiktok-live-companion-extension-package',
        private: true,
        version: version,
        scripts: {
            setup: 'npm --prefix companion-service run setup --',
            start: 'npm --prefix companion-service start',
            test: 'npm --prefix companion-service test'
        }
    }, null, 2) + '\n',
    'utf-8'
);

// Create extension zip
const extensionArchive = new AdmZip();
addTree(extensionArchive, extensionDir);
extensionArchive.writeZip(extensionZip);

// Create plugin zip
const pluginArchive = new AdmZip();
addTree(pluginArchive, ROOT, 'tiktok-live-companion');
pluginArchive.writeZip(pluginZip);

// Create service zip
const serviceArchive = new AdmZip();
addTree(serviceArchive, path.join(ROOT, 'companion-service'));
serviceArchive.writeZip(serviceZip);

const iosSource = path.resolve(argv.iosSource);
const androidSource = path.resolve(argv.androidSource);

if (!fs.existsSync(iosSource) || !fs.statSync(iosSource).isDirectory() ||
    !fs.existsSync(androidSource) || !fs.statSync(androidSource).isDirectory()) {
    throw new Error("--ios-source and --android-source must point to existing source directories");
}

const nativeShared = path.resolve(argv.nativeSharedSource);
if (!fs.existsSync(path.join(nativeShared, 'native', 'tlc_peak_limiter.h'))) {
    throw new Error("Shared native limiter source is required for both mobile source packages");
}

// Create iOS source zip
const iosSourceArchive = new AdmZip();
addTree(iosSourceArchive, iosSource, 'TikTokLiveCompanion-iOS');
addTree(iosSourceArchive, nativeShared, 'shared');
iosSourceArchive.writeZip(iosSourceZip);

// Create Android source zip
const androidSourceArchive = new AdmZip();
addTree(androidSourceArchive, androidSource, 'TikTokLiveCompanion-Android');
addTree(androidSourceArchive, nativeShared, 'shared');
androidSourceArchive.writeZip(androidSourceZip);

if (argv.androidApk) {
    const sourceApk = path.resolve(argv.androidApk);
    if (!fs.existsSync(sourceApk) || path.extname(sourceApk).toLowerCase() !== '.apk') {
        throw new Error("--android-apk must point to an existing APK");
    }
    if (path.resolve(sourceApk) !== path.resolve(androidApk)) {
        copyFileSync(sourceApk, androidApk);
    }
}

const artifacts = [extensionZip, pluginZip, serviceZip, iosSourceZip, androidSourceZip];
if (fs.existsSync(androidApk)) {
    artifacts.push(androidApk);
}

const checksums = [];
for (const artifact of artifacts) {
    const fileBuffer = fs.readFileSync(artifact);
    const hashSum = crypto.createHash('sha256');
    hashSum.update(fileBuffer);
    const hex = hashSum.digest('hex');
    checksums.push(`${hex}  ${path.basename(artifact)}`);
}

writeFileSync(checksumFile, checksums.join('\n') + '\n', 'utf-8');

console.log(JSON.stringify({
    extension_dir: path.resolve(extensionDir),
    extension_zip: path.resolve(extensionZip),
    plugin_zip: path.resolve(pluginZip),
    service_zip: path.resolve(serviceZip),
    ios_source_zip: path.resolve(iosSourceZip),
    android_source_zip: path.resolve(androidSourceZip),
    android_apk: fs.existsSync(androidApk) ? path.resolve(androidApk) : null,
    checksum_file: path.resolve(checksumFile),
    version: version
}, null, 2));
