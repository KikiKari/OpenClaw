from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


core = load("tt_live_test", ROOT / "tt_live.py")
dispatcher = load("tiktok_dispatch_test", ROOT / "tiktok_dispatch.py")


class IdentityStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.env = mock.patch.dict(
            os.environ,
            {"TT_LIVE_WORKSPACE": self.temp.name},
            clear=False,
        )
        self.env.start()
        self.workspace = Path(self.temp.name)
        core.ensure_dirs(self.workspace)
        self.store = core.IdentityStore(self.workspace)

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def scrape(self, handle="Example", nickname="Name", user_id="123"):
        return {
            "sec_uid": "stable_sec_uid",
            "unique_id": handle,
            "nickname": nickname,
            "user_id": user_id,
        }

    def test_upsert_is_normalized_and_preserves_first_seen(self):
        self.store.update_from_scrape(self.scrape())
        first = self.store.load_identity("stable_sec_uid")
        self.store.update_from_scrape(self.scrape(handle="example"))
        second = self.store.load_identity("stable_sec_uid")
        self.assertEqual(first["first_seen"], second["first_seen"])
        self.assertEqual(second["unique_id_current"], "example")
        self.assertEqual(len(list(self.store.ident_dir.glob("*.json"))), 1)
        self.assertEqual(len(list(self.store.ptr_dir.glob("*.json"))), 1)

    def test_sparse_fields_do_not_erase_values(self):
        self.store.update_from_scrape(self.scrape())
        self.store.update_from_scrape(self.scrape(nickname=None, user_id=None))
        value = self.store.load_identity("stable_sec_uid")
        self.assertEqual(value["nickname"], "Name")
        self.assertEqual(value["user_id"], "123")

    def test_rename_history_is_not_duplicated(self):
        self.store.update_from_scrape(self.scrape(handle="old"))
        self.store.update_from_scrape(self.scrape(handle="new"))
        identity = self.store.load_identity("stable_sec_uid")
        duplicate = dict(identity)
        duplicate["unique_id_current"] = "old"
        core.atomic_json_write(self.store._ident_path("stable_sec_uid"), duplicate)
        self.store.update_from_scrape(self.scrape(handle="new"))
        history = self.store.load_identity("stable_sec_uid")["rename_history"]
        self.assertEqual([(x["from"], x["to"]) for x in history], [("old", "new")])

    def test_passive_90_day_cleanup(self):
        stale = self.store.ident_dir / "stale.json"
        core.atomic_json_write(stale, {"sec_uid": "stale", "last_seen": "2020-01-01T00:00:00Z"})
        pointer = self.store.ptr_dir / "stale.json"
        core.atomic_json_write(pointer, {"unique_id": "stale", "last_pointed_at": "2020-01-01T00:00:00Z"})
        self.store.update_from_scrape(self.scrape())
        self.assertFalse(stale.exists())
        self.assertFalse(pointer.exists())


class DispatcherTests(unittest.TestCase):
    def args(self, operation="url"):
        return mock.Mock(operation=operation, handle="example", timeout=5, quality="ld", json=True)

    def test_terminal_python_url_does_not_run_node(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("live", "python_api", 0, "https://x/live.m3u8")), \
             mock.patch.object(dispatcher, "node_fallback") as fallback:
            with mock.patch("builtins.print"):
                code = dispatcher.dispatch(self.args())
        self.assertEqual(code, 0)
        fallback.assert_not_called()

    def test_python_error_runs_one_internal_fallback(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("technical_error", "python_api", 2)), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("restricted", "playwright_enhanced", 1)) as fallback, \
             mock.patch.object(dispatcher, "identity_sync"), \
             mock.patch("builtins.print"):
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, 1)
        fallback.assert_called_once()

    def test_python_offline_is_provisional_and_runs_node(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("offline", "python_webcast", 1)), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("offline", "playwright_enhanced", 1)) as fallback, \
             mock.patch.object(dispatcher, "identity_sync"), \
             mock.patch("builtins.print"):
            code = dispatcher.dispatch(self.args("check"))
        self.assertEqual(code, 1)
        fallback.assert_called_once()

    def test_overloaded_preflight_is_immediate_and_runs_no_resolver(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=None), \
             mock.patch.object(dispatcher, "python_first") as python_first, \
             mock.patch("builtins.print") as output:
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, dispatcher.EXIT_OVERLOADED)
        python_first.assert_not_called()
        payload = json.loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "overloaded")
        self.assertEqual(payload["method"], "concurrency_preflight")

    def test_default_dispatcher_capacity_is_one(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(dispatcher.max_active_dispatchers(), 1)


if __name__ == "__main__":
    unittest.main()
