import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "tt_live.py"
SPEC = importlib.util.spec_from_file_location("tt_live", MODULE_PATH)
tt_live = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = tt_live
SPEC.loader.exec_module(tt_live)


class IdentityValidationTests(unittest.TestCase):
    def test_normalizes_at_username(self):
        self.assertEqual(tt_live.normalize_username("@example_creator"), "example_creator")

    def test_rejects_path_username(self):
        with self.assertRaises(Exception):
            tt_live.normalize_username("../../tmp/owned")

    def test_rejects_malicious_scrape_identifiers(self):
        with tempfile.TemporaryDirectory() as directory:
            store = tt_live.IdentityStore(Path(directory))
            result = store.update_from_scrape({
                "sec_uid": "../../owned",
                "unique_id": "example_creator",
            })
            self.assertEqual(result, (None, False))

    def test_accepts_expected_sec_uid(self):
        self.assertEqual(tt_live.validate_sec_uid("MS4wLjAB_AAA-123"), "MS4wLjAB_AAA-123")

    def test_rejects_non_tiktok_media_url(self):
        self.assertFalse(tt_live.is_allowed_media_url("http://127.0.0.1/admin"))
        self.assertFalse(tt_live.is_allowed_media_url("file:///etc/passwd"))
        self.assertTrue(tt_live.is_allowed_media_url(
            "https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv"
        ))


class PublicUrlResolutionTests(unittest.TestCase):
    def test_cmd_url_resolves_fresh_even_when_history_has_url(self):
        stale = "https://pull-hls.tiktokcdn.com/old_ld.m3u8"
        fresh = "https://pull-hls.tiktokcdn.com/fresh_hd.m3u8"
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("MS4wLjAB_valid", False)
        state = mock.Mock()
        state.get_latest_url.return_value = stale
        args = SimpleNamespace(username="example_creator", verbose=False, quality="hd")
        scrape = {"room_id": "123"}

        with mock.patch.object(tt_live, "resolve_workspace", return_value=Path("/tmp/ws")), \
             mock.patch.object(tt_live, "resolve_identity_dir", return_value=Path("/tmp/ids")), \
             mock.patch.object(tt_live, "ensure_dirs"), \
             mock.patch.object(tt_live, "IdentityStore", return_value=identity), \
             mock.patch.object(tt_live, "StateStore", return_value=state), \
             mock.patch.object(tt_live, "fetch_user_live_page", return_value=scrape), \
             mock.patch.object(tt_live, "is_live_from_sigi", return_value=True), \
             mock.patch.object(tt_live, "extract_stream_url", return_value=(fresh, "api")), \
             mock.patch("builtins.print") as output:
            code = tt_live.cmd_url(args)

        self.assertEqual(code, 0)
        output.assert_called_once_with(fresh)
        state.get_latest_url.assert_not_called()
        state.add_url.assert_called_once_with("MS4wLjAB_valid", "123", fresh)

    def test_streamlink_720p_fallback_order(self):
        with mock.patch.object(tt_live.shutil, "which", return_value="/usr/bin/streamlink"), \
             mock.patch.object(tt_live.subprocess, "run") as run:
            run.return_value = SimpleNamespace(
                returncode=0,
                stdout="https://pull-hls.tiktokcdn.com/live_hd.m3u8\n",
            )
            tt_live.extract_via_streamlink("example_creator", "720p")
        self.assertEqual(run.call_args.args[0][-1], "hd,sd,ld,worst")

    def test_ytdlp_hd_caps_preferred_resolution_at_720p(self):
        with mock.patch.object(tt_live.shutil, "which", return_value="/usr/bin/yt-dlp"), \
             mock.patch.object(tt_live.subprocess, "run") as run:
            run.return_value = SimpleNamespace(
                returncode=0,
                stdout="https://pull-hls.tiktokcdn.com/live_hd.m3u8\n",
            )
            tt_live.extract_via_ytdlp("example_creator", "hd")
        selector = run.call_args.args[0][run.call_args.args[0].index("-f") + 1]
        self.assertTrue(selector.startswith("hls-hd/"))

    def test_hd_is_preferred_and_sd_ld_are_fallbacks(self):
        room = {"stream_url": {"hls_pull_url_map": {
            "ld": "https://pull-hls.tiktokcdn.com/live_ld.m3u8",
            "sd": "https://pull-hls.tiktokcdn.com/live_sd.m3u8",
            "hd": "https://pull-hls.tiktokcdn.com/live_hd.m3u8",
        }}}
        self.assertIn("_hd", tt_live.pick_hls(room, "hd"))
        del room["stream_url"]["hls_pull_url_map"]["hd"]
        self.assertIn("_sd", tt_live.pick_hls(room, "hd"))

    def test_streamlink_models_all_tiktok_player_levels(self):
        expected = {
            "original": "origin,uhd_60,hd_60,hd,sd,ld,best,worst",
            "1080p60": "uhd_60,hd_60,hd,sd,ld,worst",
            "720p60": "hd_60,hd,sd,ld,worst",
            "720p": "hd,sd,ld,worst",
            "540p": "sd,ld,worst",
            "360p": "ld,worst",
            "auto": "best,origin,uhd_60,hd_60,hd,sd,ld,worst",
        }
        with mock.patch.object(tt_live.shutil, "which", return_value="/usr/bin/streamlink"), \
             mock.patch.object(tt_live.subprocess, "run") as run:
            run.return_value = SimpleNamespace(
                returncode=0,
                stdout="https://pull-hls.tiktokcdn.com/live.m3u8\n",
            )
            for quality, selector in expected.items():
                tt_live.extract_via_streamlink("example_creator", quality)
                self.assertEqual(run.call_args.args[0][-1], selector)

    def test_api_models_all_tiktok_player_levels(self):
        expected = {
            "original": "origin", "1080p60": "uhd_60",
            "720p60": "hd_60", "720p": "hd",
            "540p": "sd", "360p": "ld", "auto": "origin",
        }
        room = {"stream_url": {"hls_pull_url_map": {
            key: f"https://pull-hls.tiktokcdn.com/live_{key}.m3u8"
            for key in ("origin", "uhd_60", "hd_60", "hd", "sd", "ld")
        }}}
        for quality, key in expected.items():
            self.assertIn(f"_{key}.m3u8", tt_live.pick_hls(room, quality))

    def test_url_parser_defaults_to_auto(self):
        args = tt_live.build_parser().parse_args(["url", "example_creator"])
        self.assertEqual(args.quality, "auto")


