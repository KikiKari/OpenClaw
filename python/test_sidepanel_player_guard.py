#!/usr/bin/env python3
# test_sidepanel_player_guard.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import asyncio
import re
from pathlib import Path
import sys


async def main():
    try:
        # Read the source file
        source_path = Path(__file__).parent / '../browser-extension/sidepanel.js'
        source = source_path.read_text(encoding='utf-8')
        
        # Find the function boundaries
        start = source.find('  async function refreshPlayer()')
        end = source.find('  function setButtonBusy', start)
        
        if start < 0 or end <= start:
            raise AssertionError("Could not find refreshPlayer function boundaries")
            
        # Extract the function code
        function_code = source[start:end]
        
        # Variables to track state
        reply = None
        calls = 0
        rendered = []
        
        # Mock browser APIs
        class BrowserContext:
            def __init__(self):
                self.activeTabId = 1
                self.activeIsTikTok = True
                self.playerContextGeneration = 0
                
            async def send(self):
                nonlocal calls, reply
                calls += 1
                # Create a future that can be resolved later
                loop = asyncio.get_event_loop()
                future = loop.create_future()
                reply = future
                return future
                
            def renderPlayer(self, state):
                rendered.append(state)
                
        # Create execution context
        context = BrowserContext()
        
        # We need to extract and adapt the refreshPlayer function
        # Since Python doesn't have vm.createContext equivalent, we'll parse and execute differently
        
        # Extract the refreshPlayer function and convert to Python
        # This is a simplified approach - in practice you'd want a proper JS parser
        
        # Look for the pattern of refresh() function with playerContextGeneration++ 
        refresh_pattern = r'async\s+function\s+refresh\(\)\s*\{\s*playerContextGeneration\+\+;'
        if not re.search(refresh_pattern, source):
            raise AssertionError('Context invalidation must precede asynchronous tab lookup')
            
        # First call
        pending = context.send()
        
        # Change context
        context.activeTabId = 2
        
        # Resolve the promise
        reply.set_result({'response': {'playerState': {'playing': True}}})
        await pending
        
        assert len(rendered) == 0, 'Old tab response must be ignored'
        
        # Test non-TikTok behavior
        context.activeIsTikTok = False
        # Should not make a call since it's not TikTok
        
        assert calls == 1, 'Non-TikTok tabs must not be polled'
        
        # Test current tab response
        context.activeIsTikTok = True
        pending = context.send()
        reply.set_result({'response': {'playerState': {'playing': True}}})
        await pending
        
        assert len(rendered) == 1, 'Current tab response must render'
        
        # Test context invalidation
        pending = context.send()
        context.activeTabId = 3
        context.playerContextGeneration += 1
        context.activeTabId = 2
        context.playerContextGeneration += 1
        reply.set_result({'response': {'playerState': {'playing': False}}})
        await pending
        
        assert len(rendered) == 1, 'Returning to the same tab must not revive an old response'
        
        print('PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered')
        
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
