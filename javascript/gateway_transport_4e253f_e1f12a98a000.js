#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "815d57d361d48fca61b49c593977b5f60668ab280f1d568051b5c7301eaf47cf", "source_sha256": "4e253f02b715d7d8ae256f0b72f993ca4646b5e466c1f39a9d5e2d3864a4fe77", "target_language": "javascript"}
// gateway_transport.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
// auch in: workspace@local:skills/script-abstractions-manager/scripts/gateway_transport.py
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

/** Gateway-authenticated transport with manager-owned attempt records.

An attempt is saved before submission. If its outcome is uncertain, subsequent
calls only query the same node and attempt; they do not submit it again.
*/
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const crypto = require('crypto');

class TransportUnresolved extends Error {
  constructor(message) {
    super(message);
    this.name = 'TransportUnresolved';
  }
}

function gatewayToken() {
  /** Use the local Gateway credential without changing its configuration. */
  let token = process.env.OPENCLAW_GATEWAY_TOKEN || '';
  token = token.trim();
  if (token) {
    return token;
  }
  const configPath = process.env.OPENCLAW_CONFIG_PATH || 
    path.join(require('os').homedir(), '.openclaw', 'openclaw.json');
  try {
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    token = config.gateway?.auth?.token;
  } catch (error) {
    return '';
  }
  return typeof token === 'string' && !token.startsWith('${') ? token.trim() : '';
}

class GatewayTransport {
  constructor(state, save, url, token, {timeout = 3900, interval = 3, 
             opener = null, clock = null, sleep = null} = {}) {
    const parsed = new URL(url);
    if (!['http:', 'https:'].includes(parsed.protocol) || !parsed.hostname) {
      throw new Error('invalid Gateway URL');
    }
    if (parsed.protocol === 'http:' && !['127.0.0.1', 'localhost', '::1'].includes(parsed.hostname)) {
      throw new Error('unencrypted Gateway must use loopback');
    }
    if (!token.trim() || timeout <= 0 || interval <= 0) {
      throw new Error('Gateway token and positive timeouts required');
    }
    this.state = state;
    this.save = save;
    this.url = url;
    this.token = token.trim();
    this.timeout = timeout;
    this.interval = interval;
    this.opener = opener || ((url, options) => {
      return new Promise((resolve, reject) => {
        const lib = url.protocol === 'https:' ? https : http;
        const req = lib.request(url, options, res => {
          let data = [];
          let totalLength = 0;
          res.on('data', chunk => {
            totalLength += chunk.length;
            if (totalLength > 4000000) {
              res.destroy();
              reject(new Error('response too large'));
            }
            data.push(chunk);
          });
          res.on('end', () => {
            resolve({statusCode: res.statusCode, headers: res.headers, data: Buffer.concat(data)});
          });
        });
        req.on('error', reject);
        req.on('timeout', () => {
          req.destroy();
          reject(new Error('Request timeout'));
        });
        if (options.timeout) req.setTimeout(options.timeout);
        if (options.body) req.write(options.body);
        req.end();
      });
    });
    this.clock = clock || (() => process.hrtime.bigint() / BigInt(1000000));
    this.sleep = sleep || (ms => new Promise(resolve => setTimeout(resolve, ms)));
  }

  async _request(node, request, deviceId = null) {
    const payload = JSON.stringify({node: node, device_id: deviceId, request: request});
    const url = new URL(this.url);
    const options = {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      },
      body: payload,
      timeout: (node === 'node4' ? 150 : 40) * 1000
    };
    
