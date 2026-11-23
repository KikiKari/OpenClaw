import ast
import importlib.util
import json
import os
import subprocess
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest.mock import patch

TEMP = tempfile.TemporaryDirectory()
os.environ['ABSTRACTIONS_WORKSPACE'] = TEMP.name
SCRIPT = Path('/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py')
spec = importlib.util.spec_from_file_location('storage_manager', SCRIPT)
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)


class StorageReserveTests(unittest.TestCase):
    def test_thresholds_and_unknown(self):
        limit = 4 * 1024**3
        for free, expected in [(limit - 1, False), (limit, True), (limit + 1, True), (None, False), (True, False)]:
            with self.subTest(free=free):
                self.assertEqual(manager.node_hat_reserve('node3', 'id', {'id': free}), expected)
        for free, expected in [(40 * 1024**3 - 1, False), (40 * 1024**3, True)]:
            with patch.object(manager.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=free)):
                self.assertEqual(manager.node_hat_reserve('node1', 'gateway-local', {}), expected)

    def test_status_identity_freshness_and_failure(self):
        now = int(time.time() * 1000)
        payload = {'ts': now, 'nodes': [
            {'nodeId': 'fresh', 'connected': True, 'hostStats': {'diskAvailableBytes': 4 * 1024**3, 'updatedAtMs': now}},
            {'nodeId': 'stale', 'connected': True, 'hostStats': {'diskAvailableBytes': 4 * 1024**3, 'updatedAtMs': now - 300001}},
            {'nodeId': 'offline', 'connected': False, 'hostStats': {'diskAvailableBytes': 4 * 1024**3, 'updatedAtMs': now}},
            {'nodeId': 'unknown', 'connected': True},
        ]}
        with patch.object(manager.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, json.dumps(payload), '')):
            self.assertEqual(manager.node_speicherstatus(), {'fresh': 4 * 1024**3})
        with patch.object(manager.subprocess, 'run', side_effect=OSError()):
            self.assertEqual(manager.node_speicherstatus(), {})

    def test_dispatcher_preserves_priority_and_falls_back(self):
        tree = ast.parse(SCRIPT.read_text())
        node = next(n for n in ast.walk(tree) if isinstance(n, ast.ClassDef) and n.name == 'GatewayDispatcher')
        manager.module = types.SimpleNamespace(JobDispatcher=object)
        manager.transport = types.SimpleNamespace(available=lambda: {
            **{f'node{i}': True for i in range(1, 7)},
            'node_ids': {'node1': 'local', 'node2': 'a', 'node3': 'b', 'node4': 'c', 'node5': 'd', 'node6': 'e'},
        })
        exec(compile(ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[])), str(SCRIPT), 'exec'), manager.__dict__)
        free = {'a': 4 * 1024**3 - 1, 'b': 4 * 1024**3, 'c': 4 * 1024**3, 'e': 4 * 1024**3}
        with patch.object(manager, 'node_speicherstatus', return_value=free):
            with patch.object(manager.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=40 * 1024**3)):
                self.assertEqual(manager.GatewayDispatcher().select_node('light'), 'node1')
            with patch.object(manager.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=40 * 1024**3 - 1)):
                self.assertEqual(manager.GatewayDispatcher().select_node('light'), 'node3')
                self.assertEqual(manager.GatewayDispatcher().select_node('heavy'), 'node6')


if __name__ == '__main__':
    unittest.main()
