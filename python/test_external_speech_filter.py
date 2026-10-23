#!/usr/bin/env python3
# test_external_speech_filter.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import unittest

# Simulating the required functions from content-core.js
def should_filter_external_speech_trigger(text, enabled, prefixes='.'):
    if not enabled:
        return False
    if isinstance(prefixes, str):
        prefixes = set(prefixes)
    else:
        prefixes = set('.')
    
    trimmed_text = text.lstrip()
    return any(trimmed_text.startswith(prefix) for prefix in prefixes)

def normalize_external_speech_trigger_characters(chars):
    if chars is None:
        return '.'
    if not chars:
        return ''
    
    # Remove spaces and common quotes
    result = ''.join(c for c in chars if c not in ' "\'')
    
    # Limit to first 5 characters (Unicode scalar values)
    return result[:5]

class TestExternalSpeechFilter(unittest.TestCase):
    
    def test_basic_filtering(self):
        test_cases = []
        for enabled in [False, True]:
            for text in ['.Text', '. Text', '  .Text', '\t\n. Text', 'Normal', 'Ein Satz. Noch einer', '']:
                test_cases.append((enabled, text))
        
        for enabled, text in test_cases:
            with self.subTest(enabled=enabled, text=text):
                expected = enabled and text.lstrip().startswith('.')
                actual = should_filter_external_speech_trigger(text, enabled)
                self.assertEqual(actual, expected, f"Failed for enabled={enabled}, text='{text}'")
    
    def test_custom_prefixes(self):
        """0PE-187: individual literal prefixes, commas and semicolons are not separators"""
        for enabled in [False, True]:
            # These should return True when enabled
            positive_cases = ['.Hallo', ',Hallo', '- Hallo', '  , Hallo']
            for text in positive_cases:
                with self.subTest(enabled=enabled, text=text, case='positive'):
                    expected = enabled if enabled else False
                    actual = should_filter_external_speech_trigger(text, enabled, '.,-')
                    self.assertEqual(actual, expected)
            
            # These should always return False
            negative_cases = ['Hallo, zusammen.', 'Normal-Text', 'Hallo', '.']
            for text in negative_cases:
                with self.subTest(enabled=enabled, text=text, case='negative'):
                    actual = should_filter_external_speech_trigger(text, enabled, ',-')
                    self.assertFalse(actual)
            
            # Semicolon test
            with self.subTest(enabled=enabled, text=';Hallo', case='semicolon'):
                expected = enabled if enabled else False
                actual = should_filter_external_speech_trigger(';Hallo', enabled, ';')
                self.assertEqual(actual, expected)
                
            # Bracket tests
            with self.subTest(enabled=enabled, text='[Hallo', case='bracket_positive'):
                expected = enabled if enabled else False
                actual = should_filter_external_speech_trigger('[Hallo', enabled, '[')
                self.assertEqual(actual, expected)
                
            with self.subTest(enabled=enabled, text='Hallo', case='bracket_negative'):
                actual = should_filter_external_speech_trigger('Hallo', enabled, '[')
                self.assertFalse(actual)
    
    def test_unicode_and_normalization(self):
        """0PE-187: five Unicode scalar triggers, paste sanitization and explicit empty selection"""
        self.assertEqual(normalize_external_speech_trigger_characters(None), '.')
        self.assertEqual(normalize_external_speech_trigger_characters(''), '')
        self.assertEqual(normalize_external_speech_trigger_characters('.,-;:'), '.,-;:')
        self.assertEqual(normalize_external_speech_trigger_characters(' a1 "\'.,- '), '.,-')
        self.assertEqual(normalize_external_speech_trigger_characters('😀😁😂😃😄😅'), '😀😁😂😃😄')
        
        self.assertTrue(should_filter_external_speech_trigger('😀Hallo', True, '😀'))
        self.assertFalse(should_filter_external_speech_trigger('.Hallo', True, ''))
        self.assertFalse(should_filter_external_speech_trigger('.Hallo', True, ','))

if __name__ == '__main__':
    unittest.main()