def make_room_info():
    import json as _json
    stream_data = {
        "data": {
            "origin": {"main": {
                "hls": "https://pull-hls.tiktokcdn.com/live_origin.m3u8",
                "flv": "https://pull-flv.tiktokcdn.com/live_origin.flv",
                "sdk_params": _json.dumps(
                    {"resolution": "1920x1080", "vbitrate": 4500000}
                ),
            }},
            "hd": {"main": {
                "hls": "https://pull-hls.tiktokcdn.com/live_hd.m3u8",
                "flv": "https://pull-flv.tiktokcdn.com/live_hd.flv",
                "sdk_params": _json.dumps(
                    {"resolution": "1280x720", "vbitrate": 2500000}
                ),
            }},
            "ao": {"main": {
                "hls": "https://pull-hls.tiktokcdn.com/live_ao.m3u8",
            }},
            "evil": {"main": {
                "hls": "https://attacker.example.com/live.m3u8",
            }},
        }
    }
    return {
        "title": "  Mein Stream  ",
        "user_count": 321,
        "create_time": 1783970000,
        "like_count": 999,
        "stats": {"total_user": 4567},
        "owner": {
            "nickname": "Nick 🩵",
            "follow_info": {"follower_count": 1200, "following_count": 34},
        },
        "hashtag": {"title": "Gaming"},
        "stream_url": {
            "live_core_sdk_data": {
                "pull_data": {"stream_data": _json.dumps(stream_data)}
            },
            "hls_pull_url_map": {
                "sd": "https://pull-hls.tiktokcdn.com/live_sd.m3u8",
            },
            "flv_pull_url_map": {
                "sd": "https://pull-flv.tiktokcdn.com/live_sd.flv",
            },
        },
    }


