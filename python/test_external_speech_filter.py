#!/usr/bin/env python3
# test_external_speech_filter.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import unittest
from content_core import shouldFilterExternalSpeechTrigger as filter

class TestExternalSpeechFilter(unittest.TestCase):
    def test_filter_combinations(self):
        for enabled in [False, True]:
            for text in ['.Text', '. Text', '  .Text', '\t\n. Text', 'Normal', 'Ein Satz. Noch einer', '']:
                with self.subTest(enabled=enabled, text=text):
                    expected = enabled and text.lstrip().startswith('.')
                    self.assertEqual(filter(text, enabled), expected)

if __name__ == '__main__':
    unittest.main()
