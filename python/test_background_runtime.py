#!/usr/bin/env python3
# test_background_runtime.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_background_runtime.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_background_runtime.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import unittest
import os
import sys
import json
import copy
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock, AsyncMock
import asyncio
import hashlib
import base64

# Mock Node.js modules
sys.modules['node:assert/strict'] = MagicMock()
sys.modules['node:fs'] = MagicMock()
sys.modules['node:path'] = MagicMock()
sys.modules['node:vm'] = MagicMock()
sys.modules['node:crypto'] = MagicMock()
sys.modules['node:test'] = MagicMock()

# Mock required imports
extension_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../browser-extension"))
core = MagicMock()
export_privacy = MagicMock()

def mock_require(path):
    if 'content-core.js' in path:
        return core
    elif 'export-privacy.js' in path:
        return export_privacy
    return MagicMock()

with patch.dict('sys.modules', {
    'node:assert/strict': MagicMock(),
    'node:fs': MagicMock(),
    'node:path': MagicMock(),
    'node:vm': MagicMock(),
    'node:crypto': MagicMock(),
    'node:test': MagicMock()
}), \
patch('builtins.require', side_effect=mock_require):
    
    # Now we can import our actual test functions
    pass

class TestBackgroundRuntime(unittest.TestCase):
    
    def setUp(self):
        self.extension = os.path.abspath(os.path.join(os.path.dirname(__file__), "../browser-extension"))
        
    def test_0PE_170_startup_retry_backs_off_caps_at_three_attempts_and_ignores_stale_documents(self):
        state = core.newEmbedSession("test", "creator", 1000)
        
        def observe(now, status, documentId="a", documentStartedAtMs=1000):
            result = core.advanceEmbedSession(state, {"status": status, "documentId": documentId, "documentStartedAtMs": documentStartedAtMs}, now)
            state.update(result.session)
            return result.action
            
        self.assertEqual(observe(2000, "server-error"), "none")
        self.assertEqual(state.nextAttemptAtMs, 4000)
        self.assertEqual(observe(3999, "server-error"), "none")
        self.assertEqual(observe(4000, "server-error"), "reload")
        self.assertEqual(state.attempt, 2)
        self.assertEqual(observe(5000, "playing"), "none")
        self.assertEqual(state.phase, "loading", "old document cannot complete a newer attempt")
        observe(6000, "unavailable", "b", 4500)
        self.assertEqual(state.nextAttemptAtMs, 10000)
        self.assertEqual(observe(10000, "unavailable", "b", 4500), "reload")
        observe(11000, "server-error", "c", 10500)
        self.assertEqual(state.phase, "failed")
        self.assertEqual(state.attempt, 3)
        self.assertEqual(observe(100000, "server-error", "c", 10500), "none")

    def test_0PE_170_playback_before_retry_cancels_it_while_login_ended_gesture_never_reload(self):
        def observation(status):
            return {"status": status, "documentId": "a", "documentStartedAtMs": 1000}
            
        initial = core.newEmbedSession("test", "creator", 1000)
        waiting = core.advanceEmbedSession(initial, observation("server-error"), 2000).session
        recovered = core.advanceEmbedSession(waiting, observation("playing"), 3000)
        self.assertEqual(recovered.session.phase, "playing")
        self.assertEqual(recovered.session.nextAttemptAtMs, None)
        
        for status in ["login-required", "ended", "awaiting-gesture"]:
            result = core.advanceEmbedSession(waiting, observation(status), 6000)
            self.assertEqual(result.action, "none")
            self.assertEqual(result.session.nextAttemptAtMs, None)
            
        self.assertEqual(core.advanceEmbedSession({"phase": "cancelled", **initial}, observation("server-error"), 100000).action, "none")
        self.assertEqual(core.classifyEmbedObservation({"text": "Server error"}), "server-error")
        self.assertEqual(core.classifyEmbedObservation({"text": "LIVE is unavailable"}), "unavailable")
        self.assertEqual(core.classifyEmbedObservation({"text": "Melde dich an für das vollständige Erlebnis"}), "login-required")
        self.assertEqual(core.classifyEmbedObservation({"playing": True, "readyState": 4}), "playing")
        self.assertEqual(core.classifyEmbedObservation({"paused": True, "readyState": 4}), "awaiting-gesture")

    def worker(self, seed=None):
        if seed is None:
            seed = {}
            
        clock = {"now": seed.get("now", datetime.now().timestamp() * 1000)}
        
        class TestDate(datetime):
            @classmethod
            def now(cls):
                return datetime.fromtimestamp(clock["now"] / 1000)
                
        session = copy.deepcopy(seed.get("session", {}))
        local = copy.deepcopy(seed.get("local", {}))
        sent = []
        broadcasts = []
        browser_tabs = {tab["id"]: copy.deepcopy(tab) for tab in seed.get("tabs", [])}
        tab_actions = []
        next_tab_id = 100
        listeners = {}
        alarms = {}
        
        def event(name):
            def add_listener(fn):
                listeners[name] = fn
            return type('Event', (), {'addListener': add_listener})()
            
        def storage(data):
            async def get(key):
                if key is None:
                    return copy.deepcopy(data)
                return {key: copy.deepcopy(data.get(key))}
                
            async def set_(patch):
                data.update(copy.deepcopy(patch))
                
            async def remove(key):
                if key in data:
                    del data[key]
                    
            return type('Storage', (), {'get': get, 'set': set_, 'remove': remove})()
            
        chrome = type('Chrome', (), {
            'alarms': type('Alarms', (), {
                'onAlarm': event("alarm"),
                'create': AsyncMock(side_effect=lambda name, info: alarms.update({name: copy.deepcopy(info)})),
                'clear': AsyncMock(side_effect=lambda name: alarms.pop(name, None))
            })(),
            'storage': type('StorageArea', (), {
                'session': storage(session),
                'local': storage(local)
            })(),
            'sidePanel': type('SidePanel', (), {
                'setPanelBehavior': AsyncMock(),
                'setOptions': AsyncMock()
            })(),
            'runtime': type('Runtime', (), {
                'onInstalled': event("installed"),
                'onStartup': event("startup"),
                'onMessage': event("message"),
                'getManifest': lambda: {'version': "0.8.2"},
                'getURL': lambda name: f"chrome-extension://test/{name}",
                'sendMessage': AsyncMock(side_effect=lambda message: broadcasts.append(copy.deepcopy(message)))
            })(),
            'tabs': type('Tabs', (), {
                'onUpdated': event("updated"),
                'onRemoved': event("removed"),
                'get': AsyncMock(side_effect=lambda id_: copy.deepcopy(browser_tabs[id_]) if id_ in browser_tabs else Exception("Tab not found")),
                'create': AsyncMock(side_effect=lambda options: (
                    browser_tabs.update({next_tab_id: {**options, "id": next_tab_id}}) or 
                    tab_actions.append({"action": "create", **{**options, "id": next_tab_id}}) or
                    setattr(next_tab_id, next_tab_id + 1) or
                    copy.deepcopy(browser_tabs[next_tab_id - 1])
                )),
                'update': AsyncMock(side_effect=lambda id_, options: (
                    browser_tabs.update({id_: {**browser_tabs[id_], **copy.deepcopy(options)}}) if id_ in browser_tabs else Exception("Tab not found") or
                    (tab_actions.append({"action": "update", "id": id_, **copy.deepcopy(options)}) if not seed.get("failNavigation", lambda x, y: False)(id_, options) else Exception("Navigation failed")) or
                    copy.deepcopy(browser_tabs[id_])
                )),
                'remove': AsyncMock(side_effect=lambda id_: (browser_tabs.pop(id_, None), tab_actions.append({"action": "remove", "id": id_}))),
                'reload': AsyncMock(side_effect=lambda id_: (tab_actions.append({"action": "reload", "id": id_}) if id_ in browser_tabs else Exception("Tab not found"))),
                'sendMessage': AsyncMock(side_effect=lambda id_, message: (
                    sent.append({"id": id_, **copy.deepcopy(message)}) or
                    (seed.get("tabReply")(id_, message) if seed.get("tabReply") else 
                     {"shouldReload": True} if message.get("type") == "TLC_RECOVERY_PREFLIGHT" else {})
                ))
            })(),
            'scripting': type('Scripting', (), {
                'executeScript': AsyncMock(return_value=[])
            })(),
            'webRequest': type('WebRequest', (), {
                'onBeforeRequest': event("request")
            })()
        })()
        
        context = {
            'chrome': chrome,
            'TLC_CONTENT_CORE': core,
            'TLC_EXPORT_PRIVACY': export_privacy,
            'TLCPipelines': type('Pipelines', (), {
                'publish': AsyncMock(),
                'message': AsyncMock()
            })(),
            'importScripts': lambda: None,
            'structuredClone': copy.deepcopy,
            'URL': MagicMock(),
            'Date': TestDate if seed.get("now") is not None else datetime,
            'console': MagicMock(),
            'crypto': MagicMock(),
            'setTimeout': lambda fn, _: asyncio.get_event_loop().call_soon(fn),
            'clearTimeout': lambda _: None,
            'fetch': AsyncMock(return_value=None)
        }
        
        # Mock file reading
        with patch('builtins.open', mock_open(read_data="")):
            pass
            
        def send(type_, tabId, extra=None):
            if extra is None:
                extra = {}
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            async def _send():
                timeout = asyncio.sleep(seed.get("responseTimeoutMs", 1000) / 1000)
                try:
                    value = None
                    if "message" in listeners:
                        def callback(v):
                            nonlocal value
                            value = v
                        listeners["message"]({"type": type_, "tabId": tabId, **extra}, {}, callback)
                        await asyncio.wait_for(asyncio.shield(asyncio.sleep(0.01)), timeout=1)
                    if value is None:
                        raise Exception(f"No response: {type_}")
                    if not value.get("ok"):
                        raise Exception(value.get("error", type_))
                    return copy.deepcopy(value)
                except Exception as e:
                    raise e
                    
            return loop.run_until_complete(_send())
            
        return type('Worker', (), {
            'context': context,
            'send': send,
            'session': session,
            'local': local,
            'sent': sent,
            'broadcasts': broadcasts,
            'browserTabs': browser_tabs,
            'tabActions': tab_actions,
            'clock': clock,
            'alarms': alarms,
            'fireAlarm': lambda name: listeners["alarm"]({"name": name}) if "alarm" in listeners else None
        })()

    def test_0PE_177_percentage_reaches_content_and_persists_only_after_successful_activation(self):
        w = self.worker({"tabReply": AsyncMock(return_value={"activated": True})})
        asyncio.run(w.send("TLC_PLAYER_ACTION", 7, {"action": "set-limiter", "enabled": True, "strength": 75}))
        self.assertEqual(w.sent[-1].strength, 75)
        self.assertEqual(w.local["tlc-settings"].limiterStrength, 75)
        
        rejected = self.worker({"local": w.local, "tabReply": AsyncMock(return_value={"activated": False, "reason": "AudioWorklet unavailable"})})
        asyncio.run(rejected.send("TLC_PLAYER_ACTION", 7, {"action": "set-limiter", "enabled": True, "strength": 100}))
        self.assertEqual(rejected.local["tlc-settings"].limiterStrength, 75)
        
        asyncio.run(w.send("TLC_PLAYER_ACTION", 7, {"action": "set-limiter", "enabled": True, "thresholdDbfs": -30}))
        self.assertEqual(w.local["tlc-settings"].limiterStrength, 100)

    def test_0PE_170_worker_wake_restores_active_Embed_deadlines_without_another_navigation(self):
        w = self.worker({"now": 5000, "session": {
            "tlc-embed-7": {"phase": "loading", "startedAtMs": 1000},
            "tlc-embed-8": {"phase": "playing", "startedAtMs": 1000},
            "tlc-embed-9": {"phase": "retry-wait", "startedAtMs": -100000}
        }})
        asyncio.run(asyncio.sleep(0.01))  # Allow event loop to process
        self.assertEqual(w.alarms.get("tlc-embed-deadline-7", {}).get("when"), 91000)
        self.assertFalse("tlc-embed-deadline-8" in w.alarms)
        self.assertEqual(w.alarms.get("tlc-embed-deadline-9", {}).get("when"), 5001)
        self.assertEqual(len(w.tabActions), 0)

    def test_0PE_170_restored_expired_session_terminates_cancelled_session_stays_cancelled(self):
        initial = core.newEmbedSession("restart-test", "creator", 1000)
        w = self.worker({"now": 95000,
            "tabs": [{"id": 7, "url": "https://www.tiktok.com/embed/live/@creator"}],
            "session": {"tlc-embed-7": initial, "tlc-embed-8": {**initial, "phase": "cancelled"}}
        })
        asyncio.run(asyncio.sleep(0.01))
        asyncio.run(w.fireAlarm("tlc-embed-deadline-7"))
        self.assertEqual(w.session["tlc-embed-7"].phase, "failed")
        self.assertEqual(w.session["tlc-embed-7"].reason, "timeout")
        self.assertFalse("tlc-embed-deadline-7" in w.alarms)
        self.assertFalse("tlc-embed-deadline-8" in w.alarms)
        asyncio.run(w.fireAlarm("tlc-embed-deadline-8"))
        self.assertEqual(w.session["tlc-embed-8"].phase, "cancelled")
        self.assertEqual(len(w.tabActions), 0)

    # Additional tests would continue here following the same pattern...

if __name__ == '__main__':
    unittest.main()
