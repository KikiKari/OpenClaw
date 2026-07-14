'use strict';

/**
 * Shared TikTok LIVE safety contract: handle normalization, per-CPU load
 * preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
 * validation, and normalized extractor statuses.
 */

const os = require('os');

const DEFAULT_MAX_LOAD_PER_CPU = 1.5;
const USERNAME_PATTERN = /^[A-Za-z0-9._]{1,24}$/;
const FAILURE_STATUSES = new Set([
    'offline',
    'restricted',
    'overloaded',
    'dependency_missing',
    'technical_error'
]);

function normalizeUsername(raw) {
    const username = String(raw || '').trim().replace(/^@+/, '');
    if (!USERNAME_PATTERN.test(username)) {
        throw new Error('Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores');
    }
    return username;
}

function loadState(env = process.env) {
    const cpuCount = Math.max(1, os.cpus().length);
    const observed = env.TIKTOK_TEST_LOAD_PER_CPU === undefined
        ? os.loadavg()[0] / cpuCount
        : Number(env.TIKTOK_TEST_LOAD_PER_CPU);
    const maximum = env.TIKTOK_MAX_LOAD_PER_CPU === undefined
        ? DEFAULT_MAX_LOAD_PER_CPU
        : Number(env.TIKTOK_MAX_LOAD_PER_CPU);
    if (!Number.isFinite(observed) || !Number.isFinite(maximum) || maximum <= 0) {
        throw new Error('Invalid TikTok load configuration');
    }
    return { overloaded: observed > maximum, loadPerCpu: observed, maximum };
}

function enforceLoadLimit(method) {
    const state = loadState();
    if (!state.overloaded) return state;
    process.stderr.write(`${JSON.stringify({
        status: 'overloaded',
        method,
        loadPerCpu: Number(state.loadPerCpu.toFixed(3)),
        maximum: state.maximum,
        message: 'Host is overloaded; retry on another node or later'
    })}\n`);
    process.exit(75);
}

function liveHrefSelectors(username) {
    const href = `/@${username}/live`;
    return [`a[href="${href}"]`, `a[href^="${href}?"]`];
}

function isAllowedStreamUrl(value) {
    try {
        const url = new URL(value);
        const hostname = url.hostname.toLowerCase();
        return url.protocol === 'https:' &&
            url.pathname.toLowerCase().includes('.flv') &&
            /(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$/.test(hostname);
    } catch (error) {
        return false;
    }
}

function isSuccessfulStreamResponse(status, value) {
    return Number.isInteger(status) &&
        status >= 200 &&
        status < 300 &&
        isAllowedStreamUrl(value);
}

// Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`.
const QUALITY_URL_PATTERN = /_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)/;

function qualityKeyFromUrl(value) {
    try {
        const match = new URL(value).pathname.toLowerCase().match(QUALITY_URL_PATTERN);
        return match ? match[1] : null;
    } catch (error) {
        return null;
    }
}

function normalizeExtractorResult(value, method, username) {
    const technicalError = {
        success: false,
        status: 'technical_error',
        method,
        username,
        message: 'invalid extractor result'
    };
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        return technicalError;
    }
    if (value.success === true) {
        if (value.status !== 'live' || !isAllowedStreamUrl(value.url)) {
            return technicalError;
        }
        return { ...value, success: true, status: 'live' };
    }
    if (value.success !== false) {
        return technicalError;
    }
    const result = {
        ...value,
        success: false,
        status: FAILURE_STATUSES.has(value.status)
            ? value.status
            : 'technical_error',
        method: typeof value.method === 'string' ? value.method : method,
        username: typeof value.username === 'string' ? value.username : username
    };
    delete result.url;
    delete result.streams;
    delete result.allUrls;
    return result;
}

function classifyFinalFailure(results) {
    const statuses = new Set(
        results
            .map(result => result && result.status)
            .filter(status => FAILURE_STATUSES.has(status))
    );
    if (statuses.has('overloaded')) return 'overloaded';
    if (statuses.has('restricted')) return 'restricted';
    if (statuses.has('technical_error')) return 'technical_error';
    if (statuses.has('offline')) return 'offline';
    if (statuses.has('dependency_missing')) return 'dependency_missing';
    return 'technical_error';
}

function exitCodeForResult(result) {
    if (result && result.success === true && result.status === 'live') return 0;
    if (result && result.status === 'overloaded') return 75;
    if (result && ['offline', 'restricted'].includes(result.status)) return 1;
    return 2;
}

function classifyDirectLiveState({
    username,
    currentPath,
    title,
    bodyText,
    successfulStreamResponse
}) {
    const expectedPath = `/@${username}/live`;
    if (currentPath !== expectedPath) {
        return { status: 'offline', reason: 'target live page redirected' };
    }
    if (successfulStreamResponse) {
        return { status: 'live', reason: 'successful TikTok CDN stream response' };
    }

    const normalizedBody = String(bodyText || '').replace(/\s+/g, ' ').toLowerCase();
    const normalizedTitle = String(title || '').toLowerCase();
    const accountLiveTitle = normalizedTitle.includes(
        `(@${username.toLowerCase()}) is live`
    );
    const endedMarkers = [
        'live has ended',
        'das live ist beendet',
        'live wurde beendet',
        'dieses live ist beendet',
        'stream has ended'
    ];
    if (endedMarkers.some(marker => normalizedBody.includes(marker))) {
        return { status: 'offline', reason: 'target live page reports ended stream' };
    }

    const restrictionMarkers = [
        'dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten',
        'melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen',
        'bei tiktok anmelden',
        'melde dich an für das volle live-erlebnis',
        'melde dich an für das vollständige erlebnis',
        'this live may contain content that could be uncomfortable',
        'log in to tiktok',
        'log in for the full live experience',
        'mature content',
        'age-restricted',
        'viewer discretion'
    ];
    if (
        accountLiveTitle &&
        restrictionMarkers.some(marker => normalizedBody.includes(marker))
    ) {
        return { status: 'restricted', reason: 'target live page requires authentication' };
    }
    if (accountLiveTitle) {
        return {
            status: 'restricted',
            reason: 'target is live but no accessible media response was available'
        };
    }
    return { status: 'offline', reason: 'no account-specific live signal' };
}

function forcedOffline(method, username) {
    if (process.env.TIKTOK_TEST_OFFLINE !== '1') return false;
    process.stderr.write(`${JSON.stringify({
        success: false,
        status: 'offline',
        method,
        username,
        message: 'forced offline test mode'
    })}\n`);
    return true;
}

module.exports = {
    classifyDirectLiveState,
    classifyFinalFailure,
    enforceLoadLimit,
    exitCodeForResult,
    forcedOffline,
    isAllowedStreamUrl,
    isSuccessfulStreamResponse,
    liveHrefSelectors,
    loadState,
    normalizeExtractorResult,
    normalizeUsername,
    qualityKeyFromUrl
};
