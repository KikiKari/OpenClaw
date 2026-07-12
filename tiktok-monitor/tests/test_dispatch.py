import importlib.util
import os
import sys
import unittest
from argparse import Namespace
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "tiktok_dispatch.py"
SPEC = importlib.util.spec_from_file_location("tiktok_dispatch", MODULE_PATH)
dispatch = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = dispatch
SPEC.loader.exec_module(dispatch)


class DispatcherTests(unittest.TestCase):
    def test_workspace_defaults_to_dispatcher_checkout(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(
                dispatch.resolve_workspace(),
                MODULE_PATH.parent.parent,
            )

    def test_workspace_honors_explicit_override(self):
        with mock.patch.dict(
            os.environ,
            {"OPENCLAW_WORKSPACE": "/workspace"},
            clear=True,
        ):
            self.assertEqual(
                dispatch.resolve_workspace(),
                Path("/workspace").resolve(),
            )

    def test_username_normalization(self):
        self.assertEqual(dispatch.normalize_username("@example_creator"), "example_creator")
        self.assertEqual(dispatch.normalize_username(" example_creator "), "example_creator")

    def test_username_rejects_shell_input(self):
        with self.assertRaises(ValueError):
            dispatch.normalize_username("example_creator;id")

    def test_overload_classification(self):
        attempt = dispatch.classify("playwright", 75, "", '{"status":"overloaded"}', "url")
        self.assertEqual(attempt.status, "overloaded")

    def test_offline_has_no_url(self):
        attempt = dispatch.classify("playwright", 1, "", '{"status":"offline"}', "url")
        self.assertEqual(attempt.status, "offline")
        self.assertIsNone(attempt.url)

    def test_offline_url_cannot_be_promoted(self):
        attempt = dispatch.classify(
            "playwright", 1, '{"status":"offline","url":"http://127.0.0.1/admin"}', "", "url"
        )
        self.assertEqual(attempt.status, "offline")
        self.assertIsNone(attempt.url)

    def test_nonzero_live_is_technical_error(self):
        attempt = dispatch.classify("playwright", 2, '{"live":true}', "", "check")
        self.assertEqual(attempt.status, "technical_error")

    def test_browser_crash_with_exit_one_is_technical_error(self):
        attempt = dispatch.classify(
            "playwright_network_basic",
            1,
            "",
            "browserType.launch: Target page, context or browser has been closed",
            "url",
        )
        self.assertEqual(attempt.status, "technical_error")

    def test_remote_title_does_not_override_structured_live(self):
        attempt = dispatch.classify(
            "python", 0, '{"live":true,"title":"age-restricted promotion"}', "", "check"
        )
        self.assertEqual(attempt.status, "live")

    @mock.patch.object(dispatch, "connected_system_run_nodes")
    def test_selects_lowest_reported_load(self, nodes):
        nodes.return_value = [
            {"nodeId": "busy", "commands": ["system.run"], "loadPerCpu": 1.2},
            {"nodeId": "idle", "commands": ["system.run"], "loadPerCpu": 0.2},
        ]
        self.assertEqual(dispatch.select_node(), "idle")

    @mock.patch.object(dispatch, "connected_system_run_nodes")
    def test_skips_malformed_node_load(self, nodes):
        nodes.return_value = [
            {"nodeId": "bad", "commands": ["system.run"], "loadPerCpu": "not-a-number"},
            {"nodeId": "idle", "commands": ["system.run"], "loadPerCpu": 0.2},
        ]
        self.assertEqual(dispatch.select_node(), "idle")

    @mock.patch.object(dispatch, "connected_system_run_nodes")
    def test_accepts_node_without_status_load_telemetry(self, nodes):
        nodes.return_value = [
            {
                "nodeId": "node-id",
                "displayName": "xnetx",
                "commands": ["system.run"],
            }
        ]
        self.assertEqual(dispatch.select_node(), "node-id")

    @mock.patch.object(dispatch, "connected_system_run_nodes")
    def test_requested_alias_returns_canonical_node_id(self, nodes):
        nodes.return_value = [
            {
                "nodeId": "node-id",
                "displayName": "xnetx",
                "commands": ["system.run"],
            }
        ]
        self.assertEqual(dispatch.select_node("xnetx"), "node-id")

    @mock.patch.object(dispatch, "run_json_command")
    def test_node_status_uses_dedicated_timeout(self, run_json):
        run_json.return_value = {"nodes": []}
        self.assertEqual(dispatch.connected_system_run_nodes(), [])
        run_json.assert_called_once_with(
            ["openclaw", "nodes", "status", "--connected", "--json"],
            timeout=dispatch.NODE_STATUS_TIMEOUT_SECONDS,
        )

    def test_timeout_bounds(self):
        self.assertEqual(dispatch.positive_bounded_timeout("45"), 45)
        with self.assertRaises(Exception):
            dispatch.positive_bounded_timeout("0")
        with self.assertRaises(Exception):
            dispatch.positive_bounded_timeout("121")

    def test_forced_load_value(self):
        with mock.patch.dict(os.environ, {"TIKTOK_TEST_LOAD_PER_CPU": "2.0",
                                          "TIKTOK_MAX_LOAD_PER_CPU": "1.5"}):
            self.assertEqual(dispatch.load_state(), (2.0, 1.5))

    def test_concurrency_state_override(self):
        with mock.patch.dict(
            os.environ,
            {"TIKTOK_TEST_ACTIVE_DISPATCHES": "2", "TIKTOK_MAX_CONCURRENT": "1"},
        ):
            self.assertEqual(dispatch.concurrency_state(), (2, 1))

    @mock.patch.object(dispatch, "emit_log")
    def test_concurrent_request_returns_overloaded(self, _emit_log):
        args = Namespace(json=True)
        with mock.patch.object(dispatch, "concurrency_state", return_value=(2, 1)):
            with mock.patch("builtins.print") as output:
                code = dispatch.dispatch(args)
        self.assertEqual(code, 75)
        payload = __import__("json").loads(output.call_args.args[0])
        self.assertEqual(payload["status"], "overloaded")
        self.assertEqual(payload["method"], "concurrency_preflight")

    @mock.patch.object(dispatch, "emit_log")
    @mock.patch.object(dispatch, "run_command")
    @mock.patch.object(dispatch, "commands")
    def test_restricted_web_check_overrides_tentative_python_live(
        self, command_list, run_command, _emit_log
    ):
        command_list.return_value = [
            ("python_webcast", ["python-webcast"]),
            ("playwright_enhanced", ["playwright-enhanced"]),
        ]
        run_command.side_effect = [
            (0, '{"live":true}', ""),
            (1, '{"status":"restricted","isLive":true}', ""),
        ]
        args = Namespace(
            operation="check",
            username="example_creator",
            quality="ld",
            retries=0,
            timeout=45,
        )
        payload, code = dispatch.dispatch_local(args)
        self.assertEqual(code, 1)
        self.assertEqual(payload["status"], "restricted")
        self.assertEqual(payload["method"], "playwright_enhanced")


if __name__ == "__main__":
    unittest.main()
