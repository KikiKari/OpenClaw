#!/usr/bin/env python3
# tiktok-get-stream.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway1:skills/tiktok-live/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

"""
TikTok Stream URL Extractor
Führt zuerst den profilgebundenen Status-Checker aus.
Nur bei bestätigtem Live-Status werden FLV-Netzwerk-URLs erfasst.
Offline wird keine Stream-URL ausgegeben.
"""

import asyncio
import json
import os
import platform
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Playwright not installed. Please run: pip install playwright", file=sys.stderr)
    sys.exit(1)

def reject_busy_node():
    limit = os.environ.get('TIKTOK_MAX_LOAD_PER_CPU')
    try:
        limit = float(limit)
    except (TypeError, ValueError):
        return
    
    if limit <= 0:
        return
        
    # Get CPU count
    cpu_count = max(1, os.cpu_count() or 1)
    
    # Get load average (Unix-like systems)
    try:
        if hasattr(os, 'getloadavg'):
            load_avg = os.getloadavg()[0]
        else:
            # Windows fallback
            load_avg = 0
    except OSError:
        load_avg = 0
    
    normalized_load = load_avg / cpu_count if load_avg > 0 else 0
    
    if normalized_load > limit:
        print(f"NODE_BUSY normalizedLoad={normalized_load:.2f} limit={limit}", file=sys.stderr)
        sys.exit(75)

async def verify_live_status(username):
    script_dir = Path(__file__).parent
    checker_path = script_dir / 'tiktok-check-profile.js'
    
    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable, str(checker_path), username,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=os.environ
        )
        
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            return False
            
        if proc.returncode == 0:
            result = json.loads(stdout.decode())
            return result.get('isLive') is True
        else:
            # Try parsing output even on error
            output = stdout or stderr
            if output:
                try:
                    result = json.loads(output.decode())
                    return result.get('isLive') is True
                except json.JSONDecodeError:
                    pass
            return False
            
    except Exception:
        return False

def get_quality_rank(url):
    """Rank URLs by quality based on suffixes or resolution indicators"""
    suffix_ranks = [
        ('_origin.', 600),
        ('_uhd_60.', 550),
        ('_uhd.', 540),
        ('_hd_60.', 500),
        ('_hd.', 450),
        ('_sd.', 350),
        ('_ld.', 250)
    ]
    
    for suffix, rank in suffix_ranks:
        if suffix in url:
            return rank
            
    # Check for resolution pattern like 1080p
    match = re.search(r'(\d+)p', url)
    if match:
        return int(match.group(1))
        
    return 0

async def get_stream_url(username):
    if not await verify_live_status(username):
        error_result = {
            'username': username,
            'isLive': False,
            'error': 'User is not currently live.',
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        }
        print(json.dumps(error_result), file=sys.stderr)
        return False

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )
        page = await context.new_page()
        
        flv_urls = []
        
        async def handle_request(request):
            url = request.url
            if '.flv' in url or 'pull-flv' in url:
                flv_urls.append({
                    'url': url,
                    'type': request.resource_type,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                })
                
        page.on('request', handle_request)
        
        try:
            # Navigate to live page
            await page.goto(f'https://www.tiktok.com/@{username}/live', 
                          wait_until='load', timeout=60000)
            
            # Wait for potential cookie dialogs
            await asyncio.sleep(3)
            
            # Accept cookies if present
            accept_button = await page.query_selector('button[data-e2e="cookie-banner-accept"]')
            if accept_button:
                await accept_button.click()
                await asyncio.sleep(1)
                
            # Wait for stream to load
            await asyncio.sleep(8)
            # Additional wait to capture FLV URLs
            await asyncio.sleep(10)
            
            # Try to trigger video play
            video = await page.query_selector('video')
            if video:
                try:
                    await video.evaluate('v => v.play()')
                    await asyncio.sleep(3)
                except:
                    pass
                    
            await browser.close()
            
            if flv_urls:
                # Deduplicate URLs
                seen_urls = set()
                unique_urls = []
                for item in flv_urls:
                    if item['url'] not in seen_urls:
                        seen_urls.add(item['url'])
                        unique_urls.append(item)
                        
                # Sort by quality
                unique_urls.sort(key=lambda x: get_quality_rank(x['url']), reverse=True)
                
                result = {
                    'username': username,
                    'isLive': True,
                    'streamCount': len(unique_urls),
                    'streams': unique_urls,
                    'vlcCommand': f'vlc "{unique_urls[0]["url"]}"' if unique_urls else None,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                }
                print(json.dumps(result, indent=2))
                return True
            else:
                error_result = {
                    'username': username,
                    'isLive': False,
                    'error': 'No stream URLs found - user may not be live',
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                }
                print(json.dumps(error_result), file=sys.stderr)
                return False
                
        except Exception as e:
            await browser.close()
            error_result = {
                'error': True,
                'message': str(e),
                'timestamp': datetime.utcnow().isoformat() + 'Z'
            }
            print(json.dumps(error_result), file=sys.stderr)
            return False

async def main():
    if len(sys.argv) < 2:
        print('Usage: python tiktok-get-stream.py <username>', file=sys.stderr)
        sys.exit(1)
        
    raw_username = sys.argv[1]
    username = raw_username.lstrip('@')
    
    if not username:
        print('Username must not be empty', file=sys.stderr)
        sys.exit(1)
        
    reject_busy_node()
    
    try:
        success = await get_stream_url(username)
        sys.exit(0 if success else 1)
    except Exception as e:
        error_result = {
            'error': True,
            'message': str(e),
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        }
        print(json.dumps(error_result), file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(main())