class QualityEnumerationTests(unittest.TestCase):
    def test_collect_qualities_orders_best_first_with_audio_last(self):
        qualities = tt_live.collect_qualities(make_room_info())
        self.assertEqual(list(qualities), ["origin", "hd", "sd", "ao"])
        self.assertEqual(
            qualities["ao"]["hls"],
            "https://pull-hls.tiktokcdn.com/live_ao.m3u8",
        )
        self.assertNotIn("evil", qualities)

    def test_collect_qualities_carries_hls_flv_and_metadata(self):
        qualities = tt_live.collect_qualities(make_room_info())
        origin = qualities["origin"]
        self.assertEqual(origin["label"], "original")
        self.assertEqual(origin["hls"], "https://pull-hls.tiktokcdn.com/live_origin.m3u8")
        self.assertEqual(origin["flv"], "https://pull-flv.tiktokcdn.com/live_origin.flv")
        self.assertEqual(origin["resolution"], "1920x1080")
        self.assertEqual(origin["bitrate_kbps"], 4500)
        sd = qualities["sd"]
        self.assertEqual(sd["hls"], "https://pull-hls.tiktokcdn.com/live_sd.m3u8")
        self.assertEqual(sd["flv"], "https://pull-flv.tiktokcdn.com/live_sd.flv")
        self.assertIsNone(sd["resolution"])

    def test_collect_qualities_handles_missing_and_malformed_payloads(self):
        self.assertEqual(tt_live.collect_qualities({}), {})
        self.assertEqual(tt_live.collect_qualities(None), {})
        broken = {"stream_url": {"live_core_sdk_data": {"pull_data": {
            "stream_data": "{not json"
        }}}}
        self.assertEqual(tt_live.collect_qualities(broken), {})

    def test_pick_hls_still_prefers_requested_quality(self):
        room = make_room_info()
        self.assertIn("_hd.m3u8", tt_live.pick_hls(room, "720p"))
        self.assertIn("_origin.m3u8", tt_live.pick_hls(room, "original"))

    def test_pick_hls_falls_back_to_audio_only_when_alone(self):
        room = {"stream_url": {"hls_pull_url_map": {
            "ao": "https://pull-hls.tiktokcdn.com/live_ao.m3u8",
        }}}
        self.assertIn("_ao", tt_live.pick_hls(room, "auto"))


class RoomSummaryTests(unittest.TestCase):
    def test_summary_extracts_and_trims_fields(self):
        with mock.patch.object(tt_live.time, "time", return_value=1783973600):
            summary = tt_live.collect_room_summary(make_room_info())
        self.assertEqual(summary["title"], "Mein Stream")
        self.assertEqual(summary["nickname"], "Nick 🩵")
        self.assertEqual(summary["hashtag"], "Gaming")
        self.assertEqual(summary["viewers"], 321)
        self.assertEqual(summary["total_viewers"], 4567)
        self.assertEqual(summary["likes"], 999)
        self.assertEqual(summary["follower_count"], 1200)
        self.assertEqual(summary["following_count"], 34)
        self.assertEqual(summary["start_epoch"], 1783970000)
        self.assertEqual(summary["duration_sec"], 3600)

    def test_summary_omits_missing_and_malformed_fields(self):
        summary = tt_live.collect_room_summary({
            "title": "   ",
            "user_count": "not-a-number",
            "create_time": -5,
            "hashtag": "Chat",
        })
        self.assertEqual(summary, {"hashtag": "Chat"})
        self.assertEqual(tt_live.collect_room_summary(None), {})


