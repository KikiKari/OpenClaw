#!/usr/bin/env python3
"""Regression checks for the documented /tiktok_live normal flow."""

from pathlib import Path
import unittest


SKILL = Path(__file__).resolve().parents[1] / "SKILL.md"
CANONICAL_COMMAND = (
    "/home/openclaw/.openclaw/workspace/tiktok-monitor/"
    "tiktok_dispatch.py url @handle --quality auto --json"
)
NODE_COMMAND = CANONICAL_COMMAND


class SkillContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SKILL.read_text(encoding="utf-8")
        cls.normalized_text = " ".join(cls.text.split())

    def test_dispatcher_is_the_documented_first_action(self):
        self.assertIn("Make the existing dispatcher the first action", self.text)
        self.assertIn("first tool call of the request", self.normalized_text)
        self.assertEqual(self.text.count(CANONICAL_COMMAND), 2)

    def test_slash_command_bypasses_the_model(self):
        for expected in (
            "command-dispatch: tool",
            "command-tool: tiktok_live_command",
            "command-arg-mode: raw",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.text)

    def test_no_preliminary_playwright_or_dependency_probe(self):
        for expected in (
            "Before this dispatcher call, do not invoke or inspect",
            "`tiktok-check-profile.js`",
            "Do not attempt to install or repair browser dependencies",
            "failed preliminary tool call",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.normalized_text)

    def test_direct_exec_without_shell_wrapper(self):
        for expected in (
            "Invoke that executable directly as the exec command",
            "Do not invoke `bash`",
            "`bash -lc`",
            "wrapper must not be attempted in the first place",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.normalized_text)

    def test_success_json_wins_over_trailing_diagnostics(self):
        for expected in (
            "display the final stdout JSON before trailing stderr diagnostics",
            "regardless of its visual position",
            "the tool execution succeeded",
            "Never replace such a result with a generic tool-failure message",
            "`node_available`",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.normalized_text)

    def test_auto_host_and_bounded_node_fallback(self):
        for expected in (
            "tools.exec.host=auto",
            "omit both the `host` and `node` fields",
            "retry exactly once",
            "least-loaded connected paired node",
            "host=node",
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
        self.assertIn("runtime block occurs before the Node allowlist", self.text)
        self.assertEqual(self.text.count(CANONICAL_COMMAND), 2)

    def test_public_contract_covers_legacy_and_rich_formats(self):
        legacy = (
            "@<handle> is currently "
            "<OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\n"
            "VLC/MPV: not available\n"
            "Method: <validated method>"
        )
        self.assertIn(legacy, self.text)
        self.assertIn(
            "@<handle> is currently LIVE on TikTok.\nTitel: <room.title>",
            self.text,
        )
        for expected in (
            "Stream-URLs:",
            "<label> (HLS):",
            "<label> (FLV):",
            "Live seit: <HH:MM UTC> (<Xh Ym>)",
            "exactly one URL and nothing else",
            "degrades to the legacy three lines including the `VLC/MPV:` URL",
            "No raw URL appears in plain text",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.normalized_text)

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
            "send it atomically",
            "Preserve every returned URL byte-for-byte",
            "channel voice output set to `always`",
            "Do not invoke the `tts` tool",
            "do not emit `[[tts:text]]` wrappers",
            "visible text remains the authoritative source",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.normalized_text)


if __name__ == "__main__":
    unittest.main()
