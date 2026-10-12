#!/usr/bin/env node
// package_artifacts.py — portiert nach javascript
// Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/package_artifacts.py
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/package_artifacts.py
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/package_artifacts.py
// auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/package_artifacts.py
// Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yargs = require('yargs');
const { hideBin } = require('yargs/helpers');
const archiver = require('archiver');

const __filename = new URL(import.meta.url).pathname;
const ROOT = path.resolve(path.dirname(__filename), '../..');
const PROJECT_ROOT = path.resolve(ROOT, '..');
const EXCLUDED_PARTS = new Set(["__pycache__", ".gradle", ".kotlin", ".cxx", "build", "DerivedData", "xcuserdata", "Pods"]);

function addTree(archive, source, prefix = "") {
    const files = getAllFiles(source);
    files.sort();
    
    for (const filePath of files) {
        const relativePath = path.relative(source, filePath);
        const parts = relativePath.split(path.sep);
        
        if (EXCLUDED_PARTS.has(path.basename(filePath)) || 
            parts.some(part => EXCLUDED_PARTS.has(part)) ||
            path.extname(filePath) === '.pyc' ||
            path.extname(filePath) === '.aar') {
            continue;
        }
        
        const archivePath = path.posix.join(prefix, relativePath.replace(/\\/g, '/'));
        const stat = fs.statSync(filePath);
        
        archive.file(filePath, {
            name: archivePath,
            mode: path.basename(filePath) === 'gradlew' ? 0o100755 : 0o100644,
            date: new Date('1980-01-01')
        });
    }
}

function getAllFiles(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    
    list.forEach(file => {
        file = path.resolve(dir, file);
        const stat = fs.statSync(file);
        
        if (stat && stat.isDirectory()) {
            results = results.concat(getAllFiles(file));
        } else {
            results.push(file);
        }
    });
    
    return results;
}

function readJsonFileSync(filePath) {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJsonFileSync(filePath, data) {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

async function createZip(zipPath, callback) {
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(zipPath);
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });
        
        output.on('close', () => resolve());
        archive.on('error', err => reject(err));
        
        archive.pipe(output);
        callback(archive);
        archive.finalize();
    });
}

const argv = yargs(hideBin(process.argv))
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
fs.mkdirSync(outputDir, { recursive: true });

const manifest = readJsonFileSync(path.join(ROOT, 'browser-extension', 'manifest.json'));
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

function copyDirSync(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    const entries = fs.readdirSync(src, { withFileTypes: true });
    
    for (const entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        
        if (entry.isDirectory()) {
            copyDirSync(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

copyDirSync(path.join(ROOT, 'browser-extension'), extensionDir);
copyDirSync(path.join(ROOT, 'companion-service'), path.join(extensionDir, 'companion-service'));

fs.writeFileSync(
    path.join(extensionDir, 'Sprachdienst-reparieren.cmd'),
    '@echo off\r\ncall "%~dp0companion-service\\Sprachdienst-reparieren.cmd"\r\n',
    'utf8'
);

writeJsonFileSync(path.join(extensionDir, 'package.json'), {
    name: 'tiktok-live-companion-extension-package',
    private: true,
    version: version,
    scripts: {
        setup: 'npm --prefix companion-service run setup --',
        start: 'npm --prefix companion-service start',
        test: 'npm --prefix companion-service test'
    }
});

(async () => {
    await createZip(extensionZip, (archive) => {
        addTree(archive, extensionDir);
    });
    
    await createZip(pluginZip, (archive) => {
        addTree(archive, ROOT, 'tiktok-live-companion');
    });
    
    await createZip(serviceZip, (archive) => {
        addTree(archive, path.join(ROOT, 'companion-service'));
    });
    
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
    
    await createZip(iosSourceZip, (archive) => {
        addTree(archive, iosSource, 'TikTokLiveCompanion-iOS');
        addTree(archive, nativeShared, 'shared');
    });
    
    await createZip(androidSourceZip, (archive) => {
        addTree(archive, androidSource, 'TikTokLiveCompanion-Android');
        addTree(archive, nativeShared, 'shared');
    });
    
    if (argv.androidApk) {
        const sourceApk = path.resolve(argv.androidApk);
        if (!fs.existsSync(sourceApk) || path.extname(sourceApk).toLowerCase() !== '.apk') {
            throw new Error("--android-apk must point to an existing APK");
        }
        
        if (path.resolve(sourceApk) !== path.resolve(androidApk)) {
            fs.copyFileSync(sourceApk, androidApk);
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
    
    fs.writeFileSync(checksumFile, checksums.join('\n') + '\n', 'utf8');
    
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
})();
