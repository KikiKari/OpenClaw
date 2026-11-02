#!/usr/bin/env python3
# test_status_overview_player.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_status_overview_player.cjs
# Erzeugt: 2026-11-02 durch ABSTRACTIONS_MANAGER.py

import unittest
from unittest.mock import Mock, patch, AsyncMock
import asyncio
import os
import sys
from datetime import datetime, timedelta

# Mock classes to simulate DOM elements and browser APIs
class Element:
    def __init__(self, tag):
        self.tag = tag
        self.style = {}
        self.classList = Mock()
        self.classList.toggle = Mock()
        self.children = []
        self.listeners = {}
        self.muted = False
        self.paused = True
        self.src = ''
        self.currentTime = 0
        self.textContent = ''
        self.hidden = False
        
    def append(self, *nodes):
        self.children.extend(nodes)
        
    def addEventListener(self, name, fn):
        if name not in self.listeners:
            self.listeners[name] = set()
        self.listeners[name].add(fn)
        
    def removeEventListener(self, name, fn):
        if name in self.listeners:
            self.listeners[name].discard(fn)
            
    def emit(self, name):
        if name in self.listeners:
            for fn in list(self.listeners[name]):
                fn()
                
    def pause(self):
        self.paused = True
        
    def removeAttribute(self, attr):
        self.src = ''
        
    def load(self):
        pass
        
    async def play(self):
        self.paused = False
        # Use asyncio to simulate microtask queueing
        async def delayed_play():
            if 'bad' in self.src:
                self.emit('error')
            else:
                self.currentTime += 1
                self.emit('playing')
                self.emit('timeupdate')
        asyncio.create_task(delayed_play())
        return None

class MockDocument:
    def __init__(self, grid_element):
        self.grid_element = grid_element
        
    def getElementById(self, id):
        return self.grid_element
        
    def createElement(self, tag):
        return Element(tag)

class MockStorage:
    def __init__(self):
        self.onChanged = Mock()
        self.onChanged.addListener = Mock()

class MockRuntime:
    def __init__(self, send_message_func):
        self.sendMessage = send_message_func

class MockChrome:
    def __init__(self, send_message_func):
        self.runtime = MockRuntime(send_message_func)
        self.storage = MockStorage()

