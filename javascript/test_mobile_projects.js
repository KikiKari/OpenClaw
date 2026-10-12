#!/usr/bin/env node
// test_mobile_projects.py — portiert nach javascript
// Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
// auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_mobile_projects.py
// Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
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

function readFileSync(filePath) {
    return fs.readFileSync(filePath, 'utf-8');
}

function readFileBuffer(filePath) {
    return fs.readFileSync(filePath);
}

function existsSync(dirPath) {
    return fs.existsSync(dirPath);
}

function globSync(pattern, options = {}) {
    const { cwd = '.', recursive = true } = options;
    const results = [];
    
    function walk(currentDir) {
        const entries = fs.readdirSync(currentDir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(currentDir, entry.name);
            const relativePath = path.relative(cwd, fullPath);
            
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
    
    walk(cwd);
    return results;
}

function plistParse(content) {
    // Simple parser for Info.plist - in real usage you might want to use a proper plist parser
    // This is a basic implementation that extracts CFBundleShortVersionString
    const match = content.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/);
    return {
        CFBundleShortVersionString: match ? match[1] : undefined
    };
}

if (existsSync(ANDROID)) {
    const manifest = readFileSync(path.join(ANDROID, 'app', 'src', 'main', 'AndroidManifest.xml'));
    const gradle = readFileSync(path.join(ANDROID, 'app', 'build.gradle.kts'));
    const androidWebview = readFileSync(path.join(ANDROID, 'app', 'src', 'main', 'java', 'app', 'tiktoklivecompanion', 'CompanionWebView.kt'));
    
    requireCondition(gradle.includes('minSdk = 21') && gradle.includes('versionName = "0.8.2"'), "Android version contract");
    requireCondition(manifest.includes('usesCleartextTraffic="false"'), "Android cleartext must be disabled");
    requireCondition(!androidWebview.includes("addJavascriptInterface"), "insecure Android JavaScript interface");
    requireCondition(androidWebview.includes("addWebMessageListener") && androidWebview.includes("ALLOWED_ORIGIN"), "origin-restricted Android bridge");
    
    const aarFiles = globSync('*.aar', { cwd: path.join(ANDROID, 'app', 'libs') });
    requireCondition(aarFiles.length === 0, "ShazamKit AAR must not be committed");
    
    const sharedBytes = readFileBuffer(SHARED);
    const androidBridgeBytes = readFileBuffer(path.join(ANDROID, 'app', 'src', 'main', 'res', 'raw', 'webview_bridge.js'));
    requireCondition(sharedBytes.equals(androidBridgeBytes), "Android bridge copy drift");
}

if (existsSync(IOS)) {
    const iosWebview = readFileSync(path.join(IOS, 'TikTokLiveCompanion', 'CompanionWebView.swift'));
    const pbx = readFileSync(path.join(IOS, 'TikTokLiveCompanion.xcodeproj', 'project.pbxproj'));
    
    requireCondition(
        iosWebview.includes("forMainFrameOnly: false") && 
        iosWebview.includes('securityOrigin.host == "www.tiktok.com"'), 
        "origin-restricted iOS subframe bridge"
    );
    
    requireCondition(
        pbx.includes("MARKETING_VERSION = 0.8.2") && 
        pbx.includes("IPHONEOS_DEPLOYMENT_TARGET = 15.0"), 
        "iOS version contract"
    );
    
    const requiredNames = [
        "StreamNameNormalizer.swift in Sources", 
        "StreamNameNormalizerTests.swift in Sources", 
        "MobileUIStructureTests.swift in Sources"
    ];
    
    requireCondition(
        requiredNames.every(name => pbx.includes(name)), 
        "iOS source and XCTest membership"
    );
    
    const sharedBytes = readFileBuffer(SHARED);
    const iosBridgeBytes = readFileBuffer(path.join(IOS, 'Resources', 'webview-bridge.js'));
    requireCondition(sharedBytes.equals(iosBridgeBytes), "iOS bridge copy drift");
    
    const infoContent = readFileSync(path.join(IOS, 'TikTokLiveCompanion', 'Info.plist'));
    const info = plistParse(infoContent);
    requireCondition(info.CFBundleShortVersionString === "0.8.2", "iOS plist version");
}

const p8Files = globSync('*.p8', { cwd: ROOT, recursive: true });
requireCondition(p8Files.length === 0, "Apple private key must not be committed");

const schemaContent = readFileSync(path.join(ROOT, 'plugin-source', 'mobile-shared', 'recognition-result.schema.json'));
const schema = JSON.parse(schemaContent);
requireCondition(
    JSON.stringify(schema.properties.source.enum) === JSON.stringify(["microphone", "webview"]), 
    "recognition source schema"
);

console.log("PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions");
