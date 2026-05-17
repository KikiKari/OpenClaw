#!/usr/bin/env python3
from __future__ import annotations

import shlex
import sqlite3
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable

BASE = Path('/home/openclaw/.openclaw/workspace/ops-hub')
DB_PATH = BASE / 'logs.db'
ERROR_LOG = BASE / 'collection-errors.log'
COLLECTED_BY = 'ops-hub'
RETENTION_DAYS = 30
SSH_USER = 'openclaw'
SSH_PORT = 22

REMOTE_COMMANDS = [
    ("systemd_journal", "journalctl -n 500 --no-pager"),
    ("syslog_tail", "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'"),
    ("openclaw_logs", "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"),
]

LOCAL_COMMANDS = [
    ("systemd_journal", ["journalctl", "-n", "500", "--no-pager"]),
    ("syslog_tail", "tail -n 200 /var/log/syslog 2>/dev/null || echo 'no syslog'"),
    ("openclaw_logs", "tail -n 200 ~/.openclaw/logs/*.log 2>/dev/null || echo 'no openclaw logs'"),
]


@dataclass(frozen=True)
class Node:
    node_id: str
    hostname: str
    tailscale_ip: str | None = None
    wireguard_ip: str | None = None
    wan_host: str | None = None
    ssh_user: str = SSH_USER
    ssh_port: int = SSH_PORT
    enabled: bool = True


NODES = [
    Node(node_id='node1', hostname='local-gateway'),
    Node(node_id='node2', hostname='10.10.0.2', wireguard_ip='10.10.0.2'),
    Node(node_id='node3', hostname='10.10.0.3', wireguard_ip='10.10.0.3'),
]


class CollectorError(RuntimeError):
    pass


class LogCollector:
    def __init__(self) -> None:
        self.conn: sqlite3.Connection | None = None
        self.critical = False
        BASE.mkdir(parents=True, exist_ok=True)
        ERROR_LOG.touch(exist_ok=True)

    def ts(self) -> str:
        return datetime.now().isoformat(timespec='seconds')

    def log_error(self, message: str) -> None:
        with ERROR_LOG.open('a', encoding='utf-8') as fh:
            fh.write(f'[{self.ts()}] {message}\n')

    def connect_db(self) -> None:
        self.conn = sqlite3.connect(DB_PATH)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute('PRAGMA foreign_keys = ON')
        self.conn.executescript(
            '''
            CREATE TABLE IF NOT EXISTS nodes (
                node_id TEXT PRIMARY KEY,
                hostname TEXT NOT NULL,
                tailscale_ip TEXT,
                wireguard_ip TEXT,
                wan_host TEXT,
                ssh_user TEXT DEFAULT 'openclaw',
                ssh_port INTEGER DEFAULT 22,
                enabled INTEGER DEFAULT 1,
                last_collection_at TEXT,
                last_status TEXT
            );

            CREATE TABLE IF NOT EXISTS collection_runs (
                run_id INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at TEXT NOT NULL,
                finished_at TEXT,
                nodes_total INTEGER NOT NULL,
                nodes_success INTEGER DEFAULT 0,
                nodes_failed INTEGER DEFAULT 0,
                logs_collected INTEGER DEFAULT 0,
                critical_error INTEGER DEFAULT 0,
                notes TEXT
            );

            CREATE TABLE IF NOT EXISTS ssh_connections (
                connection_id INTEGER PRIMARY KEY AUTOINCREMENT