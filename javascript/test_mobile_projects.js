#!/usr/bin/env node
// test_mobile_projects.py — portiert nach javascript
// Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_projects.py
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';

const __filename = new URL(import.meta.url).pathname;
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..', '..');
const IOS = path.join(ROOT, 'mobile', 'ios');
const ANDROID = path.join(ROOT, 'mobile', 'android');
const SHARED = path.join(ROOT, 'plugin-source', 'mobile-shared', 'webview-bridge.js');

function requireCondition(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function globSync(pattern, options = {}) {
    const { cwd = '.', recursive = false } = options;
    const basePath = path.resolve(cwd);
    const results = [];

    function walk(dir) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            const relativePath = path.relative(basePath, fullPath);

            if (entry.isDirectory()) {
                if (recursive) {
                    walk(fullPath);
                }
            } else {
                if (pattern === '*.p8' && entry.name.endsWith('.p8')) {
                    results.push(fullPath);
                } else if (pattern === '*.aar' && entry.name.endsWith('.aar')) {
                    results.push(fullPath);
                }
            }
        }
    }

    walk(basePath);
    return results;
}

function rglob(pattern, baseDir) {
    const results = [];
    
    function walk(dir) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            
            if (entry.isDirectory()) {
                walk(fullPath);
            } else {
                if (pattern === '*.p8' && entry.name.endsWith('.p8')) {
                    results.push(fullPath);
                }
            }
        }
    }
    
    walk(baseDir);
    return results;
}

if (fs.existsSync(ANDROID)) {
    const manifest = fs.readFileSync(path.join(ANDROID, 'app', 'src', 'main', 'AndroidManifest.xml'), 'utf8');
    const gradle = fs.readFileSync(path.join(ANDROID, 'app', 'build.gradle.kts'), 'utf8');
    const android_webview = fs.readFileSync(path.join(ANDROID, 'app', 'src', 'main', 'java', 'app', 'tiktoklivecompanion', 'CompanionWebView.kt'), 'utf8');
    
    requireCondition(gradle.includes('minSdk = 21') && gradle.includes('versionName = "0.8.2"'), "Android version contract");
    requireCondition(manifest.includes('usesCleartextTraffic="false"'), "Android cleartext must be disabled");
    requireCondition(!android_webview.includes("addJavascriptInterface"), "insecure Android JavaScript interface");
    requireCondition(android_webview.includes("addWebMessageListener") && android_webview.includes("ALLOWED_ORIGIN"), "origin-restricted Android bridge");
    
    const aarFiles = globSync('*.aar', { cwd: path.join(ANDROID, 'app', 'libs') });
    requireCondition(aarFiles.length === 0, "ShazamKit AAR must not be committed");
    
    const sharedBytes = fs.readFileSync(SHARED);
    const androidBridgeBytes = fs.readFileSync(path.join(ANDROID, 'app', 'src', 'main', 'res', 'raw', 'webview_bridge.js'));
    requireCondition(Buffer.compare(sharedBytes, androidBridgeBytes) === 0, "Android bridge copy drift");
}

if (fs.existsSync(IOS)) {
    const ios_webview = fs.readFileSync(path.join(IOS, 'TikTokLiveCompanion', 'CompanionWebView.swift'), 'utf8');
    const pbx = fs.readFileSync(path.join(IOS, 'TikTokLiveCompanion.xcodeproj', 'project.pbxproj'), 'utf8');
    
    requireCondition(ios_webview.includes("forMainFrameOnly: false") && ios_webview.includes('securityOrigin.host == "www.tiktok.com"'), "origin-restricted iOS subframe bridge");
    requireCondition(pbx.includes("MARKETING_VERSION = 0.8.2") && pbx.includes("IPHONEOS_DEPLOYMENT_TARGET = 15.0"), "iOS version contract");
    
    const requiredNames = [
        "StreamNameNormalizer.swift in Sources", 
        "StreamNameNormalizerTests.swift in Sources", 
        "MobileUIStructureTests.swift in Sources"
    ];
    requireCondition(requiredNames.every(name => pbx.includes(name)), "iOS source and XCTest membership");
    
    const sharedBytes = fs.readFileSync(SHARED);
    const iosBridgeBytes = fs.readFileSync(path.join(IOS, 'Resources', 'webview-bridge.js'));
    requireCondition(Buffer.compare(sharedBytes, iosBridgeBytes) === 0, "iOS bridge copy drift");
    
    const infoPlist = fs.readFileSync(path.join(IOS, 'TikTokLiveCompanion', 'Info.plist'));
    const info = parsePlist(infoPlist);
    requireCondition(info.CFBundleShortVersionString === "0.8.2", "iOS plist version");
}

const p8Files = rglob('*.p8', ROOT);
requireCondition(p8Files.length === 0, "Apple private key must not be committed");

const schemaContent = fs.readFileSync(path.join(ROOT, 'plugin-source', 'mobile-shared', 'recognition-result.schema.json'), 'utf8');
const schema = JSON.parse(schemaContent);
requireCondition(
    Array.isArray(schema.properties.source.enum) && 
    schema.properties.source.enum.includes('microphone') && 
    schema.properties.source.enum.includes('webview') &&
    schema.properties.source.enum.length === 2, 
    "recognition source schema"
);

console.log("PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions");

// Simple plist parser for the specific use case
function parsePlist(data) {
    const text = data.toString();
    const result = {};
    
    // Extract CFBundleShortVersionString
    const versionMatch = text.match(/<key>CFBundleShortVersionString<\/key>\s*<string>(.*?)<\/string>/);
    if (versionMatch) {
        result.CFBundleShortVersionString = versionMatch[1];
    }
    
    return result;
}
