#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "3e11f50fe57ab7964bea5f52310e0c6f4924c8a1f6b1899e7e0b0a20276355dc", "source_sha256": "0cfda5c5495fad1eb8cbf8562ac3b851f251f1a3645890dc28e6f870336a28b5", "target_language": "javascript"}
// gateway_transport.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/gateway_transport.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

/** Gateway-authenticated transport with manager-owned attempt records.

An attempt is saved before submission. If its outcome is uncertain, subsequent
calls only query the same node and attempt; they do not submit it again.
*/
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const urlModule = require('url');

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
  let configPath = process.env.OPENCLAW_CONFIG_PATH;
  if (!configPath) {
    configPath = path.join(require('os').homedir(), '.openclaw', 'openclaw.json');
  }
  try {
    const configContent = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(configContent);
    token = config.gateway?.auth?.token;
  } catch (error) {
    return '';
  }
  if (typeof token === 'string' && !token.startsWith('${')) {
    return token.trim();
  }
  return '';
}

class GatewayTransport {
  constructor(state, save, url, token, { timeout = 3900, interval = 3, opener = null, clock = null, sleep = null } = {}) {
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
    this.opener = opener || ((req, callback) => {
      const protocol = req.protocol === 'https:' ? https : http;
      const request = protocol.request(req, callback);
      request.on('error', (err) => callback(err));
      return request;
    });
    this.clock = clock || (() => Date.now() / 1000);
    this.sleep = sleep || ((ms) => new Promise(resolve => setTimeout(resolve, ms * 1000)));
  }

  _request(node, request, deviceId = null) {
    return new Promise((resolve, reject) => {
      const payloadData = {
        node: node,
        device_id: deviceId,
        request: request
      };
      
      const payload = JSON.stringify(payloadData);
      const urlObj = new URL(this.url);
      
      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port,
        path: urlObj.pathname,
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + this.token,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload)
        },
        protocol: urlObj.protocol
      };

      const req = (urlObj.protocol === 'https:' ? https : http).request(options, (res) => {
        let rawData = [];
        let totalLength = 0;
        
        res.on('data', (chunk) => {
          totalLength += chunk.length;
          if (totalLength > 4_000_000) {
            res.destroy();
            reject(new Error('response too large'));
            return;
          }
          rawData.push(chunk);
        });
        
        res.on('end', () => {
          try {
            const raw = Buffer.concat(rawData);
            if (raw.length > 4_000_000) {
              throw new Error('response too large');
            }
            
            const data = JSON.parse(raw.toString('utf8'));
            if (typeof data !== 'object' || !('result' in data)) {
              throw new Error('invalid gateway response');
            }
            
            if (deviceId !== null && data.device_id !== deviceId) {
              throw new Error('gateway device identity mismatch');
            }
            
            resolve(data.result);
          } catch (error) {
            reject(error);
          }
        });
      });

      req.on('error', (error) => {
        reject(new TransportUnresolved('Gateway request failed', { cause: error }));
      });

      req.setTimeout(node === 'node4' ? 150000 : 40000, () => {
        req.destroy();
        reject(new Error('Request timeout'));
      });

      req.write(payload);
      req.end();
    }).catch((error) => {
      if (error instanceof TransportUnresolved) {
        throw error;
      }
      throw new TransportUnresolved('Gateway request failed', { cause: error });
    });
  }

  async available() {
    const result = await this._request('node1', { operation: 'availability' });
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
      
      if (typeof result === 'object' && 
          result.status === 'released' && 
          ['job_id', 'attempt_id', 'selected_node', 'target_language'].every(key => 
            result[key] === original[key])) {
        entry.released = true;
        this.save(this.state);
      }
    } catch (error) {
      // Retry cleanup later; the result is durable in manager state.
      return;
    }
  }

  releasePending() {
    const entries = this.state.auftraege || {};
    for (const entry of Object.values(entries)) {
      if (typeof entry === 'object' && 
          ['completed', 'failed', 'unknown'].includes(entry.status) && 
          typeof entry.job === 'object') {
        this._release(entry.job, entry);
      }
    }
  }

  async call(job) {
    if (!job.source_sha256 || !job.target_language || !job.selected_device_id) {
      throw new Error('missing source identity');
    }
    
    const key = job.source_sha256 + ':' + job.target_language;
    this.state.auftraege = this.state.auftraege || {};
    const entries = this.state.auftraege;
    let entry = entries[key];
    const fresh = entry === undefined;
    
    if (fresh) {
      const { randomUUID } = require('crypto');
      const original = {
        ...job,
        attempt_id: randomUUID()
      };
      entry = { job: original, status: 'submitted' };
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
          { operation: 'execute', job: original },
          original.selected_device_id
        );
      } catch (error) {
        // The request may have been accepted. Query, never resend.
      }
    }
    
    const deadline = this.clock() + this.timeout;
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
      
      if (['job_id', 'attempt_id', 'selected_node', 'target_language'].some(k => 
          status[k] !== original[k])) {
        throw new TransportUnresolved('status identity mismatch');
      }
      
      const state = status.status;
      if (state === 'completed') {
        const response = status.response;
        if (typeof response !== 'object' || 
            response.status !== 'ok' || 
            ['job_id', 'selected_node', 'target_language'].some(k => 
              response[k] !== original[k]) || 
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
        await this._release(original, entry);
        throw new TransportUnresolved('attempt requires reconciliation');
      }
      
      if (state !== 'running' || this.clock() >= deadline) {
        throw new TransportUnresolved('attempt is unresolved');
      }
      
      await this.sleep(this.interval);
      status = null;
    }
  }
}

// Make the class callable like in Python
GatewayTransport.prototype[Symbol.toPrimitive] = function() {
  return this.call.bind(this);
};

module.exports = { TransportUnresolved, gatewayToken, GatewayTransport };