class CheckEnrichmentTests(unittest.TestCase):
    def _run_check(self, live, room_info):
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("MS4wLjAB_valid", False)
        state = mock.Mock()
        state.read.return_value = {}
        scrape = {
            "sec_uid": "MS4wLjAB_valid", "unique_id": "example_creator",
            "nickname": "Nick", "user_id": "1", "room_id": "123",
            "title": "t", "start_time": 1,
        }
        args = SimpleNamespace(username="example_creator")
        with mock.patch.object(tt_live, "resolve_workspace", return_value=Path("/tmp/ws")), \
             mock.patch.object(tt_live, "resolve_identity_dir", return_value=Path("/tmp/ids")), \
             mock.patch.object(tt_live, "ensure_dirs"), \
             mock.patch.object(tt_live, "IdentityStore", return_value=identity), \
             mock.patch.object(tt_live, "StateStore", return_value=state), \
             mock.patch.object(tt_live, "fetch_user_live_page", return_value=scrape), \
             mock.patch.object(tt_live, "is_live_from_sigi", return_value=live), \
             mock.patch.object(tt_live, "fetch_room_info", return_value=room_info) as fetch, \
             mock.patch("builtins.print") as output:
            code = tt_live.cmd_check(args)
        import json as _json
        return code, fetch, _json.loads(output.call_args.args[0])

    def test_check_live_includes_room_and_qualities(self):
        code, fetch, out = self._run_check(True, make_room_info())
        self.assertEqual(code, 0)
        fetch.assert_called_once_with("123")
        self.assertEqual(out["room"]["viewers"], 321)
        self.assertEqual(list(out["qualities"]), ["origin", "hd", "sd", "ao"])

    def test_check_offline_skips_room_fetch(self):
        code, fetch, out = self._run_check(False, None)
        self.assertEqual(code, 1)
        fetch.assert_not_called()
        self.assertNotIn("room", out)
        self.assertNotIn("qualities", out)

    def test_check_survives_enrichment_failure(self):
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("MS4wLjAB_valid", False)
        state = mock.Mock()
        state.read.return_value = {}
        scrape = {"sec_uid": "MS4wLjAB_valid", "unique_id": "x", "room_id": "123"}
        args = SimpleNamespace(username="example_creator")
        with mock.patch.object(tt_live, "resolve_workspace", return_value=Path("/tmp/ws")), \
             mock.patch.object(tt_live, "resolve_identity_dir", return_value=Path("/tmp/ids")), \
             mock.patch.object(tt_live, "ensure_dirs"), \
             mock.patch.object(tt_live, "IdentityStore", return_value=identity), \
             mock.patch.object(tt_live, "StateStore", return_value=state), \
             mock.patch.object(tt_live, "fetch_user_live_page", return_value=scrape), \
             mock.patch.object(tt_live, "is_live_from_sigi", return_value=True), \
             mock.patch.object(tt_live, "fetch_room_info", side_effect=RuntimeError), \
             mock.patch("builtins.print"):
            self.assertEqual(tt_live.cmd_check(args), 0)


