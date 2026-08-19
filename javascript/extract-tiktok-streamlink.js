#!/usr/bin/env node
// extract-tiktok-streamlink.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

// Bounded fallback used by the enhanced extractor. Output is normalized again
// by tiktok-get-stream.js; standalone success must remain URL-only unless
// --json is requested. Exit 75 means preflight overload.
'use strict';

const { execSync, spawn } = require('child_process');
const os = require('os');

const USERNAME = process.argv[2]?.replace(/^@/, '') || '';
const QUALITY = process.argv[3] || 'best';
const JSON_FLAG = process.argv[4] || '';
const TIMESTAMP = new Date().toISOString().replace(/\.\d+Z$/, 'Z');

function emitJson(success, method, username, url, quality, author, title, error, timestamp, status) {
    const payload = {};
    if (success !== undefined && success !== null && success !== "") payload.success = String(success).toLowerCase() === "true";
    if (method !== undefined && method !== null && method !== "") payload.method = method;
    if (username !== undefined && username !== null && username !== "") payload.username = username;
    if (url !== undefined && url !== null && url !== "") payload.url = url;
    if (quality !== undefined && quality !== null && quality !== "") payload.quality = quality;
    if (author !== undefined && author !== null && author !== "") payload.author = author;
    if (title !== undefined && title !== null && title !== "") payload.title = title;
    if (error !== undefined && error !== null && error !== "") payload.error = error;
    if (timestamp !== undefined && timestamp !== null && timestamp !== "") payload.timestamp = timestamp;
    if (status !== undefined && status !== null && status !== "") payload.status = status;
    console.error(JSON.stringify(payload, null, 0));
}

if (!USERNAME.match(/^[A-Za-z0-9._]{1,24}$/)) {
    console.error("Invalid TikTok username");
    process.exit(64);
}
if (!QUALITY.match(/^(best|worst|original|1080p60|720p60|720p|540p|360p|auto)$/)) {
    console.error("Invalid stream quality");
    process.exit(64);
}

let loadPerCpu;
try {
    const cpus = os.cpus().length || 1;
    const loadAvg = os.loadavg()[0];
    loadPerCpu = loadAvg / Math.max(1, cpus);
} catch (err) {
    loadPerCpu = 0;
}
const maxLoad = parseFloat(process.env.TIKTOK_MAX_LOAD_PER_CPU || "1.5");
if (loadPerCpu > maxLoad) {
    emitJson(false, "streamlink", USERNAME, "", QUALITY, "", "", "host overloaded", TIMESTAMP, "overloaded");
    process.exit(75);
}

try {
    execSync('which streamlink', { stdio: 'ignore' });
} catch (err) {
    emitJson(false, "streamlink", USERNAME, "", QUALITY, "", "", "streamlink not installed", TIMESTAMP, "dependency_missing");
    process.exit(2);
}

const liveUrl = `https://www.tiktok.com/@${USERNAME}/live`;
let selector;
switch (QUALITY) {
    case "original": selector = "origin,uhd_60,hd_60,hd,sd,ld,best,worst"; break;
    case "auto": selector = "best,origin,uhd_60,hd_60,hd,sd,ld,worst"; break;
    case "1080p60": selector = "uhd_60,hd_60,hd,sd,ld,worst"; break;
    case "720p60": selector = "hd_60,hd,sd,ld,worst"; break;
    case "720p": selector = "hd,sd,ld,worst"; break;
    case "540p": selector = "sd,ld,worst"; break;
    case "360p": selector = "ld,worst"; break;
    default: selector = QUALITY;
}

function runStreamlink(args) {
    return new Promise((resolve) => {
        const child = spawn('streamlink', args, { stdio: ['ignore', 'pipe', 'ignore'] });
        let stdout = '';
        child.stdout.on('data', (data) => { stdout += data.toString(); });
        child.on('close', (code) => {
            resolve({ code, output: stdout.trim() });
        });
    });
}

async function main() {
    try {
        const result = await runStreamlink(['--json', liveUrl, selector]);
        if (result.code !== 0 || !result.output) {
            const urlResult = await runStreamlink(['--stream-url', liveUrl, selector]);
            if (urlResult.code !== 0 || !urlResult.output) {
                emitJson(false, "streamlink", USERNAME, "", QUALITY, "", "", "streamlink failed or no stream found", TIMESTAMP, "offline");
                process.exit(1);
            }
            if (JSON_FLAG === "--json") {
                emitJson(true, "streamlink", USERNAME, urlResult.output, QUALITY, "", "", "", TIMESTAMP, "live");
            } else {
                console.log(urlResult.output);
            }
            process.exit(0);
        }

        let parsed;
        try {
            const data = JSON.parse(result.output);
            let url = data.url || "";
            const streams = data.streams || {};
            if (!url && typeof streams === 'object') {
                const keys = ["best", "worst", ...Object.keys(streams)];
                for (const key of keys) {
                    const value = streams[key];
                    if (typeof value === 'object' && value?.url) {
                        url = value.url;
                        break;
                    }
                }
            }
            const metadata = data.metadata || {};
            parsed = { url, author: metadata.author || "", title: metadata.title || "" };
        } catch (parseErr) {
            emitJson(false, "streamlink", USERNAME, "", QUALITY, "", "", "invalid streamlink JSON", TIMESTAMP, "technical_error");
            process.exit(2);
        }

        const { url, author, title } = parsed;
        if (!url) {
            emitJson(false, "streamlink", USERNAME, "", QUALITY, author, title, "could not extract stream URL", TIMESTAMP, "offline");
            process.exit(1);
        }
        if (JSON_FLAG === "--json") {
            emitJson(true, "streamlink", USERNAME, url, QUALITY, author, title, "", TIMESTAMP, "live");
        } else {
            console.log(url);
        }
    } catch (err) {
        emitJson(false, "streamlink", USERNAME, "", QUALITY, "", "", "unexpected error", TIMESTAMP, "technical_error");
        process.exit(2);
    }
}

main();
