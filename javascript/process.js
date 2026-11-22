#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "42b01c89cbe424c69392f2cc1c4e332cef96a8d89ff5375333ff1868c60b8a23", "source_sha256": "d00d873eeab51d166892e3bc7f2dd08b6f535b2c11988d1bb7bc0c123b76e82d", "target_language": "javascript"}
// process.go — portiert nach javascript
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/process.go
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs/promises';
import path from 'path';
import { createHash } from 'crypto';
import YAML from 'yaml';

const workflowVersion = "1";

async function processFile(ctx, translator, tm, docsRoot, filePath, srcLang, tgtLang) {
    const { absPath, relPath } = await resolveDocsPath(docsRoot, filePath);
    
    const content = await fs.readFile(absPath, 'utf8');
    
    const [frontMatter, body] = splitFrontMatter(content);
    let frontData = {};
    if (frontMatter) {
        try {
            frontData = YAML.parse(frontMatter);
        } catch (err) {
            throw new Error(`frontmatter parse failed for ${relPath}: ${err.message}`);
        }
    }
    
    await translateFrontMatter(ctx, translator, tm, frontData, relPath, srcLang, tgtLang);
    
    let translatedBody = await translateHTMLBlocks(ctx, translator, body, srcLang, tgtLang);
    
    const segments = await extractSegments(translatedBody, relPath);
    
    const namespace = cacheNamespace();
    for (const seg of segments) {
        seg.CacheKey = cacheKey(namespace, srcLang, tgtLang, seg.SegmentID, seg.TextHash);
        const entry = tm.get(seg.CacheKey);
        if (entry) {
            seg.Translated = entry.Translated;
            continue;
        }
        const translated = await translator.translate(ctx, seg.Text, srcLang, tgtLang);
        seg.Translated = translated;
        const newEntry = {
            CacheKey: seg.CacheKey,
            SegmentID: seg.SegmentID,
            SourcePath: relPath,
            TextHash: seg.TextHash,
            Text: seg.Text,
            Translated: translated,
            Provider: docsPiProvider(),
            Model: docsPiModel(),
            SrcLang: srcLang,
            TgtLang: tgtLang,
            UpdatedAt: new Date().toISOString()
        };
        tm.put(newEntry);
    }
    
    const translatedBodyFinal = applyTranslations(translatedBody, segments);
    const updatedFront = await encodeFrontMatter(frontData, relPath, content);
    
    const outputPath = path.join(docsRoot, tgtLang, relPath);
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    
    const output = updatedFront + translatedBodyFinal;
    await fs.writeFile(outputPath, output, 'utf8');
    
    return [false, outputPath, null];
}

function splitFrontMatter(content) {
    if (!content.startsWith('---')) {
        return ['', content];
    }
    const lines = content.split('\n');
    if (lines.length < 2) {
        return ['', content];
    }
    let endIndex = -1;
    for (let i = 1; i < lines.length; i++) {
        if (lines[i].trim() === '---') {
            endIndex = i;
            break;
        }
    }
    if (endIndex === -1) {
        return ['', content];
    }
    const front = lines.slice(1, endIndex).join('\n');
    let body = lines.slice(endIndex + 1).join('\n');
    if (body.startsWith('\n')) {
        body = body.substring(1);
    }
    return [front, body];
}

function encodeFrontMatter(frontData, relPath, source) {
    if (!frontData) {
        frontData = {};
    }
    frontData['x-i18n'] = {
        source_path: relPath,
        source_hash: hashBytes(source),
        provider: docsPiProvider(),
        model: docsPiModel(),
        workflow: workflowVersion,
        generated_at: new Date().toISOString()
    };
    const encoded = YAML.stringify(frontData);
    return `---\n${encoded}---\n\n`;
}

async function translateFrontMatter(ctx, translator, tm, data, relPath, srcLang, tgtLang) {
    if (!data || Object.keys(data).length === 0) {
        return;
    }
    
    if (typeof data.summary === 'string') {
        if (docsI18nVerboseLogs()) {
            console.log(`docs-i18n: frontmatter start ${relPath} field=summary bytes=${data.summary.length}`);
        }
        const translated = await translateSnippet(ctx, translator, tm, `${relPath}:frontmatter:summary`, data.summary, srcLang, tgtLang);
        if (docsI18nVerboseLogs()) {
            console.log(`docs-i18n: frontmatter done ${relPath} field=summary out_bytes=${translated.length}`);
        }
        data.summary = translated;
    }
    
    if (typeof data.title === 'string') {
        if (docsI18nVerboseLogs()) {
            console.log(`docs-i18n: frontmatter start ${relPath} field=title bytes=${data.title.length}`);
        }
        const translated = await translateSnippet(ctx, translator, tm, `${relPath}:frontmatter:title`, data.title, srcLang, tgtLang);
        if (docsI18nVerboseLogs()) {
            console.log(`docs-i18n: frontmatter done ${relPath} field=title out_bytes=${translated.length}`);
        }
        data.title = translated;
    }
    
    if (Array.isArray(data.read_when)) {
        const translated = [];
        for (let idx = 0; idx < data.read_when.length; idx++) {
            const item = data.read_when[idx];
            if (typeof item !== 'string') {
                translated.push(item);
                continue;
            }
            if (docsI18nVerboseLogs()) {
                console.log(`docs-i18n: frontmatter start ${relPath} field=read_when[${idx}] bytes=${item.length}`);
            }
            const value = await translateSnippet(
                ctx, 
                translator, 
                tm, 
                `${relPath}:frontmatter:read_when:${idx}`, 
                item, 
                srcLang, 
                tgtLang
            );
            if (docsI18nVerboseLogs()) {
                console.log(`docs-i18n: frontmatter done ${relPath} field=read_when[${idx}] out_bytes=${value.length}`);
            }
            translated.push(value);
        }
        data.read_when = translated;
    }
}

