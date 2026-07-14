#!/usr/bin/env python3
"""Regression checks for /tiktok_live_mon routing and monitor actions."""

from pathlib import Path
import unittest


SKILL = Path(__file__).resolve().parents[1] / "SKILL.md"
DISPATCHER = (
    "/home/openclaw/.openclaw/workspace/tiktok-monitor/"
    "tiktok_dispatch.py url @name --quality auto --json"
)
CONTROLLER = (
    "/home/openclaw/.openclaw/workspace/tiktok-monitor/"
    "tiktok-monitorctl.sh"
)


class MonitorSkillContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SKILL.read_text(encoding="utf-8")
        cls.normalized_text = " ".join(cls.text.split())

    def test_bare_handle_uses_dispatcher_as_first_tool_call(self):
        self.assertIn(
            "dispatcher exec must be the first tool call",
            self.normalized_text,
        )
        self.assertIn(DISPATCHER, self.text)
        self.assertIn("A bare handle never starts a daemon", self.text)

    def test_slash_command_bypasses_the_model(self):
        for expected in (
            "command-dispatch: tool",
            "command-tool: tiktok_live_mon_command",
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

    def test_running_dispatcher_is_polled_without_restart(self):
        for expected in (
            "Start exactly one dispatcher exec per request",
            "do not rerun exec",
            'sessionId: "NAME"',
            "Continue polling that same name until completion",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, self.text)

    def test_monitor_actions_remain_controller_backed(self):
        for action in ("start", "status", "stop"):
            with self.subTest(action=action):
                self.assertIn(f"{CONTROLLER} {action} @name", self.text)
        self.assertIn("prevents duplicate active monitors", self.text)
        self.assertIn("Without the current word `start`", self.text)

    def test_one_shot_response_contract_covers_all_statuses(self):
        legacy = (
            "@<handle> is currently "
            "<OFFLINE|RESTRICTED|OVERLOADED|TECHNICAL_ERROR> on TikTok.\n"
            "VLC/MPV: not available\n"
            "Method: <method>"
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
            "exactly one URL and nothing else",
            "No raw URL appears in plain text",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, " ".join(self.text.split()))
        for status in (
            "live", "offline", "restricted", "overloaded",
            "dependency_missing", "technical_error",
        ):
            with self.subTest(status=status):
                self.assertIn(status, self.text)

    def test_invalid_current_input_is_not_taken_from_history(self):
        self.assertIn("Derive the action, handle, hours, and poll interval only", self.text)
        self.assertIn("Never take them from", self.text)


if __name__ == "__main__":
    unittest.main()
