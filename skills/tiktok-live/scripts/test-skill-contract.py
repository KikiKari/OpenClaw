#!/usr/bin/env python3
"""Regression checks for the documented /tiktok_live normal flow."""

from pathlib import Path
import unittest


SKILL = Path(__file__).resolve().parents[1] / "SKILL.md"
CANONICAL_COMMAND = (
    "python3 /home/openclaw/.openclaw/workspace/tiktok-monitor/"
    "tiktok_dispatch.py url @handle --json"
)
NODE_COMMAND = CANONICAL_COMMAND + " --execution local"


class SkillContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SKILL.read_text(encoding="utf-8")
        cls.normalized_text = " ".join(cls.text.split())

    def test_dispatcher_is_the_documented_first_action(self):
        self.assertIn("Make the existing dispatcher the first action", self.text)
        self.assertEqual(self.text.count(CANONICAL_COMMAND), 2)

    def test_auto_host_and_bounded_node_fallback(self):
        for expected in (
            "tools.exec.host=auto",
            "omit both the `host` and `node` fields",
            "retry exactly once",
            "least-loaded connected paired node",
            "host=node",
            "TIKTOK_EXECUTION_CONTEXT=node",
            NODE_COMMAND,
            "Never replace it with",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.text)
        self.assertIn(
            "`technical_error`, `dependency_missing`, or `overloaded`",
            self.normalized_text,
        )
        self.assertNotIn("host=gateway", self.text)
        self.assertIn("Never start a second node retry", self.text)
        self.assertIn("never\nchange the global exec host", self.text)
        self.assertEqual(self.text.count(CANONICAL_COMMAND), 2)

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

    def test_atomic_output_and_synchronized_audio(self):
        for expected in (
            "send them atomically",
            "Preserve a returned URL byte-for-byte",
            "pass exactly that same text to TTS",
            "Never invoke TTS before the final text is complete",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.normalized_text)


if __name__ == "__main__":
    unittest.main()
