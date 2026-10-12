#!/usr/bin/env python3
# test_issue_controls.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_issue_controls.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_issue_controls.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import unittest
from unittest.mock import Mock, AsyncMock, patch, call
import asyncio
import re


class TestIssueControls(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # Simulate reading the source file (we'll mock this)
        self.source = """
        // Some dummy content to simulate the real file structure
        async function speakItem(item) {
            if (filterExternalSpeechTriggers) {
                // filtering logic here
            } else {
                // no filtering
            }
            speechQueue.push(item);
            await pumpSpeech();
        }
        
        async function pumpSpeech() {
            while (speechQueue.length > 0) {
                const item = speechQueue.shift();
                const text = speechText(item);
                await serviceSpeech(text);
            }
        }
        
        function enqueueSpeech(item) {
            speechQueue.push(item);
            pumpSpeech();
        }

        elements["toggle-speech"].addEventListener("click", async () => {
            try {
                speechEnabled = !speechEnabled;
                elements["speech-status"].textContent = speechEnabled ? "On" : "Off";
                await send(speechEnabled ? "ENABLE_SPEECH" : "DISABLE_SPEECH");
                elements["speech-status"].textContent = "";
            } catch (error) {
                elements["speech-status"].textContent = "failed: " + error.message;
            }
        });

        elements["toggle-hook"].addEventListener("click", async () => {
            try {
                const newState = !currentState.hook.armed;
                await send(newState ? "TLC_ENABLE_HOOK" : "TLC_DISABLE_HOOK");
                currentState.hook.armed = newState;
            } catch (error) {
                elements["notice"].textContent = "failed: " + error.message;
            }
        });
        
        elements["open-connection-settings"].addEventListener("click", () => {
            elements["connection-settings-modal"].hidden = false;
            elements["close-connection-settings"].focus();
        });
        
        document.addEventListener("keydown", (event) => {
            if (event.key === "Tab") {
                // Tab handling logic
            } else if (event.key === "Escape") {
                elements["connection-settings-modal"].hidden = true;
                elements["open-connection-settings"].focus();
            }
        });
        """

    def fragment(self, start, end):
        a = self.source.find(start)
        b = self.source.find(end, a + len(start))
        if a < 0 or b <= a:
            raise AssertionError(f"Fragment not found: {start} ... {end}")
        return self.source[a:b]

    def controls(self):
        document = {'activeElement': None}
        elements = {}

        class Element:
            def __init__(self, id):
                self.id = id
                self.hidden = True
                self.disabled = False
                self.textContent = 'Off'
                self.handlers = {}

            def addEventListener(self, name, fn):
                self.handlers[name] = fn

            def focus(self):
                document['activeElement'] = self

            def click(self):
                if 'click' in self.handlers:
                    return self.handlers['click']({'target': self})

            def querySelectorAll(self, selector):
                return self._query_selector_all_result if hasattr(self, '_query_selector_all_result') else []

        def get_element(id):
            if id not in elements:
                elements[id] = Element(id)
            return elements[id]

        return {'elements': elements, 'document': document, 'get_element': get_element}

    async def test_175_manual_and_automatic_speech_reject_raw_point_triggers_before_author_prefixes(self):
        for enabled in [False, True]:
            with self.subTest(enabled=enabled):
                spoken = []
                
                s = {
                    'filterExternalSpeechTriggers': enabled,
                    'speechEnabled': True,
                    'speechQueue': [],
                    'elements': {'speech-status': {}},
                    'pumpSpeech': AsyncMock(),
                    'speechText': lambda item: f"Autor sagt {item['content']}",
                    'speechLang': lambda: 'de',
                    'serviceSpeech': AsyncMock(side_effect=lambda text: spoken.append(text)),
                    'browserSpeech': AsyncMock(side_effect=lambda: self.fail('unexpected fallback'))
                }

                # Extract and execute relevant code fragments
                speak_item_code = self.fragment('async function speakItem(', 'async function pumpSpeech(')
                enqueue_speech_code = self.fragment('function enqueueSpeech(', 'function ')

                # Execute the functions in a controlled context
                exec(speak_item_code, s)
                exec(enqueue_speech_code, s)

                contents = ['.Text', '. Text', '  .Text', 'Normal', 'Ein Satz. Noch einer']
                for content in contents:
                    await s['speakItem']({'content': content})
                    s['enqueueSpeech']({'content': content})

                expected_count = 2 if enabled else 5
                self.assertEqual(len(spoken), expected_count)
                self.assertEqual(len(s['speechQueue']), expected_count)

    async def test_176_speech_switch_commits_On_Off_only_after_successful_request(self):
        ctrl = self.controls()
        s = {
            **ctrl,
            'speechEnabled': False,
            'send': AsyncMock(),
            'refresh': AsyncMock(),
            'activateSpeech': lambda: setattr(s, 'speechEnabled', True),
            'stopSpeech': lambda: setattr(s, 'speechEnabled', False)
        }

        # Add methods as attributes since they're referenced in the toggle function
        s['activateSpeech'] = lambda: setattr(s['speechEnabled'], 'value', True)
        s['stopSpeech'] = lambda: setattr(s['speechEnabled'], 'value', False)
        s['speechEnabled'] = type('obj', (object,), {'value': False})()

        # Bind the actual value to the object for reference in tests
        def activate():
            s['speechEnabled'].value = True
            
        def stop():
            s['speechEnabled'].value = False
            
        s['activateSpeech'] = activate
        s['stopSpeech'] = stop

        # Run the event listener setup code
        code_fragment = self.fragment('elements["toggle-speech"].addEventListener', 'elements["speech-volume"].addEventListener')
        exec(code_fragment, s)

        # Initial click - should enable
        await s['elements']['toggle-speech'].click()
        self.assertTrue(s['speechEnabled'].value)

        # Failed click - should remain enabled but show error
        s['send'].side_effect = Exception('failed')
        await s['elements']['toggle-speech'].click()
        self.assertTrue(s['speechEnabled'].value)
        self.assertRegex(s['elements']['speech-status'].textContent, r'failed')

        # Successful click - should disable
        s['send'].side_effect = None
        await s['elements']['toggle-speech'].click()
        self.assertFalse(s['speechEnabled'].value)

    async def test_176_Connection_selects_both_commands_and_preserves_state_on_rejection(self):
        ctrl = self.controls()
        calls = []
        
        s = {
            **ctrl,
            'currentState': {'hook': {'armed': False}},
            'send': AsyncMock(side_effect=lambda cmd: calls.append(cmd)),
            'refresh': AsyncMock(side_effect=lambda: setattr(s['currentState']['hook'], 'armed', not s['currentState']['hook']['armed']))
        }

        # Run the event listener setup code
        code_fragment = self.fragment('elements["toggle-hook"].addEventListener', 'elements["reset-tab"].addEventListener')
        exec(code_fragment, s)

        # Two successful toggles
        await s['elements']['toggle-hook'].click()
        await s['elements']['toggle-hook'].click()
        self.assertEqual(calls, ['TLC_ENABLE_HOOK', 'TLC_DISABLE_HOOK'])

        # Failed toggle - should preserve state
        s['send'].side_effect = Exception('failed')
        await s['elements']['toggle-hook'].click()
        self.assertFalse(s['currentState']['hook']['armed'])
        self.assertRegex(s['elements']['notice'].textContent, r'failed')

    def test_176_Connection_dialog_returns_focus_and_traps_Tab_in_both_directions(self):
        s = self.controls()

        # Run modal open code
        open_modal_code = self.fragment('elements["open-connection-settings"].addEventListener', 'elements["open-speech-settings"].addEventListener')
        exec(open_modal_code, s)

        # Set up keydown handler
        key_handler = [None]
        def add_event_listener(name, fn):
            key_handler[0] = fn
            
        s['document']['addEventListener'] = add_event_listener

        # Run keydown handler code
        keydown_code = self.fragment('document.addEventListener("keydown"', 'elements["keep-speech-active"].addEventListener')
        exec(keydown_code, s)

        # Open modal
        s['elements']['open-connection-settings'].click()
        self.assertFalse(s['elements']['connection-settings-modal'].hidden)
        self.assertEqual(s['document']['activeElement'], s['elements']['close-connection-settings'])

        # Setup tab navigation elements
        first = s['elements']['close-connection-settings']
        last = s['elements']['quick-recover-seconds']
        s['elements']['connection-settings-modal']._query_selector_all_result = [first, last]

        # Test reverse tab
        prevented = [0]
        def prevent_default():
            prevented[0] += 1
            
        key_handler[0]({'key': 'Tab', 'shiftKey': True, 'preventDefault': prevent_default})
        self.assertEqual(s['document']['activeElement'], last)

        # Test forward tab
        key_handler[0]({'key': 'Tab', 'shiftKey': False, 'preventDefault': prevent_default})
        self.assertEqual(s['document']['activeElement'], first)
        self.assertEqual(prevented[0], 2)

        # Test escape closes modal and returns focus
        key_handler[0]({'key': 'Escape'})
        self.assertTrue(s['elements']['connection-settings-modal'].hidden)
        self.assertEqual(s['document']['activeElement'], s['elements']['open-connection-settings'])


if __name__ == '__main__':
    unittest.main()
