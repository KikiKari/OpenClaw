#!/usr/bin/env python3
# test_background_runtime.cjs — portiert nach python
# Quelle: javascript, Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import unittest
import os
import sys
import json
import time
import uuid
from datetime import datetime
from copy import deepcopy
from unittest.mock import patch, MagicMock, AsyncMock
import asyncio
import hashlib

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../browser-extension'))

try:
    import content_core as core
    import export_privacy as exportPrivacy
except ImportError:
    print("Warning: content_core or export_privacy modules not found")
    core = None
    exportPrivacy = None

def structured_clone(obj):
    return deepcopy(obj)

class TestBackgroundRuntime(unittest.TestCase):
    
    def setUp(self):
        self.extension_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../browser-extension'))
        
    def test_0PE_170_startup_retry_backs_off_caps_at_three_attempts_and_ignores_stale_documents(self):
        state = core.new_embed_session("test", "creator", 1000)
        
        def observe(now, status, document_id="a", document_started_at_ms=1000):
            nonlocal state
            result = core.advance_embed_session(state, {"status": status, "documentId": document_id, "documentStartedAtMs": document_started_at_ms}, now)
            state = result["session"]
            return result["action"]
            
        self.assertEqual(observe(2000, "server-error"), "none")
        self.assertEqual(state["nextAttemptAtMs"], 4000)
        self.assertEqual(observe(3999, "server-error"), "none")
        self.assertEqual(observe(4000, "server-error"), "reload")
        self.assertEqual(state["attempt"], 2)
        self.assertEqual(observe(5000, "playing"), "none")
        self.assertEqual(state["phase"], "loading")
        observe(6000, "unavailable", "b", 4500)
        self.assertEqual(state["nextAttemptAtMs"], 10000)
        self.assertEqual(observe(10000, "unavailable", "b", 4500), "reload")
        observe(11000, "server-error", "c", 10500)
        self.assertEqual(state["phase"], "failed")
        self.assertEqual(state["attempt"], 3)
        self.assertEqual(observe(100000, "server-error", "c", 10500), "none")

    def test_0PE_170_playback_before_retry_cancels_it_while_login_ended_gesture_never_reload(self):
        def observation(status):
            return {"status": status, "documentId": "a", "documentStartedAtMs": 1000}
            
        initial = core.new_embed_session("test", "creator", 1000)
        waiting = core.advance_embed_session(initial, observation("server-error"), 2000)["session"]
        recovered = core.advance_embed_session(waiting, observation("playing"), 3000)
        self.assertEqual(recovered["session"]["phase"], "playing")
        self.assertIsNone(recovered["session"]["nextAttemptAtMs"])
        
        for status in ["login-required", "ended", "awaiting-gesture"]:
            result = core.advance_embed_session(waiting, observation(status), 6000)
            self.assertEqual(result["action"], "none")
            self.assertIsNone(result["session"]["nextAttemptAtMs"])
            
        result = core.advance_embed_session({"phase": "cancelled", **initial}, observation("server-error"), 100000)
        self.assertEqual(result["action"], "none")
        self.assertEqual(core.classify_embed_observation({"text": "Server error"}), "server-error")
        self.assertEqual(core.classify_embed_observation({"text": "LIVE is unavailable"}), "unavailable")
        self.assertEqual(core.classify_embed_observation({"text": "Melde dich an für das vollständige Erlebnis"}), "login-required")
        self.assertEqual(core.classify_embed_observation({"playing": True, "readyState": 4}), "playing")
        self.assertEqual(core.classify_embed_observation({"paused": True, "readyState": 4}), "awaiting-gesture")

    def worker(self, seed=None):
        if seed is None:
            seed = {}
            
        clock = {"now": seed.get("now", int(time.time() * 1000))}
        
        session = structured_clone(seed.get("session", {}))
        local = structured_clone(seed.get("local", {}))
        sent = []
        broadcasts = []
        
        browser_tabs = {}
        if "tabs" in seed:
            for tab in seed["tabs"]:
                browser_tabs[tab["id"]] = structured_clone(tab)
                
        tab_actions = []
        next_tab_id = 100
        
        listeners = {}
        alarms = {}
        
        def event(name):
            def add_listener(fn):
                listeners[name] = fn
            return type('Event', (), {'addListener': add_listener})()
            
        def storage(data):
            async def get(key=None):
                if key is None:
                    return structured_clone(data)
                return structured_clone({key: data.get(key)})
                
            async def set_(patch):
                data.update(structured_clone(patch))
                
            async def remove(key):
                data.pop(key, None)
                
            return type('Storage', (), {'get': get, 'set': set_, 'remove': remove})()
            
        class MockChrome:
            def __init__(self):
                self.alarms = type('Alarms', (), {
                    'onAlarm': event('alarm'),
                    'create': AsyncMock(side_effect=lambda name, info: alarms.update({name: structured_clone(info)})),
                    'clear': AsyncMock(side_effect=lambda name: alarms.pop(name, None))
                })()
                
                self.storage = type('StorageArea', (), {
                    'session': storage(session),
                    'local': storage(local)
                })()
                
                self.sidePanel = type('SidePanel', (), {
                    'setPanelBehavior': AsyncMock(),
                    'setOptions': AsyncMock()
                })()
                
                self.runtime = type('Runtime', (), {
                    'onInstalled': event('installed'),
                    'onStartup': event('startup'),
                    'onMessage': event('message'),
                    'getManifest': lambda: {'version': '0.8.2'},
                    'getURL': lambda name: f'chrome-extension://test/{name}',
                    'sendMessage': AsyncMock(side_effect=lambda message: broadcasts.append(structured_clone(message)))
                })()
                
                self.tabs = type('Tabs', (), {
                    'onUpdated': event('updated'),
                    'onRemoved': event('removed'),
                    'get': AsyncMock(side_effect=lambda id_: browser_tabs.get(id_) or (lambda: exec('raise Exception("Tab not found")') or None)),
                    'create': AsyncMock(side_effect=lambda options: self._create_tab(options)),
                    'update': AsyncMock(side_effect=lambda id_, options: self._update_tab(id_, options)),
                    'remove': AsyncMock(side_effect=lambda id_: self._remove_tab(id_)),
                    'reload': AsyncMock(side_effect=lambda id_: self._reload_tab(id_)),
                    'sendMessage': AsyncMock(side_effect=lambda id_, message: self._send_message(id_, message))
                })()
                
                self.scripting = type('Scripting', (), {
                    'executeScript': AsyncMock(return_value=[])
                })()
                
                self.webRequest = type('WebRequest', (), {
                    'onBeforeRequest': event('request')
                })()
                
            def _create_tab(self, options):
                nonlocal next_tab_id
                tab = {"id": next_tab_id, **structured_clone(options)}
                next_tab_id += 1
                browser_tabs[tab["id"]] = tab
                tab_actions.append({"action": "create", **tab})
                return structured_clone(tab)
                
            def _update_tab(self, id_, options):
                if id_ not in browser_tabs:
                    raise Exception("Tab not found")
                if seed.get("failNavigation") and seed["failNavigation"](id_, options):
                    raise Exception("Navigation failed")
                browser_tabs[id_].update(structured_clone(options))
                tab_actions.append({"action": "update", "id": id_, **structured_clone(options)})
                return structured_clone(browser_tabs[id_])
                
            def _remove_tab(self, id_):
                browser_tabs.pop(id_, None)
                tab_actions.append({"action": "remove", "id": id_})
                
            def _reload_tab(self, id_):
                if id_ not in browser_tabs:
                    raise Exception("Tab not found")
                tab_actions.append({"action": "reload", "id": id_})
                
            def _send_message(self, id_, message):
                sent.append({"id": id_, **structured_clone(message)})
                if seed.get("tabReply"):
                    return seed["tabReply"](id_, message)
                elif message.get("type") == "TLC_RECOVERY_PREFLIGHT":
                    return {"shouldReload": True}
                else:
                    return {}

        chrome = MockChrome()
        
        # Create mock context
        context = {
            'chrome': chrome,
            'TLC_CONTENT_CORE': core,
            'TLC_EXPORT_PRIVACY': exportPrivacy,
            'importScripts': lambda: None,
            'structuredClone': structured_clone,
            'URL': MagicMock(),
            'console': MagicMock(),
            'setTimeout': lambda fn, ms: asyncio.get_event_loop().call_later(ms/1000, fn),
            'clearTimeout': lambda handle: None,
            'fetch': AsyncMock(return_value=MagicMock())
        }
        
        if seed.get("now") is not None:
            context['Date'] = type('MockDate', (), {
                '__init__': lambda self, *args: setattr(self, '_dt', datetime.fromtimestamp(args[0]/1000) if args else datetime.fromtimestamp(clock['now']/1000)),
                'now': staticmethod(lambda: clock['now'])
            })
        else:
            context['Date'] = datetime
            
        # Load background.js if exists
        try:
            background_js_path = os.path.join(self.extension_path, "background.js")
            if os.path.exists(background_js_path):
                with open(background_js_path, 'r') as f:
                    exec(f.read(), context)
        except Exception as e:
            print(f"Warning: Could not load background.js: {e}")
            
        async def send(type_, tab_id, extra=None):
            if extra is None:
                extra = {}
                
            loop = asyncio.get_event_loop()
            future = loop.create_future()
            
            def timeout():
                if not future.done():
                    future.set_exception(Exception(f"No response: {type_}"))
                    
            loop.call_later(seed.get("responseTimeoutMs", 1000)/1000, timeout)
            
            def callback(value):
                if not future.done():
                    if not value.get("ok", True):
                        future.set_exception(Exception(value.get("error", type_)))
                    else:
                        future.set_result(structured_clone(value))
                        
            message = {"type": type_, "tabId": tab_id, **extra}
            if "message" in listeners:
                listeners["message"](message, {}, callback)
            else:
                callback({"ok": True})
                
            return await future
            
        return {
            "context": context,
            "send": send,
            "session": session,
            "local": local,
            "sent": sent,
            "broadcasts": broadcasts,
            "browser_tabs": browser_tabs,
            "tab_actions": tab_actions,
            "clock": clock,
            "alarms": alarms,
            "fire_alarm": lambda name: listeners["alarm"]({"name": name}) if "alarm" in listeners else None
        }

    @unittest.skipUnless(core, "Requires content_core module")
    async def test_0PE_177_percentage_reaches_content_and_persists_only_after_successful_activation(self):
        w = self.worker({"tabReply": AsyncMock(return_value={"activated": True})})
        await w["send"]("TLC_PLAYER_ACTION", 7, {"action": "set-limiter", "enabled": True, "strength": 75})
        self.assertEqual(w["sent"][-1]["strength"], 75)
        self.assertEqual(w["local"]["tlc-settings"]["limiterStrength"], 75)
        
        rejected = self.worker({"local": w["local"], "tabReply": AsyncMock(return_value={"activated": False, "reason": "AudioWorklet unavailable"})})
        await rejected["send"]("TLC_PLAYER_ACTION", 7, {"action": "set-limiter", "enabled": True, "strength": 100})
        self.assertEqual(rejected["local"]["tlc-settings"]["limiterStrength"], 75)
        await w["send"]("TLC_PLAYER_ACTION", 7, {"action": "set-limiter", "enabled": True, "thresholdDbfs": -30})
        self.assertEqual(w["local"]["tlc-settings"]["limiterStrength"], 100)

    @unittest.skipUnless(core, "Requires content_core module")
    async def test_0PE_170_worker_wake_restores_active_Embed_deadlines_without_another_navigation(self):
        w = self.worker({"now": 5000, "session": {
            "tlc-embed-7": {"phase": "loading", "startedAtMs": 1000},
            "tlc-embed-8": {"phase": "playing", "startedAtMs": 1000},
            "tlc-embed-9": {"phase": "retry-wait", "startedAtMs": -100000}
        }})
        await asyncio.sleep(0.01)  # Allow event loop to process
        self.assertEqual(w["alarms"].get("tlc-embed-deadline-7", {}).get("when"), 91000)
        self.assertFalse("tlc-embed-deadline-8" in w["alarms"])
        self.assertEqual(w["alarms"].get("tlc-embed-deadline-9", {}).get("when"), 5001)
        self.assertEqual(len(w["tab_actions"]), 0)

    @unittest.skipUnless(core, "Requires content_core module")
    async def test_0PE_170_restored_expired_session_terminates_cancelled_session_stays_cancelled(self):
        initial = core.new_embed_session("restart-test", "creator", 1000)
        w = self.worker({"now": 95000,
            "tabs": [{"id": 7, "url": "https://www.tiktok.com/embed/live/@creator"}],
            "session": {"tlc-embed-7": initial, "tlc-embed-8": {**initial, "phase": "cancelled"}}
        })
        await asyncio.sleep(0.01)
        await w["fire_alarm"]("tlc-embed-deadline-7")
        self.assertEqual(w["session"]["tlc-embed-7"]["phase"], "failed")
        self.assertEqual(w["session"]["tlc-embed-7"]["reason"], "timeout")
        self.assertFalse("tlc-embed-deadline-7" in w["alarms"])
        self.assertFalse("tlc-embed-deadline-8" in w["alarms"])
        await w["fire_alarm"]("tlc-embed-deadline-8")
        self.assertEqual(w["session"]["tlc-embed-8"]["phase"], "cancelled")
        self.assertEqual(len(w["tab_actions"]), 0)

    def test_0PE_167_explicit_user_pause_suppresses_media_recovery_without_hiding_genuine_failures_after_resume(self):
        video = {"paused": True, "readyState": 4, "error": None, "ended": False}
        self.assertEqual(core.media_recovery_reason(video, {"userPaused": True}), "")
        self.assertEqual(core.media_recovery_reason(video), "video-paused")
        self.assertEqual(core.media_recovery_reason({**video, "paused": False}), "")
        self.assertEqual(core.media_recovery_reason({**video, "error": {}}), "video-error")
        self.assertEqual(core.media_recovery_reason({**video, "ended": True}), "video-ended")
        self.assertEqual(core.media_recovery_reason({**video, "paused": False, "readyState": 1}), "video-not-ready")
        self.assertEqual(core.media_recovery_reason(video, {"graceElapsed": False}), "")
        self.assertEqual(core.media_recovery_reason(None), "")

    def test_0PE_170_missing_playback_times_out_on_observations_and_stale_or_invalid_observations_do_nothing(self):
        state = core.new_embed_session("test", "creator", 1000)
        observation = {"status": "waiting", "documentId": "a", "documentStartedAtMs": 1000}
        self.assertEqual(core.advance_embed_session(state, observation, 15999)["session"]["phase"], "loading")
        self.assertEqual(core.advance_embed_session(state, observation, 16000)["session"]["phase"], "retry-wait")
        self.assertEqual(core.advance_embed_session(state, observation, 91000)["session"]["phase"], "failed")
        for invalid in [{**observation, "status": "unknown"}, {**observation, "documentStartedAtMs": 999}]:
            self.assertEqual(core.advance_embed_session(state, invalid, 16000), {"session": state, "action": "none"})

    def test_0PE_172_unknown_report_keys_malformed_URL_protocols_and_unknown_metadata_values_fail_closed(self):
        input_data = {
            "raw": {"password": "PRIVATE-KEY"}, 
            "cookie": "PRIVATE-COOKIE", 
            "media": [{"url": "data:PRIVATE-PAYLOAD", "source": "PRIVATE-SOURCE"}],
            "components": {
                "captions": {
                    "sources": ["PRIVATE-SOURCE"], 
                    "languages": ["PRIVATE-LANGUAGE"], 
                    "unknown": "PRIVATE-CONTENT"
                }
            }
        }
        result = exportPrivacy.diagnostic_report(input_data)
        self.assertNotIn("PRIVATE-", json.dumps(result))
        self.assertIsNone(exportPrivacy.url("not a url"))
        self.assertIsNone(exportPrivacy.url("blob:https://example.com/private"))

if __name__ == '__main__':
    unittest.main()
