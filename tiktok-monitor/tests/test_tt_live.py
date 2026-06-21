import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


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


if __name__ == "__main__":
    unittest.main()