class TestStatusOverviewPlayer(unittest.IsolatedAsyncioTestCase):
    
    async def asyncSetUp(self):
        # Load the JavaScript source file
        script_path = os.path.join(os.path.dirname(__file__), '..', 'browser-extension', 'status-overview-player.js')
        with open(script_path, 'r', encoding='utf-8') as f:
            self.js_source = f.read()
            
    def create_test_context(self, grid, rows, config=None):
        if config is None:
            config = {'interval': 5}
            
        change_callback = [None]
        
        async def send_message():
            return {'ok': True, 'config': config, 'rows': rows}
            
        document = MockDocument(grid)
        chrome = MockChrome(send_message)
        
        def add_listener(fn):
            change_callback[0] = fn
            
        chrome.storage.onChanged.addListener = add_listener
        
        context = {
            'document': document,
            'chrome': chrome,
            'window': Mock(),
            'URL': Mock(),
            'Date': Mock(),
            'Promise': Mock(),
            'Number': Mock(),
            'String': Mock(),
            'Array': Mock(),
            'JSON': Mock(),
            'Object': Mock(),
            'Map': Mock(),
            'setTimeout': lambda fn, delay: asyncio.get_event_loop().call_later(delay/1000, fn),
            'clearTimeout': Mock()
        }
        
        context['Date'].now = Mock(return_value=datetime.now())
        context['Array'].from_ = lambda x: list(x) if hasattr(x, '__len__') else list(x)
        
        return context, change_callback
    
    async def execute_js_in_context(self, context):
        # This is a simplified execution - in reality we'd need a JS interpreter
        # For now we'll mock the expected behavior based on the test cases
        pass
    
    async def test_nine_independent_tiles_start_muted_and_try_next_source(self):
        grid = Element('main')
        rows = [
            {
                'handle': f'user{i}',
                'status': 'online',
                'checkedAt': datetime.now().timestamp() * 1000,
                'media': [
                    {'protocol': 'hls', 'url': 'https://example.test/bad.m3u8'},
                    {'protocol': 'hls', 'url': 'https://example.test/good.m3u8'}
                ]
            } for i in range(9)
        ]
        
        context, change_callback = self.create_test_context(grid, rows)
        
        # Simulate running the JavaScript code
        await asyncio.sleep(0.02)  # Wait 20ms
        
        # Assertions
        self.assertEqual(len(grid.children), 29)
        
        for i, tile in enumerate(grid.children[:9]):
            self.assertTrue(tile.children[1].muted)
            self.assertIn('good', tile.children[1].src)
            self.assertIn('abgespielt', tile.children[2].textContent)
            
        # Update first row to offline
        rows[0] = {
            'handle': 'user0',
            'status': 'offline',
            'checkedAt': datetime.now().timestamp() * 1000,
            'media': []
        }
        
        # Trigger change event
        if change_callback[0]:
            change_callback[0]({'tlc-overview-row-0': {}}, 'session')
            
        await asyncio.sleep(0.01)  # Wait 10ms
        
        # Assertions after change
        self.assertTrue(grid.children[0].hidden)
        self.assertIn('good', grid.children[1].children[1].src)
    
    async def test_retry_switches_only_requested_tile_tries_remaining_sources(self):
        grid = Element('main')
        config = {'interval': 5}
        
        rows = []
        for i in range(9):
            row = {
                'handle': f'user{i}',
                'status': 'online',
                'checkedAt': (datetime.now() - timedelta(minutes=10)).timestamp() * 1000,
                'media': [
                    {'protocol': 'hls', 'url': f'https://example.test/{i}-first.m3u8'},
                    {'protocol': 'hls', 'url': f'https://example.test/{i}-bad.m3u8'},
                    {'protocol': 'hls', 'url': f'https://example.test/{i}-next.m3u8'}
                ]
            }
            row['checkedAt'] = datetime.now().timestamp() * 1000
            rows.append(row)
            
        context, change_callback = self.create_test_context(grid, rows, config)
        
        # Wait for initial setup
        await asyncio.sleep(0.02)  # Wait 20ms
        
        # Save reference to unchanged element
        untouched = grid.children[1].children[1].src
        self.assertIn('first', grid.children[0].children[1].src)
        
        # Trigger retry for tile 0
        if change_callback[0]:
            change_callback[0]({'tlc-overview-retry-0': {'newValue': {'handle': 'user0', 'nonce': 1}}}, 'session')
            
        await asyncio.sleep(0.02)  # Wait 20ms
        
        # Assertions after retry
        self.assertIn('next', grid.children[0].children[1].src)
        self.assertEqual(grid.children[1].children[1].src, untouched)
        
        # Try with different handle (should not change)
        if change_callback[0]:
            change_callback[0]({'tlc-overview-retry-0': {'newValue': {'handle': 'other', 'nonce': 2}}}, 'session')
            
        await asyncio.sleep(0.01)  # Wait 10ms
        self.assertIn('next', grid.children[0].children[1].src)
        
        # Update media list and trigger row change
        rows[0]['media'] = [{'protocol': 'hls', 'url': 'https://example.test/only.m3u8'}]
        rows[0]['checkedAt'] = datetime.now().timestamp() * 1000
        
        if change_callback[0]:
            change_callback[0]({'tlc-overview-row-0': {}}, 'session')
            
        await asyncio.sleep(0.01)  # Wait 10ms
        
        # Trigger retry again
        if change_callback[0]:
            change_callback[0]({'tlc-overview-retry-0': {'newValue': {'handle': 'user0', 'nonce': 3}}}, 'session')
            
        await asyncio.sleep(0.01)  # Wait 10ms
        self.assertIn('only', grid.children[0].children[1].src)
    
    async def test_selects_first_online_entries_among_20_reverse_order_and_four_tile_mode(self):
        grid = Element('main')
        config = {'interval': 5, 'expanded': True, 'grid2': True, 'reverse': False, 'autoSort': True}
        
        rows = []
        for i in range(20):
            row = {
                'handle': f'user{i}',
                'status': 'online' if i % 2 == 1 else 'offline',
                'checkedAt': datetime.now().timestamp() * 1000,
                'media': [{'protocol': 'hls', 'url': f'https://example.test/{i}.m3u8'}]
            }
            rows.append(row)
            
        context, change_callback = self.create_test_context(grid, rows, config)
        
        # Wait for initial setup
        await asyncio.sleep(0.02)  # Wait 20ms
        
        # Helper function to get shown indices
        def shown():
            result = []
            for i, tile in enumerate(grid.children[:20]):
                if not tile.hidden:
                    result.append(i)
            return result
            
        # Initial check
        self.assertEqual(shown(), [1, 3, 5, 7])
        
        # Change to reverse mode
        config['reverse'] = True
        if change_callback[0]:
            change_callback[0]({'tlc-overview-config': {}}, 'local')
            
        await asyncio.sleep(0.02)  # Wait 20ms
        self.assertEqual(shown(), [13, 15, 17, 19])
        self.assertEqual(grid.children[19].style.get('order', ''), '0')
        
        # Change to 9-tile mode
        config['grid2'] = False
        if change_callback[0]:
            change_callback[0]({'tlc-overview-config': {}}, 'local')
            
        await asyncio.sleep(0.02)  # Wait 20ms
        self.assertEqual(len(shown()), 9)
        self.assertEqual(grid.children[19].style.get('order', ''), '0')
        
        # Change to expanded false
        config['expanded'] = False
        if change_callback[0]:
            change_callback[0]({'tlc-overview-config': {}}, 'local')
            
        await asyncio.sleep(0.02)  # Wait 20ms
        self.assertEqual(shown(), [1, 3, 5, 7])

if __name__ == '__main__':
    unittest.main()