class UrlJsonModeTests(unittest.TestCase):
    def test_url_json_emits_compact_payload_with_enrichment(self):
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("MS4wLjAB_valid", False)
        state = mock.Mock()
        scrape = {"room_id": "123", "unique_id": "example_creator"}
        room = make_room_info()
        fresh = "https://pull-hls.tiktokcdn.com/live_origin.m3u8"
        args = SimpleNamespace(
            username="example_creator", verbose=False, quality="auto", json=True,
        )
        with mock.patch.object(tt_live, "resolve_workspace", return_value=Path("/tmp/ws")), \
             mock.patch.object(tt_live, "resolve_identity_dir", return_value=Path("/tmp/ids")), \
             mock.patch.object(tt_live, "ensure_dirs"), \
             mock.patch.object(tt_live, "IdentityStore", return_value=identity), \
             mock.patch.object(tt_live, "StateStore", return_value=state), \
             mock.patch.object(tt_live, "fetch_user_live_page", return_value=scrape), \
             mock.patch.object(tt_live, "is_live_from_sigi", return_value=True), \
             mock.patch.object(tt_live, "fetch_room_info", return_value=room) as fetch, \
             mock.patch.object(tt_live, "extract_stream_url",
                               return_value=(fresh, "api")) as extract, \
             mock.patch("builtins.print") as output:
            code = tt_live.cmd_url(args)

        self.assertEqual(code, 0)
        fetch.assert_called_once_with("123")
        self.assertIs(extract.call_args.kwargs["room_info"], room)
        line = output.call_args.args[0]
        self.assertNotIn("\n", line)
        import json as _json
        payload = _json.loads(line)
        self.assertEqual(payload["status"], "live")
        self.assertEqual(payload["url"], fresh)
        self.assertEqual(payload["source"], "api")
        self.assertEqual(payload["unique_id"], "example_creator")
        self.assertEqual(list(payload["qualities"]), ["origin", "hd", "sd", "ao"])
        self.assertEqual(payload["room"]["title"], "Mein Stream")

    def test_url_without_json_prints_naked_url_and_skips_prefetch(self):
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("MS4wLjAB_valid", False)
        state = mock.Mock()
        scrape = {"room_id": "123", "unique_id": "example_creator"}
        fresh = "https://pull-hls.tiktokcdn.com/live_hd.m3u8"
        args = SimpleNamespace(
            username="example_creator", verbose=False, quality="auto", json=False,
        )
        with mock.patch.object(tt_live, "resolve_workspace", return_value=Path("/tmp/ws")), \
             mock.patch.object(tt_live, "resolve_identity_dir", return_value=Path("/tmp/ids")), \
             mock.patch.object(tt_live, "ensure_dirs"), \
             mock.patch.object(tt_live, "IdentityStore", return_value=identity), \
             mock.patch.object(tt_live, "StateStore", return_value=state), \
             mock.patch.object(tt_live, "fetch_user_live_page", return_value=scrape), \
             mock.patch.object(tt_live, "is_live_from_sigi", return_value=True), \
             mock.patch.object(tt_live, "fetch_room_info") as fetch, \
             mock.patch.object(tt_live, "extract_stream_url", return_value=(fresh, "api")), \
             mock.patch("builtins.print") as output:
            code = tt_live.cmd_url(args)
        self.assertEqual(code, 0)
        fetch.assert_not_called()
        output.assert_called_once_with(fresh)


class NicknameHistoryTests(unittest.TestCase):
    def test_nickname_change_is_recorded_and_capped(self):
        with tempfile.TemporaryDirectory() as directory:
            store = tt_live.IdentityStore(Path(directory))
            base = {"sec_uid": "MS4wLjAB_valid", "unique_id": "example_creator"}
            store.update_from_scrape({**base, "nickname": "Alpha"})
            store.update_from_scrape({**base, "nickname": "Beta"})
            store.update_from_scrape({**base, "nickname": "Beta"})
            record = store.load_identity("MS4wLjAB_valid")
            history = record.get("nickname_history")
            self.assertEqual(len(history), 1)
            self.assertEqual(history[0]["from"], "Alpha")
            self.assertEqual(history[0]["to"], "Beta")
            self.assertIn("detected_at", history[0])
            for index in range(30):
                store.update_from_scrape({**base, "nickname": f"N{index}"})
            record = store.load_identity("MS4wLjAB_valid")
            self.assertEqual(
                len(record["nickname_history"]), tt_live.NICKNAME_HISTORY_MAX
            )

    def test_unchanged_nickname_adds_no_history(self):
        with tempfile.TemporaryDirectory() as directory:
            store = tt_live.IdentityStore(Path(directory))
            base = {"sec_uid": "MS4wLjAB_valid", "unique_id": "example_creator"}
            store.update_from_scrape({**base, "nickname": "Alpha"})
            store.update_from_scrape({**base, "nickname": "Alpha"})
            record = store.load_identity("MS4wLjAB_valid")
            self.assertNotIn("nickname_history", record)


if __name__ == "__main__":
    unittest.main()
