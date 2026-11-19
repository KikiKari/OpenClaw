import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { accessSync, constants, statSync } from 'node:fs';
import path from 'node:path';

const MAX_REQUEST = 2_000_000;
const MAX_RESPONSE = 4_000_000;

// Per-process execution state only: the node never writes job data to disk.
export function createNodeCommand({ node, python, worker, spawnProcess = spawn,
  hasCredential = () => Boolean(process.env.OPENROUTER_API_KEY?.trim()) }) {
  const tasks = new Map();
  function available() {
    if (!node || !hasCredential() || typeof python !== 'string' || typeof worker !== 'string' ||
        !path.isAbsolute(python) || !path.isAbsolute(worker)) return false;
    try {
      if (!statSync(python).isFile() || !statSync(worker).isFile()) return false;
      accessSync(python, constants.X_OK); accessSync(worker, constants.R_OK);
      return true;
    } catch { return false; }
  }
  function start(job) {
    if (!job || typeof job !== 'object' || job.selected_node !== node ||
        typeof job.job_id !== 'string' || !job.job_id ||
        typeof job.attempt_id !== 'string' || !job.attempt_id ||
        typeof job.target_language !== 'string' || !job.target_language.trim()) throw new Error('invalid job');
    const bytes = Buffer.from(JSON.stringify(job));
    if (bytes.length > MAX_REQUEST) throw new Error('request too large');
    const key = JSON.stringify([job.job_id, job.attempt_id]);
    const digest = createHash('sha256').update(bytes).digest('hex');
    const old = tasks.get(key);
    if (old) {
      if (old.digest !== digest) throw new Error('attempt conflict');
      return old;
    }
    if (!available()) throw new Error('worker unavailable');
    // A second attempt for the same job cannot silently run on this node.
    if ([...tasks.values()].some(task => task.jobId === job.job_id)) throw new Error('job already admitted');
    if ([...tasks.values()].filter(task => task.status !== 'released' &&
        !(task.status === 'unknown' && task.workerExited)).length >= 4)
      throw new Error('node job capacity reached');
    if (tasks.size >= 4096) {
      const released = [...tasks].find(([, task]) => task.status === 'released');
      if (!released) throw new Error('node job capacity reached');
      tasks.delete(released[0]);
    }
    const task = { jobId: job.job_id, attemptId: job.attempt_id, targetLanguage: job.target_language,
      node, digest, status: 'running' };
    tasks.set(key, task);
    let child;
    try {
      child = spawnProcess(python, [worker, '--node', node], { stdio: ['pipe', 'pipe', 'ignore'], shell: false,
        env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' } });
      let output = []; let size = 0; let overflow = false;
      child.stdout.on('data', chunk => {
        size += chunk.length;
        if (size <= MAX_RESPONSE) output.push(chunk);
        else { overflow = true; output = []; }
      });
      child.stdin.on('error', () => {});
      child.on('error', () => { task.status = 'unknown'; });
      child.on('close', code => {
        task.workerExited = true;
        if (task.status !== 'running') return;
        if (code !== 0 || overflow) { task.status = 'unknown'; return; }
        try {
          const result = JSON.parse(Buffer.concat(output).toString('utf8'));
          if (result.status !== 'ok' || !result.code ||
              ['job_id', 'selected_node', 'target_language'].some(k => result[k] !== job[k])) throw new Error();
          task.status = 'completed'; task.response = result;
        } catch { task.status = 'failed'; }
      });
      child.stdin.end(bytes);
    } catch { task.status = 'unknown'; }
    return task;
  }
  function publicStatus(task) {
    return task ? { job_id: task.jobId, attempt_id: task.attemptId, selected_node: task.node,
                    target_language: task.targetLanguage, status: task.status,
                    ...(task.response ? { response: task.response } : {}) } : null;
  }
  function processMessage(message) {
    if (message.length > MAX_REQUEST) throw new Error('request too large');
    const request = JSON.parse(Buffer.from(message).toString('utf8'));
    if (request.operation === 'execute') return publicStatus(start(request.job));
    if (request.operation === 'status' && typeof request.job_id === 'string' && typeof request.attempt_id === 'string') {
      return publicStatus(tasks.get(JSON.stringify([request.job_id, request.attempt_id])));
    }
    if (request.operation === 'release' && typeof request.job_id === 'string' && typeof request.attempt_id === 'string') {
      const task = tasks.get(JSON.stringify([request.job_id, request.attempt_id]));
      if (!task || !['completed', 'failed', 'unknown', 'released'].includes(task.status)) throw new Error('result not ready');
      delete task.response;
      task.status = 'released';
      return publicStatus(task);
    }
    throw new Error('invalid operation');
  }
  return { command: 'abstractions.translate.v1', cap: 'abstractions', dangerous: true, duplex: true,
    isAvailable: available,
    handle: async (_params, io) => {
      if (!io?.frames) throw new Error('duplex required');
      io.signal.throwIfAborted();
      const frames = io.frames;
      return await new Promise((resolve, reject) => {
        let done = false;
        const abort = () => { if (!done) { done = true; reject(new Error('channel closed')); } };
        io.signal.addEventListener('abort', abort, { once: true });
        const unsubscribe = frames.onMessage(async message => {
          if (done) throw new Error('duplicate request');
          done = true;
          try {
            const result = processMessage(message);
            const encoded = Buffer.from(JSON.stringify({ result }));
            if (encoded.length > MAX_RESPONSE) throw new Error('response too large');
            await frames.send(encoded);
            resolve('{"ok":true}');
          } catch (error) { reject(error); }
          finally { unsubscribe(); io.signal.removeEventListener('abort', abort); }
        });
      });
    },
  };
}
