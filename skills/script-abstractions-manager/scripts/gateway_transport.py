"""Gateway-authenticated transport with manager-owned attempt records.

An attempt is saved before submission. If its outcome is uncertain, subsequent
calls only query the same node and attempt; they do not submit it again.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


class TransportUnresolved(RuntimeError):
    pass


def gateway_token():
    """Use the local Gateway credential without changing its configuration."""
    token = os.environ.get('OPENCLAW_GATEWAY_TOKEN', '').strip()
    if token:
        return token
    path = Path(os.environ.get('OPENCLAW_CONFIG_PATH') or Path.home() / '.openclaw/openclaw.json')
    try:
        config = json.loads(path.read_text(encoding='utf-8'))
        token = config.get('gateway', {}).get('auth', {}).get('token')
    except (OSError, ValueError, TypeError, AttributeError):
        return ''
    return token.strip() if isinstance(token, str) and not token.startswith('${') else ''


class GatewayTransport:
    def __init__(self, state, save, url, token, *, timeout=3900, interval=3,
                 opener=urllib.request.urlopen, clock=time.monotonic, sleep=time.sleep):
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme not in ('http', 'https') or not parsed.hostname:
            raise ValueError('invalid Gateway URL')
        if parsed.scheme == 'http' and parsed.hostname not in ('127.0.0.1', 'localhost', '::1'):
            raise ValueError('unencrypted Gateway must use loopback')
        if not token.strip() or timeout <= 0 or interval <= 0:
            raise ValueError('Gateway token and positive timeouts required')
        self.state, self.save, self.url, self.token = state, save, url, token.strip()
        self.timeout, self.interval, self.opener, self.clock, self.sleep = timeout, interval, opener, clock, sleep

    def _request(self, node, request, device_id=None):
        payload = json.dumps({'node': node, 'device_id': device_id, 'request': request}, ensure_ascii=False).encode('utf-8')
        req = urllib.request.Request(self.url, data=payload, headers={
            'Authorization': 'Bearer ' + self.token, 'Content-Type': 'application/json'})
        try:
            with self.opener(req, timeout=150 if node == 'node4' else 40) as result:
                raw = result.read(4_000_001)
            if len(raw) > 4_000_000:
                raise ValueError('response too large')
            data = json.loads(raw)
            if not isinstance(data, dict) or 'result' not in data:
                raise ValueError('invalid gateway response')
            if device_id is not None and data.get('device_id') != device_id:
                raise ValueError('gateway device identity mismatch')
            return data['result']
        except (OSError, ValueError, urllib.error.URLError) as error:
            raise TransportUnresolved('Gateway request failed') from error

    def available(self):
        result = self._request('node1', {'operation': 'availability'})
        if not isinstance(result, dict):
            raise TransportUnresolved('invalid node availability')
        return result

    def _release(self, original, entry):
        if entry.get('released'):
            return
        try:
            result = self._request(original['selected_node'], {'operation': 'release',
                'job_id': original['job_id'], 'attempt_id': original['attempt_id']}, original['selected_device_id'])
        except TransportUnresolved:
            return  # Retry cleanup later; the result is durable in manager state.
        if (isinstance(result, dict) and result.get('status') == 'released' and
            all(result.get(key) == original[key] for key in ('job_id', 'attempt_id', 'selected_node', 'target_language'))):
            entry['released'] = True
            self.save(self.state)

    def release_pending(self):
        for entry in self.state.get('auftraege', {}).values():
            if (isinstance(entry, dict) and entry.get('status') in ('completed', 'rejected', 'failed')
                and isinstance(entry.get('job'), dict)):
                self._release(entry['job'], entry)

    def reject(self, job, reason):
        """Record a completed response rejected by validation, before retrying it."""
        key = job['source_sha256'] + ':' + job['target_language']
        entry = self.state.get('auftraege', {}).get(key)
        if not isinstance(entry, dict) or entry.get('status') != 'completed':
            return
        if entry.get('job', {}).get('attempt_id') != job.get('attempt_id'):
            raise TransportUnresolved('rejected attempt identity mismatch')
        entry['status'] = 'rejected'
        entry['validation_error'] = str(reason)[:500]
        self.save(self.state)

    def __call__(self, job):
        if not job.get('source_sha256') or not job.get('target_language') or not job.get('selected_device_id'):
            raise ValueError('missing source identity')
        key = job['source_sha256'] + ':' + job['target_language']
        entries = self.state.setdefault('auftraege', {})
        entry = entries.get(key)
        if isinstance(entry, dict) and entry.get('status') == 'rejected':
            self._release(entry['job'], entry)
            if not entry.get('released'):
                raise TransportUnresolved('rejected attempt release is unresolved')
            previous = entry
            original = dict(job, attempt_id=str(uuid.uuid4()))
            entry = {'job': original, 'status': 'submitted',
                     'previous_attempts': previous.get('previous_attempts', []) + [{
                         'job_id': previous['job'].get('job_id'),
                         'attempt_id': previous['job'].get('attempt_id'),
                         'selected_node': previous['job'].get('selected_node'),
                         'validation_error': previous.get('validation_error'),
                     }]}
            entries[key] = entry
            self.save(self.state)
            fresh = True
        else:
            fresh = entry is None
        if entry is None:
            original = dict(job, attempt_id=str(uuid.uuid4()))
            entry = {'job': original, 'status': 'submitted'}
            entries[key] = entry
            # If this write fails there must be no remote submission.
            self.save(self.state)
        original = entry['job']
        # The dispatcher verifies the job object after transport returns.
        job.update(original)
        if entry.get('response') is not None:
            self._release(original, entry)
            return entry['response']
        if entry.get('status') in ('failed', 'unknown'):
            raise TransportUnresolved('attempt requires reconciliation')
        status = None
        if fresh:
            try:
                status = self._request(original['selected_node'], {'operation': 'execute', 'job': original},
                                       original['selected_device_id'])
            except TransportUnresolved:
                pass  # The request may have been accepted. Query, never resend.
        deadline = self.clock() + self.timeout
        while True:
            if status is None:
                status = self._request(original['selected_node'], {'operation': 'status',
                    'job_id': original['job_id'], 'attempt_id': original['attempt_id']}, original['selected_device_id'])
            if not isinstance(status, dict):
                raise TransportUnresolved('attempt is not known by the node')
            if any(status.get(k) != original[k] for k in ('job_id', 'attempt_id', 'selected_node', 'target_language')):
                raise TransportUnresolved('status identity mismatch')
            state = status.get('status')
            if state == 'completed':
                response = status.get('response')
                if (not isinstance(response, dict) or response.get('status') != 'ok' or
                    any(response.get(k) != original[k] for k in ('job_id', 'selected_node', 'target_language')) or
                    not isinstance(response.get('code'), str) or not response['code'].strip()):
                    raise TransportUnresolved('invalid translation result')
                entry['response'] = response
                entry['status'] = 'completed'
                self.save(self.state)
                self._release(original, entry)
                return response
            if state in ('failed', 'unknown'):
                entry['status'] = state
                self.save(self.state)
                if state == 'failed':
                    self._release(original, entry)
                raise TransportUnresolved('attempt requires reconciliation')
            if state != 'running' or self.clock() >= deadline:
                raise TransportUnresolved('attempt is unresolved')
            self.sleep(self.interval)
            status = None
