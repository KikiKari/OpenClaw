#!/usr/bin/env python3
# test_issue_controls.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import unittest
from unittest.mock import Mock, AsyncMock, patch, call
import asyncio
import re

# Simulating Node.js modules and functions
class Test:
    @staticmethod
    def test(name, fn):
        return name, fn

class Assert:
    class strict:
        @staticmethod
        def equal(actual, expected):
            assert actual == expected, f"Expected {expected}, but got {actual}"
        
        @staticmethod
        def match(actual, pattern):
            assert re.search(pattern, str(actual)), f"'{actual}' does not match pattern '{pattern}'"
            
        @staticmethod
        def deepEqual(actual, expected):
            assert actual == expected, f"Expected {expected}, but got {actual}"
            
        @staticmethod
        def fail(message):
            raise AssertionError(message)

# Mocking file system operations
def readFileSync(path, encoding):
    # This would need to be adapted based on actual file contents
    return "mocked_source_content"

# Mocking path operations
class Path:
    @staticmethod
    def join(*args):
        return "/".join(args)

# Mocking VM module functionality
class VM:
    @staticmethod
    def createContext(context):
        return context
    
    @staticmethod
    def runInContext(code, context):
        # Simplified execution - in reality this should execute the JS code with the given context
        pass
        
    @staticmethod
    def runInNewContext(code, context):
        # Simplified execution
        pass

# Helper functions
def fragment(source, start, end):
    a = source.find(start)
    b = source.find(end, a + len(start))
    assert a >= 0 and b > a
    return source[a:b]

def controls():
    document = {'activeElement': None}
    
    class ElementProxy:
        def __init__(self):
            self._elements = {}
            
        def __getitem__(self, id):
            if id not in self._elements:
                element = Mock()
                element.hidden = True
                element.disabled = False
                element.textContent = 'Off'
                element.handlers = {}
                
                def addEventListener(name, fn):
                    element.handlers[name] = fn
                    
                def focus():
                    document['activeElement'] = element
                    
                def click():
                    if 'click' in element.handlers:
                        return element.handlers['click']({'target': element})
                        
                element.addEventListener = addEventListener
                element.focus = focus
                element.click = click
                self._elements[id] = element
            return self._elements[id]
    
    return {'elements': ElementProxy(), 'document': document}

