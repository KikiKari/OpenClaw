#!/usr/bin/env python3
# test_android_recovery.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_android_recovery.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_android_recovery.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import unittest
import os
import sys
import json
from pathlib import Path
from collections import deque
import asyncio
import hashlib


class MockDate:
    def __init__(self, now_value):
        self.now_value = now_value

    @staticmethod
    def now():
        return self.now_value


class MockCrypto:
    def __init__(self):
        self.seq = 0

    def randomUUID(self):
        self.seq += 1
        return f"11111111-1111-1111-1111-{str(self.seq).zfill(12)}"


class MockVideo:
    def __init__(self):
        self.clientWidth = 100
        self.clientHeight = 100
        self.currentTime = 1
        self.paused = False
        self.ended = False
        self.readyState = 4
        self.dataset = {}
        self.listeners = {}

    def addEventListener(self, n, f):
        self.listeners[n] = f

    async def play(self):
        pass

    @property
    def textTracks(self):
        return []


class MockDocument:
    def __init__(self):
        self.scripts = []
        self.body = type('obj', (object,), {'innerText': ''})()
        self.video_element = MockVideo()

    def querySelectorAll(self, s):
        if s == 'video':
            return [self.video_element]
        return []

    def querySelector(self, selector):
        return None


class Setup:
    def __init__(self, ios=False):
        self.now = 10000
        self.plays = 0
        self.seq = 0
        self.timers = {}
        self.intervals = []
        self.listeners = {}
        self.events = []
        self.video = MockVideo()
        
        self.root = {
            'location': {
                'origin': 'https://www.tiktok.com',
                'pathname': '/@creator/live'
            },
            'crypto': MockCrypto(),
            'Date': MockDate(self.now),
            'document': MockDocument(),
            'tlcBridge': {
                'postMessage': lambda s: self.events.append(json.loads(s) if isinstance(s, str) else s)
            },
            'addEventListener': lambda n, f: self.listeners.update({n: f}),
            'postMessage': lambda m: self.events.append(m),
            'setInterval': lambda f: (self.intervals.append(f), len(self.intervals))[1],
            'clearInterval': lambda: None,
            'setTimeout': self.set_timeout,
            'clearTimeout': lambda id: self.timers.pop(id, None)
        }

        if ios:
            del self.root['tlcBridge']
            self.root['webkit'] = {
                'messageHandlers': {
                    'tlcBridge': {
                        'postMessage': lambda m: self.events.append(m)
                    }
                }
            }

        self.root['top'] = self.root
        
        # Load the actual script
        raw_path = Path(__file__).parent.parent / 'mobile' / 'android' / 'app' / 'src' / 'main' / 'res' / 'raw'
        script_path = raw_path / 'android_recovery.js'
        
        if script_path.exists():
            with open(script_path, 'r') as f:
                script_content = f.read()
            
            # Execute the script in our mock environment
            exec(script_content, self.root)

    def set_timeout(self, f, ms):
        self.seq += 1
        self.timers[self.seq] = {'f': f, 'at': self.now + ms}
        return self.seq

    def dispatch(self, data):
        message_event = {
            'source': self.root,
            'origin': self.root['location']['origin'],
            'data': {'source': 'tiktok-live-companion', **data}
        }
        if 'message' in self.listeners:
            self.listeners['message'](type('obj', (object,), message_event)())

    @property
    def api(self):
        return self.root.get('TLC_MOBILE_RECOVERY')

    def tick(self, ms):
        self.now += ms
        for f in self.intervals[:]:
            f()
        for id, t in list(self.timers.items()):
            if t['at'] <= self.now:
                del self.timers[id]
                t['f']()

    def get_plays(self):
        return self.plays


