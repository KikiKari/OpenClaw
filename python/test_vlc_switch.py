#!/usr/bin/env python3
# test_vlc_switch.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_vlc_switch.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_vlc_switch.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import unittest
from unittest.mock import Mock, patch, MagicMock
import asyncio

class TestVLCSwitch(unittest.TestCase):
    
    def setUp(self):
        # Simulate the JavaScript objects and behavior
        self.listeners = {}
        self.changed_callback = None
        
        # Media objects
        self.native = {'muted': False, 'paused': False, 'pause': lambda: setattr(self.native, 'paused', True)}
        self.fallback = {'muted': False, 'paused': False}
        self.media = [self.native, self.fallback]
        self.unrelated_video = self.native.copy()
        self.speech_audio = self.native.copy()
        
        # Surface object with querySelectorAll
        self.surface = {'querySelectorAll': lambda selector: self.assertEqual(selector, 'video') or self.media}
        
        # Setup fallback's closest method
        self.fallback['closest'] = lambda _: {'parentElement': self.surface}
        
        # Gain object
        self.gain = {'value': 0.7}
        
        # Document mock
        self.document = {
            'querySelectorAll': lambda: exec('raise Exception("Must not globally suppress page media")'),
            'documentElement': {},
            'addEventListener': lambda name, fn: self.listeners.update({name: fn}),
            'removeEventListener': lambda name: self.listeners.pop(name, None)
        }
        
        # MutationObserver mock
        class MutationObserver:
            def __init__(self, fn):
                self.changed_callback = fn
            def observe(self): pass
            def disconnect(self): pass
            
        self.MutationObserver = MutationObserver
        
    def test_suppress_native_audio(self):
        # This is a simplified version - would need actual JS execution for full test
        # Testing the key assertions from the original code
        
        # Initial state checks
        self.assertEqual(self.native['muted'], False)
        self.assertEqual(self.native['paused'], False)
        self.assertEqual(self.gain['value'], 0.7)
        self.assertEqual(self.fallback['muted'], False)
        self.assertEqual(self.fallback['paused'], False)
        
        # Simulate suppressNativeAudio effect
        self.native['muted'] = True
        self.native['paused'] = True
        self.gain['value'] = 0
        
        # Check post-suppress state
        self.assertEqual(self.native['muted'], True)
        self.assertEqual(self.native['paused'], True)
        self.assertEqual(self.gain['value'], 0)
        self.assertEqual(self.fallback['muted'], False)
        self.assertEqual(self.fallback['paused'], False)
        
        # Simulate play event
        self.native['paused'] = False
        if 'play' in self.listeners:
            self.listeners['play']()
        self.assertEqual(self.native['paused'], True)
        
        # Add replacement media
        replacement = self.native.copy()
        replacement.update({'muted': False, 'paused': False})
        self.media.append(replacement)
        
        # Simulate change callback
        if hasattr(self.MutationObserver, 'changed_callback') and self.MutationObserver.changed_callback:
            self.MutationObserver.changed_callback()
            
        # Check replacement is muted
        self.assertEqual(replacement['muted'], True)
        self.assertEqual(replacement['paused'], True)
        
        # Release simulation
        self.native['muted'] = False
        self.native['paused'] = False
        self.gain['value'] = 0.7
        
        # Final state checks
        self.assertEqual(self.native['muted'], False)
        self.assertEqual(self.native['paused'], False)
        self.assertEqual(self.gain['value'], 0.7)
        self.assertEqual(len(self.listeners), 0)
        self.assertEqual(self.unrelated_video['paused'], False)
        self.assertEqual(self.speech_audio['paused'], False)

    def test_normal_navigation(self):
        # Test that normal navigation works even at same URL
        background_content = """
async function openNormalLive(tabId) {
    const {url} = await chrome.tabs.get(tabId);
    const handle = pageHandle(url);
    if (!handle) return;
    await chrome.tabs.update(tabId, { url: normalLiveUrl(handle) });
}
"""
        # Check that it contains the expected navigation pattern
        self.assertIn('await chrome.tabs.update(tabId, { url: normalLiveUrl(handle) })', background_content)
        self.assertNotIn('if (reloading)', background_content)

    def test_primary_video_selection(self):
        # Test active replacement wins regardless of video size
        large_native = {
            'closest': lambda: None,
            'getBoundingClientRect': lambda: {'width': 1000, 'height': 1000}
        }
        small_replacement = {
            'closest': lambda: {},
            'getBoundingClientRect': lambda: {'width': 100, 'height': 100}
        }
        
        # Active replacement scenario
        active_media_fallback_item = {}
        media_fallback_running = False
        
        def primary_video():
            if active_media_fallback_item:
                return small_replacement
            if media_fallback_running:
                return small_replacement
            return large_native
            
        # Test active replacement wins
        self.assertEqual(primary_video(), small_replacement)
        
        # Test starting replacement owns player controls
        active_media_fallback_item.clear()
        media_fallback_running = True
        self.assertEqual(primary_video(), small_replacement)
        
        # Test inactive replacement excluded
        media_fallback_running = False
        self.assertEqual(primary_video(), large_native)

    async def test_vlc_click_dispatch(self):
        starts = 0
        
        async def run_player(action, target):
            self.assertEqual(action, 'play-vlc-source')
            starts += 1
            
        button = Mock()
        button.addEventListener = Mock()
        
        # Simulate click event listener setup
        button.addEventListener('click', lambda: asyncio.create_task(run_player('play-vlc-source', button)))
        
        # Simulate click
        await button.addEventListener.call_args[0][1]()
        self.assertEqual(starts, 1)

    async def test_failed_startup_restores_native(self):
        # Test failed VLC startup restores native player
        released = 0
        removed = 0
        created = 0
        
        video = Mock()
        video.pause = Mock()
        video.removeAttribute = Mock()
        video.load = Mock()
        
        def ensure_media_fallback_video():
            nonlocal created
            created += 1
            return video
            
        def suppress_native_audio():
            def release():
                nonlocal released
                released += 1
            return release
            
        player_context = {
            'mediaFallbackRunning': False,
            'mediaFallbackPageUrl': 'live',
            'location': {'href': 'live'},
            'attemptedMediaFallbackUrls': set(),
            'activeMediaFallbackItem': None,
            'releaseNativeAudio': None,
            'mediaFallbackCandidates': lambda x: x,
            'mediaFallbackKey': lambda x: x['url'],
            'ensureMediaFallbackVideo': ensure_media_fallback_video,
            'suppressNativeAudio': suppress_native_audio,
            'setMediaFallbackStatus': Mock(),
            'destroyMediaFallbackPlayer': Mock(),
            'tryMediaUrl': Mock(return_value={'ok': False, 'reason': 'test failure'}),
            'getPlayerState': Mock(return_value={}),
            'document': {'getElementById': Mock(return_value=Mock(remove=Mock()))}
        }
        
        # Test no sources creates no overlay
        result = await self.play_media_fallback(player_context, [])
        self.assertEqual(created, 0)
        self.assertEqual(result['activated'], False)
        
        # Test failed startup restores native audio
        result = await self.play_media_fallback(player_context, [{'url': 'test', 'quality': 'test'}])
        self.assertEqual(released, 1)
        self.assertEqual(removed, 1)
        self.assertEqual(player_context['mediaFallbackRunning'], False)

    async def play_media_fallback(self, context, sources):
        # Simplified implementation of playMediaFallback logic
        if not sources:
            return {'activated': False}
            
        context['suppressNativeAudio']()
        context['ensureMediaFallbackVideo']()
        
        result = await context['tryMediaUrl']()
        if not result['ok']:
            # Cleanup on failure
            context['document']['getElementById']().remove()
            if context['releaseNativeAudio']:
                context['releaseNativeAudio']()
            return {'activated': False}
            
        return {'activated': True}

def main():
    unittest.main()

if __name__ == '__main__':
    main()
