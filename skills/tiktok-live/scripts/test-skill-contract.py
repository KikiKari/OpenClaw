#!/usr/bin/env python3
"""Regression checks for the documented /tiktok_live normal flow."""

from pathlib import Path
import unittest


SKILL = Path(__file__).resolve().parents[1] / "SKILL.md"
CANONICAL_COMMAND = (
    "python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/"
    "tiktok_dispatch.py url @handle --json"
)


class SkillContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SKILL.read_text(encoding="utf-8")

    def test_dispatcher_is_the_documented_first_action(self):
        self.assertIn("Make the existing dispatcher the first action", self.text)
        self.assertEqual(self.text.count(CANONICAL_COMMAND), 1)

    def test_public_contract_is_exactly_three_template_lines(self):
        expected = (
            "@<handle> is currently "
            "<LIVE|OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\n"
            "VLC/MPV: <validated URL or not available>\n"
            "Method: <validated method>"
        )
        self.assertIn(expected, self.text)

    def test_existing_capabilities_are_preserved(self):
        for capability in (
            "Node", "browser", "file", "directory", "configuration",
            "dependency", "diagnostic tools remain available",
        ):
            with self.subTest(capability=capability):
                self.assertIn(capability, self.text)

    def test_no_response_flag_is_documented(self):
        self.assertNotIn("--response", self.text)


if __name__ == "__main__":
    unittest.main()
