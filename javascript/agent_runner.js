#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "eb3aa94a92901435502ce9efdadae6213cf88b467b0be9fb378faeb65f0ffddf", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "javascript"}
// agent_runner.py — portiert nach javascript
// Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/** Run a gateway-only OpenClaw agent turn for a porting task. */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { v4: uuidv4 } = require('uuid');

function allowedModels(configPath) {
    const configContent = fs.readFileSync(configPath, 'utf-8');
    const config = JSON.parse(configContent);
    const defaults = config.agents?.defaults || {};
    const models = new Set(defaults.models || []);
    const selected = defaults.model;
    if (typeof selected === 'string') {
        models.add(selected);
    } else if (selected && typeof selected === 'object') {
        const primary = selected.primary;
        const fallbacks = selected.fallbacks || [];
        if (typeof primary === 'string') models.add(primary);
        fallbacks.forEach(fb => {
            if (typeof fb === 'string') models.add(fb);
        });
    }
    return models;
}

function run(task, model, timeout) {
    return new Promise((resolve, reject) => {
        if (!task.trim() || task.length > 500) {
            return reject(new Error("task must contain 1–500 characters"));
        }
        if (!(1 <= timeout && timeout <= 7200)) {
            return reject(new Error("timeout must be between 1 and 7200 seconds"));
        }

        const openclawConfigEnv = process.env.OPENCLAW_CONFIG;
        const homeDir = process.env.HOME || process.env.USERPROFILE;
        const defaultConfigPath = path.join(homeDir, '.openclaw', 'openclaw.json');
        const configPath = openclawConfigEnv ? openclawConfigEnv : defaultConfigPath;

        let models;
        try {
            models = allowedModels(configPath);
        } catch (err) {
            return reject(new Error(`Failed to read allowed models: ${err.message}`));
        }

        if (!models.has(model)) {
            return reject(new Error("model is not in the configured OpenClaw model allowlist"));
        }

        const [provider, modelId] = model.split('/');
        if (!provider || !modelId) {
            return reject(new Error("model must have provider/model form"));
        }

        const runId = uuidv4();
        const params = {
            message: task.trim(),
            provider: provider,
            model: modelId,
            sessionKey: `agent:main:abstraction-runner:${runId}`,
            idempotencyKey: runId,
            timeout: timeout,
            deliver: false,
        };

        const command = [
            'openclaw', 'gateway', 'call', 'agent',
            '--params', JSON.stringify(params),
            '--expect-final',
            '--json',
            '--timeout', String((timeout + 10) * 1000)
        ];

        const child = spawn(command[0], command.slice(1), {
            stdio: ['pipe', 'pipe', 'pipe'],
            timeout: (timeout + 20) * 1000
        });

        let stdoutData = '';
        let stderrData = '';

        child.stdout.on('data', data => {
            stdoutData += data.toString();
        });

        child.stderr.on('data', data => {
            stderrData += data.toString();
        });

        child.on('error', err => {
            reject(new Error(`Failed to start subprocess: ${err.message}`));
        });

        child.on('close', code => {
            if (code !== 0) {
                const errorMsg = stderrData || stdoutData || "OpenClaw agent call failed";
                console.error(errorMsg.trim());
                return resolve(code);
            }

            let response;
            try {
                response = JSON.parse(stdoutData);
            } catch (parseErr) {
                return reject(new Error("OpenClaw returned invalid JSON"));
            }

            if (typeof response !== 'object' || response.status !== 'ok') {
                return reject(new Error("OpenClaw did not return a completed agent result"));
            }

            const agentResult = response.result;
            if (typeof agentResult !== 'object') {
                return reject(new Error("OpenClaw returned no agent result"));
            }

            const meta = agentResult.meta || {};
            if (typeof meta !== 'object' || meta.aborted || meta.error) {
                return reject(new Error("OpenClaw agent execution did not complete successfully"));
            }

            const payloads = agentResult.payloads || [];
            if (!Array.isArray(payloads) || payloads.some(item => typeof item !== 'object' || item.isError)) {
                return reject(new Error("OpenClaw agent returned an error"));
            }

            if (!payloads.some(item => typeof item.text === 'string' && item.text.trim())) {
                return reject(new Error("OpenClaw agent returned no text"));
            }

            console.log(JSON.stringify(response, null, 0));
            resolve(0);
        });
    });
}

async function main() {
    const args = require('yargs')
        .option('task', {
            describe: 'The task to execute',
            type: 'string',
            demandOption: true
        })
        .option('model', {
            describe: 'Model identifier in provider/model format',
            type: 'string',
            demandOption: true
        })
        .option('timeout', {
            describe: 'Timeout in seconds',
            type: 'number',
            default: 1800
        })
        .option('gateway-only', {
            describe: 'Indicates that this is a gateway-only run',
            type: 'boolean',
            default: false
        })
        .help()
        .argv;

    if (!args['gateway-only']) {
        console.error("agent_runner: no worker/relay transport configured; gateway-only requires --gateway-only");
        process.exit(1);
    }

    try {
        const exitCode = await run(args.task, args.model, args.timeout);
        process.exit(exitCode);
    } catch (error) {
        console.error(`agent_runner: ${error.message}`);
        process.exit(1);
    }
}

if (require.main === module) {
    main().catch(err => {
        console.error(`Unexpected error in main: ${err.message}`);
        process.exit(1);
    });
}
