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


class StreamQualityTests(unittest.TestCase):
    def room_info(self, qualities):
        return {
            "stream_url": {
                "hls_pull_url_map": {
                    quality: f"https://media.example/stream_{quality}.m3u8"
                    for quality in qualities
                }
            }
        }

    def test_api_prefers_hd_over_ld_sd_and_origin(self):
        url = core.pick_hd_hls(self.room_info(["ld", "sd", "origin", "hd"]))
        self.assertEqual(url, "https://media.example/stream_hd.m3u8")

    def test_api_uses_hd_60_when_plain_hd_is_missing(self):
        url = core.pick_hd_hls(self.room_info(["ld", "hd_60", "origin"]))
        self.assertEqual(url, "https://media.example/stream_hd_60.m3u8")

    def test_api_keeps_ld_as_last_video_fallback(self):
        url = core.pick_hd_hls(self.room_info(["ao", "ld"]))
        self.assertEqual(url, "https://media.example/stream_ld.m3u8")

    def test_streamlink_requests_hd_before_lower_fallbacks(self):
        completed = mock.Mock(returncode=0, stdout="https://media.example/stream_hd.flv\n")
        with mock.patch.object(core.shutil, "which", return_value="/usr/bin/streamlink"), \
             mock.patch.object(core.subprocess, "run", return_value=completed) as run:
            url = core.extract_via_streamlink("example")
        self.assertEqual(url, "https://media.example/stream_hd.flv")
        self.assertEqual(run.call_args.args[0][-1], "720p,best,480p,360p,worst")

    def test_ytdlp_caps_preferred_quality_at_720p(self):
        completed = mock.Mock(returncode=0, stdout="https://media.example/stream_hd.m3u8\n")
        with mock.patch.object(core.shutil, "which", return_value="/usr/bin/yt-dlp"), \
             mock.patch.object(core.subprocess, "run", return_value=completed) as run:
            url = core.extract_via_ytdlp("example")
        self.assertEqual(url, "https://media.example/stream_hd.m3u8")
        self.assertIn("best[height<=720]/best", run.call_args.args[0])


class FreshQuerySessionTests(unittest.TestCase):
    def test_cmd_url_never_short_circuits_from_cached_url(self):
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("stable_sec_uid", False)
        state = mock.Mock()
        state.get_latest_url.return_value = "https://media.example/old_hd.flv"
        args = mock.Mock(username="example", verbose=False)
        scrape = {"room_id": "123", "unique_id": "example"}

        with mock.patch.object(core, "resolve_workspace", return_value=Path("/tmp/fresh-query")), \
             mock.patch.object(core, "ensure_dirs"), \
             mock.patch.object(core, "IdentityStore", return_value=identity), \
             mock.patch.object(core, "StateStore", return_value=state), \
             mock.patch.object(core, "fetch_user_live_page", return_value=scrape), \
             mock.patch.object(core, "is_live_from_sigi", return_value=True), \
             mock.patch.object(core, "extract_stream_url", return_value=("https://media.example/new_hd.flv", "api")) as extract, \
             mock.patch("builtins.print") as output:
            code = core.cmd_url(args)

        self.assertEqual(code, 0)
        extract.assert_called_once_with("123", "example")
        state.get_latest_url.assert_not_called()
        output.assert_called_once_with("https://media.example/new_hd.flv")


