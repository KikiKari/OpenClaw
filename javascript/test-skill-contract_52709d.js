#!/usr/bin/env node
// test-skill-contract.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/test-skill-contract.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/** Regression checks for /tiktok_live_mon routing and monitor actions. */

const fs = require('fs');
const path = require('path');

const SKILL = path.resolve(__dirname, '..', 'SKILL.md');
const DISPATCHER = (
    "/home/openclaw/.openclaw/workspace/tiktok-monitor/" +
    "tiktok_dispatch.py url @name --quality auto --json"
);
const CONTROLLER = (
    "/home/openclaw/.openclaw/workspace/tiktok-monitor/" +
    "tiktok-monitorctl.sh"
);

class MonitorSkillContractTests {
    static setUpClass() {
        this.text = fs.readFileSync(SKILL, 'utf8');
        this.normalized_text = this.text.replace(/\s+/g, ' ').trim();
    }

    static test_bare_handle_uses_dispatcher_as_first_tool_call() {
        if (!this.normalized_text.includes("dispatcher exec must be the first tool call")) {
            throw new Error("Missing: dispatcher exec must be the first tool call");
        }
        if (!this.text.includes(DISPATCHER)) {
            throw new Error("Missing: DISPATCHER");
        }
        if (!this.text.includes("A bare handle never starts a daemon")) {
            throw new Error("Missing: A bare handle never starts a daemon");
        }
    }

    static test_slash_command_bypasses_the_model() {
        const expectedItems = [
            "command-dispatch: tool",
            "command-tool: tiktok_live_mon_command",
            "command-arg-mode: raw"
        ];
        for (const expected of expectedItems) {
            if (!this.text.includes(expected)) {
                throw new Error(`Missing: ${expected}`);
            }
        }
    }

    static test_no_preliminary_playwright_or_dependency_probe() {
        const expectedItems = [
            "Before this dispatcher call, do not invoke or inspect",
            "`tiktok-check-profile.js`",
            "Do not attempt to install or repair browser dependencies",
            "failed preliminary tool call"
        ];
        for (const expected of expectedItems) {
            if (!this.normalized_text.includes(expected)) {
                throw new Error(`Missing: ${expected}`);
            }
        }
    }

    static test_direct_exec_without_shell_wrapper() {
        const expectedItems = [
            "Invoke that executable directly as the exec command",
            "Do not invoke `bash`",
            "`bash -lc`",
            "wrapper must not be attempted in the first place"
        ];
        for (const expected of expectedItems) {
            if (!this.normalized_text.includes(expected)) {
                throw new Error(`Missing: ${expected}`);
            }
        }
    }

    static test_success_json_wins_over_trailing_diagnostics() {
        const expectedItems = [
            "display the final stdout JSON before trailing stderr diagnostics",
            "regardless of its visual position",
            "the tool execution succeeded",
            "Never replace such a result with a generic tool-failure message",
            "`node_available`"
        ];
        for (const expected of expectedItems) {
            if (!this.normalized_text.includes(expected)) {
                throw new Error(`Missing: ${expected}`);
            }
        }
    }

    static test_running_dispatcher_is_polled_without_restart() {
        const expectedItems = [
            "Start exactly one dispatcher exec per request",
            "do not rerun exec",
            'sessionId: "NAME"',
            "Continue polling that same name until completion"
        ];
        for (const expected of expectedItems) {
            if (!this.text.includes(expected)) {
                throw new Error(`Missing: ${expected}`);
            }
        }
    }

    static test_monitor_actions_remain_controller_backed() {
        const actions = ["start", "status", "stop"];
        for (const action of actions) {
            if (!this.text.includes(`${CONTROLLER} ${action} @name`)) {
                throw new Error(`Missing: ${CONTROLLER} ${action} @name`);
            }
        }
        if (!this.text.includes("prevents duplicate active monitors")) {
            throw new Error("Missing: prevents duplicate active monitors");
        }
        if (!this.text.includes("Without the current word `start`")) {
            throw new Error("Missing: Without the current word `start`");
        }
    }

    static test_one_shot_response_contract_covers_all_statuses() {
        const legacy = (
            "@<handle> is currently " +
            "<OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\n" +
            "VLC/MPV: not available\n" +
            "Method: <method>"
        );
        if (!this.text.includes(legacy)) {
            throw new Error("Missing: legacy response format");
        }
        if (!this.text.includes("@<handle> is currently LIVE on TikTok.\nTitel: <room.title>")) {
            throw new Error("Missing: live response format");
        }

        const normalizedText = this.text.replace(/\s+/g, ' ').trim();
        const expectedItems = [
            "Stream-URLs:",
            "<label> (HLS):",
            "<label> (FLV):",
            "exactly one URL and nothing else",
            "No raw URL appears in plain text"
        ];
        for (const expected of expectedItems) {
            if (!normalizedText.includes(expected)) {
                throw new Error(`Missing: ${expected}`);
            }
        }

        const statuses = [
            "live", "offline", "restricted", "overloaded",
            "dependency_missing", "technical_error"
        ];
        for (const status of statuses) {
            if (!this.text.includes(status)) {
                throw new Error(`Missing: ${status}`);
            }
        }
    }

    static test_invalid_current_input_is_not_taken_from_history() {
        if (!this.text.includes("Derive the action, handle, hours, and poll interval only")) {
            throw new Error("Missing: Derive the action, handle, hours, and poll interval only");
        }
        if (!this.text.includes("Never take them from")) {
            throw new Error("Missing: Never take them from");
        }
    }
}

function runTests() {
    MonitorSkillContractTests.setUpClass();
    
    const methods = Object.getOwnPropertyNames(MonitorSkillContractTests)
        .filter(method => method.startsWith('test_'));
    
    let passed = 0;
    let failed = 0;
    
    for (const method of methods) {
        try {
            MonitorSkillContractTests[method]();
            console.log(`✓ ${method}`);
            passed++;
        } catch (error) {
            console.log(`✗ ${method}: ${error.message}`);
            failed++;
        }
    }
    
    console.log(`\n${passed} passed, ${failed} failed`);
    if (failed > 0) {
        process.exit(1);
    }
}

runTests();