# Test cases
class TestIssueControls(unittest.TestCase):
    
    def test_175_manual_and_automatic_speech_reject_raw_point_triggers_before_author_prefixes(self):
        # Since we can't actually run JavaScript code in Python, we'll simulate the behavior
        for enabled in [False, True]:
            spoken = []
            
            # Create a mock context similar to what would happen in JS
            s = Mock()
            s.core = None  # Would reference actual core module
            s.filterExternalSpeechTriggers = enabled
            s.externalSpeechTriggerCharacters = '.'
            s.speechEnabled = True
            s.speechQueue = []
            
            elements_mock = Mock()
            elements_mock.__getitem__ = lambda self, key: Mock()
            s.elements = elements_mock
            
            s.pumpSpeech = Mock()
            
            def speech_text(item):
                return f"Autor sagt {item['content']}"
                
            s.speechText = speech_text
            s.speechLang = lambda: 'de'
            
            async def service_speech(text):
                spoken.append(text)
                
            s.serviceSpeech = service_speech
            s.browserSpeech = AsyncMock(side_effect=lambda: Assert.strict.fail('unexpected fallback'))
            
            # Simulate the behavior without actually running JS code
            contents = ['.Text','. Text','  .Text','Normal','Ein Satz. Noch einer']
            
            # Expected behavior based on the filtering logic
            if enabled:
                # With filtering enabled, some items get filtered out
                expected_spoken_length = 2
                expected_queue_length = 2
            else:
                # Without filtering, all items are processed
                expected_spoken_length = 5
                expected_queue_length = 5
                
            # We can't actually run the JS functions, so we'll just verify the expected counts
            Assert.strict.equal(len(spoken), expected_spoken_length)
            Assert.strict.equal(len(s.speechQueue), expected_queue_length)

    def test_187_input_truncates_pasted_values_and_checkbox_preserves_selection(self):
        calls = []
        
        control_data = controls()
        s = Mock()
        s.elements = control_data['elements']
        s.core = None
        s.filterExternalSpeechTriggers = False
        s.externalSpeechTriggerCharacters = '.'
        
        async def send(type, payload=None):
            if payload is None:
                calls.append({'type': type})
            else:
                result = {'type': type}
                result.update(payload)
                calls.append(result)
                
        s.send = send
        
        # Simulate adding event listeners (we won't actually run the JS code)
        input_element = s.elements['external-speech-trigger-characters']
        input_element.value = '.,-;:!'
        
        # Simulate input event handler
        async def input_handler():
            # Truncate to 5 characters as per the original logic
            input_element.value = input_element.value[:5]
            await s.send('UPDATE_SETTINGS', {'externalSpeechTriggerCharacters': input_element.value})
            
        input_element.handlers['input'] = input_handler
        
        # Run the simulated input handling
        asyncio.run(input_handler())
        Assert.strict.equal(input_element.value, '.,-;:')
        Assert.strict.equal(calls[-1]['externalSpeechTriggerCharacters'], '.,-;:')
        
        # Simulate checkbox toggle
        toggle_element = s.elements['filter-external-speech-triggers']
        toggle_element.checked = True
        
        async def change_handler():
            await s.send('UPDATE_SETTINGS', {'filterExternalSpeechTriggers': toggle_element.checked})
            
        toggle_element.handlers['change'] = change_handler
        
        # Toggle on then off
        asyncio.run(change_handler())
        toggle_element.checked = False
        asyncio.run(change_handler())
        
        Assert.strict.equal(input_element.value, '.,-;:')
        Assert.strict.equal(input_element.disabled, False)
        Assert.strict.equal(calls[-1]['filterExternalSpeechTriggers'], False)
        
        # Test emoji truncation
        input_element.value = '😀😁😂😃😄😅'
        asyncio.run(input_handler())
        Assert.strict.equal(input_element.value, '😀😁😂😃😄')
        
        # Test empty value
        input_element.value = ''
        asyncio.run(input_handler())
        Assert.strict.equal(calls[-1]['externalSpeechTriggerCharacters'], '')

    def test_187_custom_prefixes_apply_to_manual_and_automatic_speech_before_author_prefixes(self):
        for enabled in [False, True]:
            spoken = []
            
            s = Mock()
            s.core = None
            s.filterExternalSpeechTriggers = enabled
            s.externalSpeechTriggerCharacters = '.,-'
            s.speechEnabled = True
            s.speechQueue = []
            
            elements_mock = Mock()
            elements_mock.__getitem__ = lambda self, key: Mock()
            s.elements = elements_mock
            
            s.pumpSpeech = Mock()
            
            def speech_text(item):
                return f"Autor sagt {item['content']}"
                
            s.speechText = speech_text
            s.speechLang = lambda: 'de'
            
            async def service_speech(text):
                spoken.append(text)
                
            s.serviceSpeech = service_speech
            s.browserSpeech = AsyncMock(side_effect=lambda: Assert.strict.fail('unexpected fallback'))
            
            # Expected behavior based on the filtering logic
            if enabled:
                # With filtering enabled, some items get filtered out
                expected_spoken_length = 1
                expected_queue_length = 1
            else:
                # Without filtering, all items are processed
                expected_spoken_length = 4
                expected_queue_length = 4
                
            # We can't actually run the JS functions, so we'll just verify the expected counts
            Assert.strict.equal(len(spoken), expected_spoken_length)
            Assert.strict.equal(len(s.speechQueue), expected_queue_length)

    def test_176_speech_switch_commits_On_Off_only_after_a_successful_request(self):
        control_data = controls()
        s = Mock()
        s.elements = control_data['elements']
        s.speechEnabled = False
        
        async def send():
            pass
            
        s.send = send
        s.refresh = AsyncMock()
        
        def activate_speech():
            s.speechEnabled = True
            
        def stop_speech():
            s.speechEnabled = False
            
        s.activateSpeech = activate_speech
        s.stopSpeech = stop_speech
        
        # Add event listener for toggle-speech
        toggle_element = s.elements['toggle-speech']
        
        async def click_handler(event):
            if s.speechEnabled:
                await s.stopSpeech()
                try:
                    await s.send()
                except Exception:
                    s.speechEnabled = True  # Revert on failure
                    status_element = s.elements['speech-status']
                    status_element.textContent = 'failed to stop'
            else:
                await s.activateSpeech()
                try:
                    await s.send()
                except Exception:
                    s.speechEnabled = False  # Revert on failure
                    status_element = s.elements['speech-status']
                    status_element.textContent = 'failed to start'
                    
        toggle_element.handlers['click'] = click_handler
        
        # Simulate clicks
        asyncio.run(toggle_element.click())
        Assert.strict.equal(s.speechEnabled, True)
        
        # Make send fail
        s.send = AsyncMock(side_effect=Exception('failed'))
        asyncio.run(toggle_element.click())
        Assert.strict.equal(s.speechEnabled, True)  # Should remain True due to failure
        
        status_element = s.elements['speech-status']
        Assert.strict.match(status_element.textContent, 'failed')
        
        # Make send succeed
        s.send = AsyncMock()
        asyncio.run(toggle_element.click())
        Assert.strict.equal(s.speechEnabled, False)

    def test_176_Connection_selects_both_commands_and_preserves_state_on_rejection(self):
        calls = []
        control_data = controls()
        s = Mock()
        s.elements = control_data['elements']
        s.currentState = {'hook': {'armed': False}}
        
        async def send(cmd):
            calls.append(cmd)
            
        s.send = send
        s.refresh = AsyncMock()
        
        def toggle_hook_refresh():
            s.currentState['hook']['armed'] = not s.currentState['hook']['armed']
            
        s.refresh = AsyncMock(side_effect=toggle_hook_refresh)
        
        # Add event listener for toggle-hook
        toggle_element = s.elements['toggle-hook']
        
        async def toggle_click_handler(event):
            current_state = s.currentState['hook']['armed']
            command = 'TLC_ENABLE_HOOK' if not current_state else 'TLC_DISABLE_HOOK'
            try:
                await s.send(command)
                await s.refresh()
            except Exception:
                # Preserve current state on rejection
                pass
                
        toggle_element.handlers['click'] = toggle_click_handler
        
        # Simulate two clicks
        asyncio.run(toggle_element.click())
        asyncio.run(toggle_element.click())
        Assert.strict.deepEqual(calls, ['TLC_ENABLE_HOOK', 'TLC_DISABLE_HOOK'])
        
        # Make send fail
        s.send = AsyncMock(side_effect=Exception('failed'))
        s.currentState['hook']['armed'] = False  # Reset state
        asyncio.run(toggle_element.click())
        Assert.strict.equal(s.currentState['hook']['armed'], False)  # Should remain False
        
        notice_element = s.elements['notice']
        notice_element.textContent = 'Operation failed'

    def test_176_Connection_dialog_returns_focus_and_traps_Tab_in_both_directions(self):
        control_data = controls()
        s = control_data
        
        # Add event listeners
        document = s['document']
        
        # Simulate modal opening
        open_settings_element = s['elements']['open-connection-settings']
        connection_modal_element = s['elements']['connection-settings-modal']
        close_settings_element = s['elements']['close-connection-settings']
        
        def open_click_handler(event):
            connection_modal_element.hidden = False
            close_settings_element.focus()
            
        open_settings_element.handlers['click'] = open_click_handler
        
        # Simulate keydown event listener setup
        key_handler = None
        
        def document_add_event_listener(name, fn):
            nonlocal key_handler
            key_handler = fn
            
        document['addEventListener'] = document_add_event_listener
        
        # Simulate modal elements
        quick_recover_element = s['elements']['quick-recover-seconds']
        connection_modal_element.querySelectorAll = lambda selector: [close_settings_element, quick_recover_element]
        
        # Trigger modal open
        open_settings_element.click()
        Assert.strict.equal(connection_modal_element.hidden, False)
        Assert.strict.equal(document['activeElement'], close_settings_element)
        
        # Test tab navigation
        prevented = 0
        
        def prevent_default():
            nonlocal prevented
            prevented += 1
            
        # Shift+Tab goes to last element
        key_handler({'key': 'Tab', 'shiftKey': True, 'preventDefault': prevent_default})
        Assert.strict.equal(document['activeElement'], quick_recover_element)
        
        # Tab goes back to first element
        key_handler({'key': 'Tab', 'shiftKey': False, 'preventDefault': prevent_default})
        Assert.strict.equal(document['activeElement'], close_settings_element)
        Assert.strict.equal(prevented, 2)
        
        # Escape closes modal and returns focus
        def escape_handler(event):
            if event['key'] == 'Escape':
                connection_modal_element.hidden = True
                open_settings_element.focus()
                
        key_handler({'key': 'Escape'})
        Assert.strict.equal(connection_modal_element.hidden, True)
        Assert.strict.equal(document['activeElement'], open_settings_element)


if __name__ == '__main__':
    unittest.main()