function docsI18nVerboseLogs() {
    const value = (process.env.OPENCLAW_DOCS_I18N_VERBOSE_LOGS || '').trim();
    if (!value) {
        return false;
    }
    const lower = value.toLowerCase();
    return ['1', 'true', 'yes', 'on', 'debug', 'verbose'].includes(lower);
}

async function translateSnippet(ctx, translator, tm, segmentID, textValue, srcLang, tgtLang) {
    if (textValue.trim() === '') {
        return textValue;
    }
    const namespace = cacheNamespace();
    const textHash = hashText(textValue);
    const ck = cacheKey(namespace, srcLang, tgtLang, segmentID, textHash);
    const entry = tm.get(ck);
    if (entry) {
        return entry.Translated;
    }
    const translated = await translator.translate(ctx, textValue, srcLang, tgtLang);
    let shouldCache = true;
    const validationErr = validateFrontmatterScalarTranslation(textValue, translated);
    if (validationErr) {
        console.log(`docs-i18n: frontmatter fallback ${segmentID} reason=${validationErr.message}`);
        translated = textValue;
        shouldCache = false;
    }
    const newEntry = {
        CacheKey: ck,
        SegmentID: segmentID,
        SourcePath: segmentID,
        TextHash: textHash,
        Text: textValue,
        Translated: translated,
        Provider: docsPiProvider(),
        Model: docsPiModel(),
        SrcLang: srcLang,
        TgtLang: tgtLang,
        UpdatedAt: new Date().toISOString()
    };
    if (shouldCache) {
        tm.put(newEntry);
    }
    return translated;
}

function validateFrontmatterScalarTranslation(source, translated) {
    const trimmed = translated.trim();
    if (trimmed === '') {
        return new Error('empty translation');
    }
    const lower = trimmed.toLowerCase();
    if (lower.includes('<frontmatter>') || lower.includes('</frontmatter>') || 
        lower.includes('<body>') || lower.includes('</body>')) {
        return new Error('tagged document wrapper detected');
    }
    if (trimmed.includes('[[[FM_')) {
        return new Error('frontmatter marker leaked into scalar translation');
    }
    if (trimmed.includes('\n---\n') || trimmed.startsWith('---\n')) {
        return new Error('yaml document boundary detected');
    }
    if (!source.includes('\n') && (trimmed.match(/\n/g) || []).length >= 3) {
        return new Error('unexpected multiline expansion');
    }
    const sourceLen = source.trim().length;
    const translatedLen = trimmed.length;
    if (sourceLen > 0) {
        let limit = sourceLen * 8 + 256;
        if (limit < 512) {
            limit = 512;
        }
        if (translatedLen > limit) {
            return new Error(`unexpected size expansion source=${sourceLen} translated=${translatedLen}`);
        }
    }
    for (const key of ['title:', 'summary:', 'read_when:']) {
        if (lower.includes(`\n${key}`) || lower.startsWith(key)) {
            return new Error('frontmatter key leaked into scalar translation');
        }
    }
    return null;
}

// Helper functions that need to be implemented based on your specific requirements
async function resolveDocsPath(docsRoot, filePath) {
    const absPath = path.resolve(docsRoot, filePath);
    const relPath = path.relative(docsRoot, absPath);
    return { absPath, relPath };
}

function hashBytes(bytes) {
    return createHash('sha256').update(bytes).digest('hex');
}

function hashText(text) {
    return createHash('sha256').update(text, 'utf8').digest('hex');
}

function cacheKey(namespace, srcLang, tgtLang, segmentID, textHash) {
    return `${namespace}:${srcLang}:${tgtLang}:${segmentID}:${textHash}`;
}

function cacheNamespace() {
    return 'default';
}

function docsPiProvider() {
    return 'unknown';
}

function docsPiModel() {
    return 'unknown';
}

// These functions are referenced but not provided in the original code
// You'll need to implement them based on your specific requirements
async function translateHTMLBlocks(ctx, translator, body, srcLang, tgtLang) {
    // Implementation needed
    return body;
}

async function extractSegments(body, relPath) {
    // Implementation needed
    return [];
}

function applyTranslations(body, segments) {
    // Implementation needed
    return body;
}