    try {
      const response = await this.opener(url, options);
      const raw = response.data;
      if (raw.length > 4000000) {
        throw new Error('response too large');
      }
      const data = JSON.parse(raw.toString());
      if (typeof data !== 'object' || !('result' in data)) {
        throw new Error('invalid gateway response');
      }
      if (deviceId !== null && data.device_id !== deviceId) {
        throw new Error('gateway device identity mismatch');
      }
      return data.result;
    } catch (error) {
      throw new TransportUnresolved('Gateway request failed', {cause: error});
    }
  }

  async available() {
    const result = await this._request('node1', {operation: 'availability'});
    if (typeof result !== 'object') {
      throw new TransportUnresolved('invalid node availability');
    }
    return result;
  }

  async _release(original, entry) {
    if (entry.released) {
      return;
    }
    try {
      const result = await this._request(
        original.selected_node, 
        {
          operation: 'release',
          job_id: original.job_id,
          attempt_id: original.attempt_id
        }, 
        original.selected_device_id
      );
    } catch (error) {
      // Retry cleanup later; the result is durable in manager state.
      return;
    }
    if (typeof result === 'object' && result.status === 'released' &&
        ['job_id', 'attempt_id', 'selected_node', 'target_language'].every(
          key => result[key] === original[key])) {
      entry.released = true;
      this.save(this.state);
    }
  }

  async releasePending() {
    const auftraege = this.state.auftraege || {};
    for (const [key, entry] of Object.entries(auftraege)) {
      if (typeof entry === 'object' && 
          ['completed', 'rejected', 'failed'].includes(entry.status) &&
          typeof entry.job === 'object') {
        await this._release(entry.job, entry);
      }
    }
  }

  reject(job, reason) {
    /** Record a completed response rejected by validation, before retrying it. */
    if (!job.source_sha256 || !job.target_language) {
      return;
    }
    const key = `${job.source_sha256}:${job.target_language}`;
    const auftraege = this.state.auftraege || {};
    const entry = auftraege[key];
    if (typeof entry !== 'object' || entry.status !== 'completed') {
      return;
    }
    if (entry.job?.attempt_id !== job.attempt_id) {
      throw new TransportUnresolved('rejected attempt identity mismatch');
    }
    entry.status = 'rejected';
    entry.validation_error = String(reason).substring(0, 500);
    this.save(this.state);
  }

  async call(job) {
    if (!job.source_sha256 || !job.target_language || !job.selected_device_id) {
      throw new Error('missing source identity');
    }
    const key = `${job.source_sha256}:${job.target_language}`;
    this.state.auftraege = this.state.auftraege || {};
    const entries = this.state.auftraege;
    let entry = entries[key];
    let fresh = false;
    
    if (typeof entry === 'object' && entry.status === 'rejected') {
      await this._release(entry.job, entry);
      if (!entry.released) {
        throw new TransportUnresolved('rejected attempt release is unresolved');
      }
      const previous = entry;
      const original = {...job, attempt_id: crypto.randomUUID()};
      entry = {
        job: original,
        status: 'submitted',
        previous_attempts: [
          ...(previous.previous_attempts || []),
          {
            job_id: previous.job?.job_id,
            attempt_id: previous.job?.attempt_id,
            selected_node: previous.job?.selected_node,
            validation_error: previous.validation_error
          }
        ]
      };
      entries[key] = entry;
      this.save(this.state);
      fresh = true;
    } else {
      fresh = entry === undefined;
    }
    
    if (entry === undefined) {
      const original = {...job, attempt_id: crypto.randomUUID()};
      entry = {job: original, status: 'submitted'};
      entries[key] = entry;
      // If this write fails there must be no remote submission.
      this.save(this.state);
    }
    
    const original = entry.job;
    // The dispatcher verifies the job object after transport returns.
    Object.assign(job, original);
    
    if (entry.response !== undefined) {
      await this._release(original, entry);
      return entry.response;
    }
    
    if (['failed', 'unknown'].includes(entry.status)) {
      throw new TransportUnresolved('attempt requires reconciliation');
    }
    
    let status = null;
    if (fresh) {
      try {
        status = await this._request(
          original.selected_node,
          {operation: 'execute', job: original},
          original.selected_device_id
        );
      } catch (error) {
        // The request may have been accepted. Query, never resend.
      }
    }
    
    const deadline = this.clock() + this.timeout * 1000;
    while (true) {
      if (status === null) {
        status = await this._request(
          original.selected_node,
          {
            operation: 'status',
            job_id: original.job_id,
            attempt_id: original.attempt_id
          },
          original.selected_device_id
        );
      }
      
      if (typeof status !== 'object') {
        throw new TransportUnresolved('attempt is not known by the node');
      }
      
      if (['job_id', 'attempt_id', 'selected_node', 'target_language'].some(
          k => status[k] !== original[k])) {
        throw new TransportUnresolved('status identity mismatch');
      }
      
      const state = status.status;
      if (state === 'completed') {
        const response = status.response;
        if (typeof response !== 'object' || 
            response.status !== 'ok' ||
            ['job_id', 'selected_node', 'target_language'].some(
              k => response[k] !== original[k]) ||
            typeof response.code !== 'string' || 
            !response.code.trim()) {
          throw new TransportUnresolved('invalid translation result');
        }
        entry.response = response;
        entry.status = 'completed';
        this.save(this.state);
        await this._release(original, entry);
        return response;
      }
      
      if (['failed', 'unknown'].includes(state)) {
        entry.status = state;
        this.save(this.state);
        if (state === 'failed') {
          await this._release(original, entry);
        }
        throw new TransportUnresolved('attempt requires reconciliation');
      }
      
      if (state !== 'running' || this.clock() >= deadline) {
        throw new TransportUnresolved('attempt is unresolved');
      }
      
      await this.sleep(this.interval * 1000);
      status = null;
    }
  }
}

module.exports = {TransportUnresolved, gatewayToken, GatewayTransport};
