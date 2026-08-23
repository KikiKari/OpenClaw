#!/usr/bin/env node
// test-skill-contract.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:skills/tiktok-live/scripts/test-skill-contract.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/** Regression checks for the documented /tiktok_live normal flow. */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import { strict as assert } from 'assert';

// Get the directory of the current file
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SKILL_PATH = resolve(__dirname, '..', 'SKILL.md');
const CANONICAL_COMMAND = (
    "/home/openclaw/.openclaw/workspace/tiktok-monitor/" +
    "tiktok_dispatch.py url @handle --quality auto --json"
);
const NODE_COMMAND = CANONICAL_COMMAND;

class SkillContractTests {
    static text = '';
    static normalizedText = '';

    static setUp() {
        this.text = readFileSync(SKILL_PATH, 'utf8');
        this.normalizedText = this.text.replace(/\s+/g, ' ');
    }

    static test_dispatcher_is_the_documented_first_action() {
        assert.ok(this.text.includes("Make the existing dispatcher the first action"));
        assert.ok(this.normalizedText.includes("first tool call of the request"));
        assert.equal((this.text.match(new RegExp(CANONICAL_COMMAND, 'g')) || []).length, 2);
    }

    static test_slash_command_bypasses_the_model() {
        const expected = [
            "command-dispatch: tool",
            "command-tool: tiktok_live_command",
            "command-arg-mode: raw"
        ];
        
        for (const item of expected) {
            assert.ok(this.text.includes(item), `Missing: ${item}`);
        }
    }

    static test_no_preliminary_playwright_or_dependency_probe() {
        const expected = [
            "Before this dispatcher call, do not invoke or inspect",
            "`tiktok-check-profile.js`",
            "Do not attempt to install or repair browser dependencies",
            "failed preliminary tool call"
        ];
        
        for (const item of expected) {
            assert.ok(this.normalizedText.includes(item), `Missing: ${item}`);
        }
    }

    static test_direct_exec_without_shell_wrapper() {
        const expected = [
            "Invoke that executable directly as the exec command",
            "Do not invoke `bash`",
            "`bash -lc`",
            "wrapper must not be attempted in the first place"
        ];
        
        for (const item of expected) {
            assert.ok(this.normalizedText.includes(item), `Missing: ${item}`);
        }
    }

    static test_success_json_wins_over_trailing_diagnostics() {
        const expected = [
            "display the final stdout JSON before trailing stderr diagnostics",
            "regardless of its visual position",
            "the tool execution succeeded",
            "Never replace such a result with a generic tool-failure message",
            "`node_available`"
        ];
        
        for (const item of expected) {
            assert.ok(this.normalizedText.includes(item), `Missing: ${item}`);
        }
    }

    static test_auto_host_and_bounded_node_fallback() {
        const expected = [
            "tools.exec.host=auto",
            "omit both the `host` and `node` fields",
            "retry exactly once",
            "least-loaded connected paired node",
            "host=node",
            NODE_COMMAND,
            "Never replace it with"
        ];
        
        for (const item of expected) {
            assert.ok(this.text.includes(item), `Missing: ${item}`);
        }
        
        assert.ok(this.normalizedText.includes("`technical_error`, `dependency_missing`, or `overloaded`"));
        assert.ok(!this.text.includes("host=gateway"));
        assert.ok(this.text.includes("Never start a second node retry"));
        assert.ok(this.text.includes("never\nchange the global exec host"));
        assert.ok(this.text.includes("runtime block occurs before the Node allowlist"));
        assert.equal((this.text.match(new RegExp(CANONICAL_COMMAND, 'g')) || []).length, 2);
    }

    static test_public_contract_covers_legacy_and_rich_formats() {
        const legacy = (
            "@<handle> is currently " +
            "<OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\n" +
            "VLC/MPV: not available\n" +
            "Method: <validated method>"
        );
        
        assert.ok(this.text.includes(legacy));
        assert.ok(this.text.includes("@<handle> is currently LIVE on TikTok.\nTitel: <room.title>"));
        
        const expected = [
            "Stream-URLs:",
            "<label> (HLS):",
            "<label> (FLV):",
            "Live seit: <HH:MM UTC> (<Xh Ym>)",
            "exactly one URL and nothing else",
            "degrades to the legacy three lines including the `VLC/MPV:` URL",
            "No raw URL appears in plain text"
        ];
        
        for (const item of expected) {
            assert.ok(this.normalizedText.includes(item), `Missing: ${item}`);
        }
    }

    static test_existing_capabilities_are_preserved() {
        const capabilities = [
            "Node", "browser", "file", "directory", "configuration",
            "dependency", "diagnostic tools remain available"
        ];
        
        for (const capability of capabilities) {
            assert.ok(this.text.includes(capability), `Missing capability: ${capability}`);
        }
    }

    static test_no_response_flag_is_documented() {
        assert.ok(!this.text.includes("--response"));
    }

    static test_atomic_output_and_synchronized_audio() {
        const expected = [
            "send it atomically",
            "Preserve every returned URL byte-for-byte",
            "channel voice output set to `always`",
            "Do not invoke the `tts` tool",
            "do not emit `[[tts:text]]` wrappers",
            "visible text remains the authoritative source"
        ];
        
        for (const item of expected) {
            assert.ok(this.normalizedText.includes(item), `Missing: ${item}`);
        }
    }
}

// Run tests
function runTests() {
    SkillContractTests.setUp();
    
    const methods = Object.getOwnPropertyNames(SkillContractTests)
        .filter(method => method.startsWith('test_'));
    
    let passed = 0;
    let failed = 0;
    
    for (const method of methods) {
        try {
            SkillContractTests[method]();
            console.log(`✓ ${method}`);
            passed++;
        } catch (error) {
            console.error(`✗ ${method}: ${error.message}`);
            failed++;
        }
    }
    
    console.log(`\n${passed} passed, ${failed} failed`);
    
    if (failed > 0) {
        process.exit(1);
    }
}

runTests();
