#!/usr/bin/env python3
# test_scanner_limits.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_scanner_limits.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_scanner_limits.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import asyncio
import json
import os
import sys
from types import SimpleNamespace


# Mock classes and functions to simulate JavaScript environment
class MockDate:
    @staticmethod
    def now():
        return 0


class MockMouseEvent:
    pass


def mock_set_timeout(fn):
    fn()
    return 1


class MockWindow:
    def __init__(self):
        self.scrollX = 0
        self.scrollY = 0
        self.innerHeight = 800

    def scrollTo(self):
        pass

    def scrollBy(self):
        pass


class MockLocation:
    def __init__(self, href):
        self.href = href


class MockCore:
    pass


def recommendation_cards():
    return [
        SimpleNamespace(
            handle=f"creator{i}",
            card=SimpleNamespace(
                scrollIntoView=lambda: None,
                dispatchEvent=lambda: None
            )
        )
        for i in range(301)
    ]


def recommendation_item(e, p):
    return SimpleNamespace(
        handle=e.handle,
        position=p,
        title="x" * 300
    )


def text(s):
    return str(s)


# Global variables to store updates
updates = []


def emit(type, p):
    global updates
    updates.append(json.loads(json.dumps(p)))


async def emit_recommendation_progress(r, status, items):
    global updates
    updates.append(json.loads(json.dumps({"status": status, "items": items})))


async def run_test():
    global updates

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    sources = [
        ["browser-extension/content.js", "  function explicitCardSummary", True],
        ["mobile-shared/webview-bridge.js", "  function primaryVideo", False]
    ]

    # Import content-core module
    sys.path.insert(0, os.path.join(root, "browser-extension"))
    try:
        import content_core
        core_module = content_core
    except ImportError:
        # Create a mock if the module doesn't exist
        core_module = MockCore()

    for file, end, browser in sources:
        with open(os.path.join(root, file), "r", encoding="utf-8") as f:
            source = f.read()

        start_index = source.find("  async function scanRecommendations(run)")
        end_index = source.find(end, start_index)
        code = source[start_index:end_index]

        assert len(code) > 100, "Code segment too short"

        for n in [1, 50, 51, 299, 300, 301]:
            updates = []
            cards = recommendation_cards()
            run = SimpleNamespace(
                limit=min(n, 300),
                sourceUrl="https://www.tiktok.com/@creator/live",
                runId="test",
                cancelled=False
            )

            # Create execution context
            context = {
                "root": {},
                "scrollX": 0,
                "scrollY": 0,
                "innerHeight": 800,
                "location": MockLocation(run.sourceUrl),
                "Date": MockDate,
                "MouseEvent": MockMouseEvent,
                "setTimeout": mock_set_timeout,
                "window": MockWindow(),
                "scrollTo": lambda: None,
                "scrollBy": lambda: None,
                "activeRecommendationScan": run,
                "RECOMMENDATION_SCAN_MAX_ROUNDS": 12,
                "RECOMMENDATION_SCAN_MAX_MS": 45000,
                "core": core_module,
                "recommendationCards": recommendation_cards,
                "recommendationItem": recommendation_item,
                "text": text,
                "emit": emit,
                "emitRecommendationProgress": emit_recommendation_progress
            }

            # Execute the code in the context
            exec(code, context)
            
            # Run the scanRecommendations function
            if 'scanRecommendations' in context:
                await context['scanRecommendations'](run)

            assert updates[-1]["status"] == "complete"
            assert len(updates[-1]["items"]) == min(n, 300)
            assert updates[-1]["items"][-1]["position"] == min(n, 300)

        print(f"PASS synthetic production scan loop: {file}; 1,50,51,299,300,301")


if __name__ == "__main__":
    asyncio.run(run_test())