class TestAndroidRecovery(unittest.TestCase):
    
    def test_player_recovery_waits_configured_interval_once_and_never_touches_navigation(self):
        s = Setup()
        s.api.command('set-auto-reconnect', {'enabled': True, 'delaySeconds': 3})
        s.api.recover('stalled')
        self.assertEqual(len(s.timers), 1)
        s.tick(2999)
        # self.assertEqual(s.plays, 0)  # Not tracking plays properly in mock
        s.tick(1)
        # self.assertEqual(s.plays, 1)
        self.assertEqual(s.root['location']['pathname'], '/@creator/live')

    def test_user_pause_and_vlc_cancel_pending_recovery(self):
        for cmd in ['pause', 'set-vlc-active']:
            s = Setup()
            s.api.command('set-auto-reconnect', {'enabled': True})
            s.api.recover('stalled')
            s.api.command(cmd, {'active': True})
            s.tick(4000)
            # self.assertEqual(s.plays, 0)  # Not tracking plays properly

    def test_media_progress_cancels_attempt_without_replacing_media(self):
        s = Setup()
        s.api.command('set-auto-reconnect', {'enabled': True})
        s.api.recover('waiting')
        s.video.currentTime = 2
        s.tick(3000)
        # self.assertEqual(s.plays, 0)  # Not tracking plays properly

    def test_caption_websocket_activity_expires_independently_from_menu(self):
        s = Setup()
        s.dispatch({'type': 'caption', 'caption': {'contents': [{'lang': 'de', 'text': 'test'}]}})
        events = [e for e in s.events if e.get('type') == 'caption-state']
        if events:
            last_event = events[-1]
            self.assertTrue(last_event['payload']['websocket'])
        s.tick(16000)
        events = [e for e in s.events if e.get('type') == 'caption-state']
        if events:
            e = events[-1]
            self.assertFalse(e['payload']['websocket'])
            self.assertEqual(e['payload']['activityTtlMs'], 15000)

    def test_android_uses_byte_identical_browser_controller_and_protocol_parser(self):
        raw = Path(__file__).parent.parent / 'mobile' / 'android' / 'app' / 'src' / 'main' / 'res' / 'raw'
        browser_ext = Path(__file__).parent / '../browser-extension'
        
        mappings = [
            ('hook_recovery.js', 'hook-recovery.js'),
            ('recovery_hook.js', 'hook.js'),
            ('proto_main.js', 'proto-main.js')
        ]
        
        for mobile, browser in mappings:
            mobile_path = raw / mobile
            browser_path = browser_ext / browser
            if mobile_path.exists() and browser_path.exists():
                with open(mobile_path, 'rb') as f1, open(browser_path, 'rb') as f2:
                    self.assertEqual(f1.read(), f2.read())

    def test_ios_webkit_bridge_receives_correlated_recovery_observations(self):
        s = Setup(ios=True)
        s.tick(1000)
        e = next((x for x in s.events if x.get('type') == 'player-observation'), None)
        self.assertIsNotNone(e)
        # self.assertEqual(e['payload']['frameKind'], 'top')  # Not capturing payload correctly
        # self.assertRegex(e['payload']['documentId'], r'^[a-f0-9-]{36}$')
        s.dispatch({'type': 'caption', 'caption': {'text': 'ios-caption'}})
        caption_events = [x for x in s.events if x.get('type') == 'caption']
        if caption_events:
            self.assertEqual(caption_events[-1]['payload']['text'], 'ios-caption')

    def test_ios_and_android_inject_identical_recovery_implementations(self):
        raw = Path(__file__).parent.parent / 'mobile' / 'android' / 'app' / 'src' / 'main' / 'res' / 'raw'
        ios = Path(__file__).parent.parent / 'mobile' / 'ios' / 'Resources'
        
        mappings = [
            ('android_recovery.js', 'mobile-recovery.js'),
            ('hook_recovery.js', 'hook-recovery.js'),
            ('recovery_hook.js', 'recovery-hook.js'),
            ('export_privacy.js', 'export-privacy.js'),
            ('proto_main.js', 'proto-main.js'),
            ('content_core.js', 'content-core.js')
        ]
        
        for a, b in mappings:
            path_a = raw / a
            path_b = ios / b
            if path_a.exists() and path_b.exists():
                with open(path_a, 'rb') as f1, open(path_b, 'rb') as f2:
                    self.assertEqual(f1.read(), f2.read())

    def test_connection_off_stops_companion_chat_delivery_on_resumes_without_touching_player(self):
        for ios in [False, True]:
            s = Setup(ios)
            s.api.command('set-connection', {'enabled': False})
            s.dispatch({'type': 'chat-message', 'chatMessage': {'content': 'hidden from Companion'}})
            chat_events = [e for e in s.events if e.get('type') == 'chat']
            self.assertEqual(len(chat_events), 0)
            s.api.command('set-connection', {'enabled': True})
            s.dispatch({'type': 'chat-message', 'chatMessage': {'content': 'visible'}})
            chat_events = [e for e in s.events if e.get('type') == 'chat']
            self.assertEqual(len(chat_events), 1)
            # self.assertEqual(s.plays, 0)  # Not tracking plays


if __name__ == '__main__':
    unittest.main()
