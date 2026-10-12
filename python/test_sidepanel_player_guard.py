#!/usr/bin/env python3
# test_sidepanel_player_guard.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import asyncio
import os
import re
from unittest.mock import MagicMock


async def main():
    # Read the source file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_path = os.path.join(script_dir, '../browser-extension/sidepanel.js')
    with open(source_path, 'r', encoding='utf-8') as f:
        source = f.read()

    # Extract the relevant function code
    start = source.find('  async function refreshPlayer()')
    end = source.find('  function setButtonBusy', start)
    if start < 0 or end <= start:
        raise AssertionError("Could not find refreshPlayer function boundaries")

    func_code = source[start:end]

    # Check for context invalidation pattern
    if not re.search(r'async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;', source):
        raise AssertionError('Context invalidation must precede asynchronous tab lookup')

    # Set up mock environment
    reply = None
    calls = 0
    rendered = []

    def send_impl():
        nonlocal calls, reply
        calls += 1
        future = asyncio.Future()
        reply = future.set_result
        return future

    def render_player_impl(state):
        rendered.append(state)

    # Create a mock context object
    context = MagicMock()
    context.activeTabId = 1
    context.activeIsTikTok = True
    context.playerContextGeneration = 0
    context.send = send_impl
    context.renderPlayer = render_player_impl

    # Execute the extracted function in the context
    exec(func_code, {'__builtins__': __builtins__}, context.__dict__)

    # Test execution
    pending = context.refreshPlayer()
    context.activeTabId = 2

    # Simulate response from old tab
    reply({'response': {'playerState': {'playing': True}}})
    await pending

    assert len(rendered) == 0, 'Old tab response must be ignored'

    context.activeIsTikTok = False
    await context.refreshPlayer()

    assert calls == 1, 'Non-TikTok tabs must not be polled'

    context.activeIsTikTok = True
    pending = context.refreshPlayer()
    reply({'response': {'playerState': {'playing': True}}})
    await pending

    assert len(rendered) == 1, 'Current tab response must render'

    pending = context.refreshPlayer()
    context.activeTabId = 3
    context.playerContextGeneration += 1
    context.activeTabId = 2
    context.playerContextGeneration += 1
    reply({'response': {'playerState': {'playing': False}}})
    await pending

    assert len(rendered) == 1, 'Returning to the same tab must not revive an old response'

    print('PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered')


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"Error: {e}")
        exit(1)
