#!/usr/bin/env node
// package_artifacts.py — portiert nach javascript
// Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yargs = require('yargs');
const AdmZip = require('adm-zip');

const __filename = process.argv[1];
const ROOT = path.resolve(path.dirname(__filename), '../..');
const PROJECT_ROOT = path.resolve(ROOT, '..');
const EXCLUDED_PARTS = new Set(["__pycache__", ".gradle", ".kotlin", "build", "DerivedData", "xcuserdata"]);

function addTree(archive, source, prefix = "") {
    const files = getAllFiles(source);
    files.sort();
    for (const filePath of files) {
        const relativePath = path.relative(source, filePath);
        const parts = relativePath.split(path.sep);
        if (EXCLUDED_PARTS.has(parts[0]) || path.extname(filePath) === '.pyc' || path.extname(filePath) === '.aar') {
            continue;
        }
        const archivePath = path.posix.join(prefix, relativePath);
        const fileContent = fs.readFileSync(filePath);
        archive.addFile(archivePath, fileContent);
    }
}

function getAllFiles(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.resolve(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = [...results, ...getAllFiles(file)];
        } else {
            results.push(file);
        }
    });
    return results;
}

const argv = yargs
    .usage('Usage: $0 [options]')
    .describe('output-dir', 'Output directory')
    .demandOption(['output-dir'])
    .option('android-apk', {
        describe: 'Optional verified mockDebug or shazamDebug APK',
        type: 'string'
    })
    .option('android-source', {
        describe: 'Verified Android source root',
        default: path.join(PROJECT_ROOT, 'mobile', 'android'),
        type: 'string'
    })
    .option('ios-source', {
        describe: 'Verified iOS source root',
        default: path.join(PROJECT_ROOT, 'mobile', 'ios'),
        type: 'string'
    })
    .argv;

const outputDir = path.resolve(argv.outputDir);
fs.mkdirSync(outputDir, { recursive: true });

const manifestPath = path.join(ROOT, 'browser-extension', 'manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
const version = manifest.version;

const extensionZip = path.join(outputDir, `tiktok-live-companion-extension-${version}.zip`);
const pluginZip = path.join(outputDir, `tiktok-live-companion-plugin-${version}.zip`);
const serviceZip = path.join(outputDir, `tiktok-live-companion-service-${version}.zip`);
const iosSourceZip = path.join(outputDir, `tiktok-live-companion-ios-${version}-source.zip`);
const androidSourceZip = path.join(outputDir, `tiktok-live-companion-android-${version}-source.zip`);
const androidApk = path.join(outputDir, `tiktok-live-companion-android-${version}.apk`);
const extensionDir = path.join(outputDir, `tiktok-live-companion-extension-${version}`);
const checksumFile = path.join(outputDir, `tiktok-live-companion-${version}-SHA256.txt`);

const resolvedExtensionDir = path.resolve(extensionDir);
if (path.dirname(resolvedExtensionDir) !== outputDir) {
    throw new Error("Refusing to package outside the requested output directory");
}
if (fs.existsSync(extensionDir)) {
    fs.rmSync(extensionDir, { recursive: true });
}
copyDirSync(path.join(ROOT, 'browser-extension'), extensionDir);
copyDirSync(path.join(ROOT, 'companion-service'), path.join(extensionDir, 'companion-service'));

const batchScriptContent = '@echo off\r\ncall "%~dp0companion-service\\Sprachdienst-reparieren.cmd"\r\n';
fs.writeFileSync(path.join(extensionDir, 'Sprachdienst-reparieren.cmd'), batchScriptContent, 'utf-8');

const packageJsonContent = {
    name: 'tiktok-live-companion-extension-package',
    private: true,
    version: version,
    scripts: {
        setup: 'npm --prefix companion-service run setup --',
        start: 'npm --prefix companion-service start',
        test: 'npm --prefix companion-service test'
    }
};
fs.writeFileSync(path.join(extensionDir, 'package.json'), JSON.stringify(packageJsonContent, null, 2) + '\n', 'utf-8');

let archive = new AdmZip();
addTree(archive, extensionDir);
archive.writeZip(extensionZip);

archive = new AdmZip();
addTree(archive, ROOT, 'tiktok-live-companion');
archive.writeZip(pluginZip);

archive = new AdmZip();
addTree(archive, path.join(ROOT, 'companion-service'));
archive.writeZip(serviceZip);

const iosSource = path.resolve(argv.iosSource);
const androidSource = path.resolve(argv.androidSource);
if (!fs.existsSync(iosSource) || !fs.statSync(iosSource).isDirectory() ||
    !fs.existsSync(androidSource) || !fs.statSync(androidSource).isDirectory()) {
    throw new Error("--ios-source and --android-source must point to existing source directories");
}

archive = new AdmZip();
addTree(archive, iosSource, 'TikTokLiveCompanion-iOS');
archive.writeZip(iosSourceZip);

archive = new AdmZip();
addTree(archive, androidSource, 'TikTokLiveCompanion-Android');
archive.writeZip(androidSourceZip);

if (argv.androidApk) {
    const sourceApk = path.resolve(argv.androidApk);
    if (!fs.existsSync(sourceApk) || path.extname(sourceApk).toLowerCase() !== '.apk') {
        throw new Error("--android-apk must point to an existing APK");
    }
    if (path.resolve(sourceApk) !== path.resolve(androidApk)) {
        fs.copyFileSync(sourceApk, androidApk);
    }
}

let artifacts = [extensionZip, pluginZip, serviceZip, iosSourceZip, androidSourceZip];
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
fs.writeFileSync(checksumFile, checksums.join('\n') + '\n', 'utf-8');

console.log(JSON.stringify({
    extension_dir: extensionDir,
    extension_zip: extensionZip,
    plugin_zip: pluginZip,
    service_zip: serviceZip,
    ios_source_zip: iosSourceZip,
    android_source_zip: androidSourceZip,
    android_apk: fs.existsSync(androidApk) ? androidApk : null,
    checksum_file: checksumFile,
    version: version
}, null, 2));

function copyDirSync(src, dest) {
    const entries = fs.readdirSync(src, { withFileTypes: true });
    fs.mkdirSync(dest, { recursive: true });
    for (let entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            copyDirSync(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}
