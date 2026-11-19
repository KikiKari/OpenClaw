#!/usr/bin/env python3
"""Restricted, idempotent entry point for a GitHub Actions manager run."""
import hashlib
import hmac
import json
import os
import re
import sqlite3
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WRAPPER = '/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh'
PRIORITIES = {'reihum', 'high', 'medium', 'low', 'alle'}


class Jobs:
    def __init__(self, path, runner=subprocess.run):
        self.path, self.runner, self.lock = str(path), runner, threading.Lock()
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS jobs (run_id TEXT PRIMARY KEY, params TEXT NOT NULL, status TEXT NOT NULL, exit_code INTEGER)')
            db.execute("UPDATE jobs SET status='unknown' WHERE status IN ('accepted','running')")

    def connect(self):
        return sqlite3.connect(self.path, timeout=30)

    def status(self, run_id):
        with self.connect() as db:
            row = db.execute('SELECT status, exit_code FROM jobs WHERE run_id=?', (run_id,)).fetchone()
        return None if row is None else {'run_id': run_id, 'status': row[0], 'exit_code': row[1]}

    def submit(self, run_id, priority, count):
        if not re.fullmatch(r'[0-9]{1,24}', run_id) or priority not in PRIORITIES or type(count) is not int or not 1 <= count <= 40:
            raise ValueError('invalid request')
        params = json.dumps([priority, count])
        with self.lock, self.connect() as db:
            row = db.execute('SELECT params FROM jobs WHERE run_id=?', (run_id,)).fetchone()
            if row:
                if row[0] != params:
                    raise ValueError('run conflict')
                return self.status(run_id)
            db.execute('INSERT INTO jobs VALUES (?, ?, ?, NULL)', (run_id, params, 'accepted'))
        threading.Thread(target=self.run, args=(run_id, priority, count), daemon=True).start()
        return self.status(run_id)

    def run(self, run_id, priority, count):
        with self.connect() as db:
            db.execute("UPDATE jobs SET status='running' WHERE run_id=?", (run_id,))
        cmd = [WRAPPER, '--anzahl', str(count)]
        if priority != 'reihum':
            cmd += ['--prioritaet', priority]
        try:
            result = self.runner(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, timeout=19500, check=False)
            code = result.returncode
            status = 'completed' if code == 0 else 'failed'
        except (OSError, subprocess.TimeoutExpired):
            code, status = None, 'unknown'
        with self.connect() as db:
            db.execute('UPDATE jobs SET status=?, exit_code=? WHERE run_id=?', (status, code, run_id))


def handler(jobs, token):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, code, value):
            body = json.dumps(value).encode()
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def authorized(self):
            supplied = self.headers.get('Authorization', '')
            return hmac.compare_digest(supplied, 'Bearer ' + token)

        def do_POST(self):
            if not self.authorized(): return self.reply(403, {'error': 'forbidden'})
            if self.path != '/runs': return self.reply(404, {'error': 'not found'})
            try:
                n = int(self.headers.get('Content-Length', '-1'))
                if not 0 < n <= 4096: raise ValueError('size')
                body = json.loads(self.rfile.read(n))
                if set(body) != {'run_id', 'priority', 'count'}: raise ValueError('fields')
                return self.reply(202, jobs.submit(body['run_id'], body['priority'], body['count']))
            except (ValueError, TypeError, json.JSONDecodeError):
                return self.reply(400, {'error': 'invalid request'})

        def do_GET(self):
            if not self.authorized(): return self.reply(403, {'error': 'forbidden'})
            match = re.fullmatch(r'/runs/([0-9]{1,24})', self.path)
            if not match: return self.reply(404, {'error': 'not found'})
            result = jobs.status(match.group(1))
            return self.reply(200 if result else 404, result or {'error': 'not found'})
    return Handler


def main():
    token = os.environ.get('GATEWAY_ACTIONS_TOKEN', '')
    if len(token) < 32: raise SystemExit('GATEWAY_ACTIONS_TOKEN missing or too short')
    directory = Path.home() / '.openclaw/state/actions-manager'
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.umask(0o077)
    jobs = Jobs(directory / 'runs.sqlite3')
    ThreadingHTTPServer(('127.0.0.1', 18818), handler(jobs, token)).serve_forever()


if __name__ == '__main__':
    main()
