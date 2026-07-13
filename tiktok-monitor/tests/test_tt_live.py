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


if __name__ == "__main__":
    unittest.main()
