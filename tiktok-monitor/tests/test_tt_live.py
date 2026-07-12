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
        stale = "https://pull-hls.tiktokcdn.com/old.m3u8"
        fresh = "https://pull-hls.tiktokcdn.com/fresh.m3u8"
        identity = mock.Mock()
        identity.update_from_scrape.return_value = ("MS4wLjAB_valid", False)
        state = mock.Mock()
        state.get_latest_url.return_value = stale
        args = SimpleNamespace(username="example_creator", verbose=False)
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


if __name__ == "__main__":
    unittest.main()