class DispatcherTests(unittest.TestCase):
    def args(self, operation="url"):
        return mock.Mock(operation=operation, handle="example", timeout=5, quality="hd", json=True)

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
        self.assertEqual(code, 0)
        fallback.assert_called_once()

    def test_python_error_and_node_offline_reports_uncertainty(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("technical_error", "python_api", 2)), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("offline", "all_node_fallbacks", 1)), \
             mock.patch("builtins.print") as output:
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, dispatcher.EXIT_TECHNICAL)
        payload = json.loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "technical_error")
        self.assertEqual(payload["method"], "source_disagreement")

    def test_node_offline_requires_all_available_playwright_sources(self):
        with mock.patch.object(dispatcher, "run_bounded", side_effect=[
            (1, '{"isLive": false}', ""),
            (2, "", "browser failed"),
        ]):
            result = dispatcher.node_fallback("url", "example", "ld", 5)
        self.assertEqual(result.status, "technical_error")
        self.assertEqual(result.method, "all_available_methods")

    def test_node_offline_when_all_available_playwright_sources_agree(self):
        with mock.patch.object(dispatcher, "run_bounded", side_effect=[
            (1, '{"isLive": false}', "user is offline"),
            (1, '{"isLive": false}', "user is offline"),
        ]):
            result = dispatcher.node_fallback("url", "example", "ld", 5)
        self.assertEqual(result.status, "offline")
        self.assertEqual(result.method, "all_node_fallbacks")

    def test_python_offline_is_provisional_and_runs_node(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("offline", "python_webcast", 1)), \
             mock.patch.object(dispatcher, "direct_media_fallback", return_value=dispatcher.Result("technical_error", "direct_media_fallbacks", 2)), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("offline", "playwright_enhanced", 1)) as fallback, \
             mock.patch.object(dispatcher.time, "sleep"), \
             mock.patch.object(dispatcher, "identity_sync"), \
             mock.patch("builtins.print"):
            code = dispatcher.dispatch(self.args("check"))
        self.assertEqual(code, 0)
        fallback.assert_called_once()

    def test_delayed_python_recheck_overrides_stale_offline(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", side_effect=[
                 dispatcher.Result("offline", "python_webcast", 1),
                 dispatcher.Result("live", "python_streamlink", 0, "https://x/live.flv"),
             ]), \
             mock.patch.object(dispatcher, "direct_media_fallback", return_value=dispatcher.Result("technical_error", "direct_media_fallbacks", 2)), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("offline", "playwright_network_basic", 1)), \
             mock.patch.object(dispatcher.time, "sleep") as sleep, \
             mock.patch.object(dispatcher, "identity_sync"), \
             mock.patch("builtins.print") as output:
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, 0)
        sleep.assert_called_once_with(dispatcher.OFFLINE_RECHECK_DELAY_SECONDS)
        payload = json.loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "live")
        self.assertEqual(payload["method"], "python_streamlink")

    def test_delayed_direct_media_recheck_overrides_stale_offline(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("offline", "python_api", 1)), \
             mock.patch.object(dispatcher, "direct_media_fallback", side_effect=[
                 dispatcher.Result("technical_error", "direct_media_fallbacks", 2),
                 dispatcher.Result("live", "direct_streamlink", 0, "https://x/live.flv"),
             ]), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("offline", "playwright_network_basic", 1)), \
             mock.patch.object(dispatcher.time, "sleep"), \
             mock.patch.object(dispatcher, "identity_sync"), \
             mock.patch("builtins.print") as output:
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, 0)
        payload = json.loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "live")
        self.assertEqual(payload["method"], "direct_streamlink")

    def test_inconclusive_delayed_recheck_does_not_publish_offline(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", side_effect=[
                 dispatcher.Result("offline", "python_api", 1),
                 dispatcher.Result("technical_error", "python_api", 2),
             ]), \
             mock.patch.object(dispatcher, "direct_media_fallback", return_value=dispatcher.Result("technical_error", "direct_media_fallbacks", 2)), \
             mock.patch.object(dispatcher, "node_fallback", return_value=dispatcher.Result("offline", "all_node_fallbacks", 1)), \
             mock.patch.object(dispatcher.time, "sleep"), \
             mock.patch("builtins.print") as output:
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, dispatcher.EXIT_TECHNICAL)
        payload = json.loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "technical_error")
        self.assertEqual(payload["method"], "offline_recheck_inconclusive")

    def test_direct_media_overrides_lagging_profile_offline(self):
        with mock.patch.object(dispatcher, "acquire_dispatch_slot", return_value=mock.mock_open()()), \
             mock.patch.object(dispatcher.fcntl, "flock"), \
             mock.patch.object(dispatcher, "python_first", return_value=dispatcher.Result("offline", "python_api", 1)), \
             mock.patch.object(dispatcher, "direct_media_fallback", return_value=dispatcher.Result("live", "direct_streamlink", 0, "https://x/live.flv")), \
             mock.patch.object(dispatcher, "node_fallback") as node_fallback, \
             mock.patch.object(dispatcher, "identity_sync"), \
             mock.patch("builtins.print") as output:
            code = dispatcher.dispatch(self.args())
        self.assertEqual(code, 0)
        node_fallback.assert_not_called()
        payload = json.loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "live")
        self.assertEqual(payload["method"], "direct_streamlink")

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

    def test_second_dispatcher_on_same_host_gets_no_slot(self):
        with tempfile.TemporaryDirectory() as lock_dir, mock.patch.dict(
            os.environ,
            {"TIKTOK_DISPATCH_LOCK_DIR": lock_dir, "TIKTOK_DISPATCH_MAX_ACTIVE": "1"},
            clear=False,
        ):
            first = dispatcher.acquire_dispatch_slot()
            try:
                self.assertIsNotNone(first)
                self.assertIsNone(dispatcher.acquire_dispatch_slot())
            finally:
                dispatcher.fcntl.flock(first.fileno(), dispatcher.fcntl.LOCK_UN)
                first.close()


if __name__ == "__main__":
    unittest.main()
