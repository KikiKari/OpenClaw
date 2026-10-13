#!/usr/bin/env python3
# tiktok-get-stream.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-get-stream.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

"""
Enhanced TikTok LIVE URL extractor.

Order: Playwright response interception, streamlink, then yt-dlp. Every
result is schema-normalized and must be an allowed HTTPS TikTok-CDN FLV
URL. Fallbacks use fixed argument arrays, bounded output, timeouts, and
process-group cleanup.

Exit 0 = URL, 1 = offline/restricted/no URL, 2 = dependency/technical
failure, 75 = overloaded before Playwright startup.
"""

import asyncio
import json
import os
import random
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

# Import from tiktok_common.py
sys.path.append(str(Path(__file__).parent))
from tiktok_common import (
    classify_final_failure,
    enforce_load_limit,
    exit_code_for_result,
    forced_offline,
    is_successful_stream_response,
    normalize_extractor_result,
    normalize_username,
    quality_key_from_url
)

FALLBACK_TIMEOUT_MS = 45000
FALLBACK_MAX_OUTPUT = 1024 * 1024


def log(message):
    print(message, file=sys.stderr)


async def run_fallback(script_path, args):
    try:
        proc = await asyncio.create_subprocess_exec(
            'bash', str(script_path), *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout_data = b''
        stderr_data = b''
        overflow = False
        
        async def collect(stream, target_data):
            nonlocal stdout_data, stderr_data, overflow
            while True:
                try:
                    chunk = await stream.read(4096)
                    if not chunk:
                        break
                    next_data = target_data + chunk
                    if len(next_data) > FALLBACK_MAX_OUTPUT:
                        overflow = True
                        return target_data
                    target_data = next_data
                except:
                    break
            return target_data
            
        # Start reading both streams concurrently
        stdout_task = asyncio.create_task(collect(proc.stdout, stdout_data))
        stderr_task = asyncio.create_task(collect(proc.stderr, stderr_data))
        
        try:
            await asyncio.wait_for(proc.wait(), timeout=FALLBACK_TIMEOUT_MS/1000)
            stdout_data = await stdout_task
            stderr_data = await stderr_task
        except asyncio.TimeoutError:
            try:
                proc.terminate()
                await asyncio.sleep(3)
                if proc.returncode is None:
                    proc.kill()
            except:
                pass
            stdout_data = await stdout_task
            stderr_data = await stderr_task
            return {
                'code': 2,
                'stdout': stdout_data.decode('utf-8', errors='ignore'),
                'stderr': (stderr_data.decode('utf-8', errors='ignore') + '\nfallback timeout').strip()
            }
            
        if overflow:
            return {'code': 2, 'stdout': '', 'stderr': 'fallback output exceeded limit'}
            
        return {
            'code': proc.returncode if proc.returncode is not None else 2,
            'stdout': stdout_data.decode('utf-8', errors='ignore').strip(),
            'stderr': stderr_data.decode('utf-8', errors='ignore').strip()
        }
        
    except Exception as e:
        return {'code': 2, 'stdout': '', 'stderr': f'fallback error: {str(e)}'}


def parse_fallback_result(method, username, execution):
    for text in [execution.get('stdout', ''), execution.get('stderr', '')]:
        if not text:
            continue
        try:
            value = json.loads(text)
            if isinstance(value, dict):
                return normalize_extractor_result(value, method, username)
        except (json.JSONDecodeError, TypeError):
            pass
    return normalize_extractor_result({
        'success': False,
        'status': 'overloaded' if execution.get('code') == 75 else 'technical_error',
        'method': method,
        'username': username,
        'message': execution.get('stderr', '') or f"fallback exited {execution.get('code', 'unknown')}"
    }, method, username)


def playwright_preflight():
    try:
        # Check if playwright is available
        import playwright
        from playwright.sync_api import sync_playwright
        
        with sync_playwright() as p:
            executable = p.chromium.executable_path
            if not os.access(executable, os.X_OK):
                raise PermissionError(f"Playwright Chromium not executable: {executable}")
            return {'ok': True, 'executable': executable}
    except Exception as e:
        return {
            'ok': False,
            'status': 'dependency_missing',
            'error': f'Playwright Chromium unavailable: {str(e)}'
        }


def human_delay(min_ms=2000, max_ms=4000):
    return random.randint(min_ms, max_ms)


def handle_popups(page):
    """DSGVO + Login-Popups schließen"""
    closed = False
    
    # DSGVO
    dsgvo_selectors = [
        'button:has-text("Verstanden")', '[data-e2e="cookie-banner-accept"]',
        'button:has-text("Accept")', 'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")', 'button:has-text("Allow all")',
        'button:has-text("Accept all")', '[data-testid="cookie-policy-banner-accept"]'
    ]
    
    for sel in dsgvo_selectors:
        try:
            btn = page.wait_for_selector(sel, state='visible', timeout=3000)
            if btn:
                btn.click()
                time.sleep(human_delay(1000, 2000) / 1000)
                closed = True
                break
        except:
            pass
    
    # Login Pop-up 1: "Bei TikTok anmelden" → X-Button
    try:
        login_text = page.query_selector('text="Bei TikTok anmelden"')
        if login_text:
            close_btn = page.query_selector('div[role="dialog"] [aria-label="Close"], div[role="dialog"] button[aria-label="Schließen"], div[role="dialog"] svg')
            if close_btn:
                close_btn.click()
                time.sleep(human_delay(1000, 2000) / 1000)
                closed = True
    except:
        pass
    
    # Login Pop-up 2: "Jetzt nicht" Button
    try:
        skip_btn = page.query_selector('button:has-text("Jetzt nicht"), button:has-text("Not now")')
        if skip_btn:
            skip_btn.click()
            time.sleep(human_delay(1000, 2000) / 1000)
            closed = True
    except:
        pass
    
    return closed


def check_restrictions(page):
    """Prüfe ob Stream eingeschränkt ist (nach Popup-Handling)"""
    restriction_texts = [
        'text="Bei TikTok anmelden"',
        'text=/Dieses LIVE enthält Themen/',
        'text="Melde dich an für das vollständige Erlebnis"',
        'text=/Melde dich an für das volle/',
        'text="Log in to TikTok"',
        'text=/mature content/',
        'text=/age-restricted/'
    ]
    
    for sel in restriction_texts:
        try:
            el = page.query_selector(sel)
            if el and el.is_visible():
                reason = sel.replace('text=', '').replace('/', '').replace('"', '')
                return {'restricted': True, 'reason': reason}
        except:
            pass
    return {'restricted': False, 'reason': None}


def extract_with_playwright(username, quality_preference):
    """Playwright-basierte FLV-Extraktion"""
    preflight = playwright_preflight()
    if not preflight['ok']:
        return {
            'success': False,
            'method': 'playwright',
            'status': preflight['status'],
            'error': preflight['error']
        }
    
    try:
        from playwright.sync_api import sync_playwright
        
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--disable-dev-shm-usage']
            )
            
            context = browser.new_context(
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                viewport={'width': 1920, 'height': 1080}
            )
            
            page = context.new_page()
            collected_urls = []
            
            def on_response(response):
                url = response.url
                if len(collected_urls) < 100 and is_successful_stream_response(response.status, url):
                    collected_urls.append({
                        'url': url,
                        'status': response.status,
                        'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
                    })
            
            page.on('response', on_response)
            
            # Navigiere direkt zu /live
            page.goto(f'https://www.tiktok.com/@{username}/live', wait_until='domcontentloaded', timeout=30000)
            
            # Popups schließen
            handle_popups(page)
            
            # Warte auf Seitenaufbau
            time.sleep(human_delay(3000, 5000) / 1000)
            try:
                page.wait_for_load_state('networkidle', timeout=10000)
            except:
                pass
            
            # Prüfe auf Einschränkungen
            restrictions = check_restrictions(page)
            if restrictions['restricted']:
                log(f"Playwright: Stream restricted - {restrictions['reason']}")
                return {
                    'success': False,
                    'method': 'playwright',
                    'status': 'restricted',
                    'restricted': True,
                    'reason': restrictions['reason']
                }
            
            # Versuche Video abzuspielen falls nötig
            try:
                video = page.query_selector('video')
                if video:
                    video.evaluate('(v) => v.play()')
            except:
                pass
            
            # Warte auf FLV-URLs (Stream muss laden)
            time.sleep(human_delay(8000, 12000) / 1000)
            
            # Zweiter Versuch Popups zu schließen
            handle_popups(page)
            time.sleep(human_delay(3000, 5000) / 1000)
            
            # Nochmal Restrictions prüfen
            restrictions2 = check_restrictions(page)
            if restrictions2['restricted']:
                log(f"Playwright: Stream became restricted after wait - {restrictions2['reason']}")
                return {
                    'success': False,
                    'method': 'playwright',
                    'status': 'restricted',
                    'restricted': True,
                    'reason': restrictions2['reason']
                }
            
            # URLs auswerten
            if len(collected_urls) == 0:
                log('Playwright: No FLV URLs captured via network monitoring.')
                return {
                    'success': False,
                    'method': 'playwright',
                    'status': 'offline',
                    'restricted': False,
                    'reason': 'No FLV URLs found'
                }
            
            # Deduplizieren und nach Qualität sortieren
            unique_urls_map = {}
            for item in collected_urls:
                base_url = item['url'].split('?')[0]
                unique_urls_map[base_url] = item
            unique_urls = list(unique_urls_map.values())
            
            # Qualitäts-Präferenz anwenden
            quality_order = {
                'original': ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
                '1080p60': ['_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
                '720p60': ['_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
                '720p': ['_hd.flv', '_sd.flv', '_ld.flv'],
                '540p': ['_sd.flv', '_ld.flv'],
                '360p': ['_ld.flv'],
                'auto': ['_origin.flv', '_uhd_60.flv', '_hd_60.flv', '_hd.flv', '_sd.flv', '_ld.flv'],
            }.get(quality_preference, [])
            
            best_url = None
            for suffix in quality_order:
                for url_item in unique_urls:
                    if suffix in url_item['url']:
                        best_url = url_item
                        break
                if best_url:
                    break
                    
            if not best_url and quality_preference in ('auto', 'original'):
                best_url = unique_urls[0] if unique_urls else None
                
            if not best_url:
                return {
                    'success': False,
                    'method': 'playwright',
                    'status': 'quality_unavailable',
                    'reason': f'Requested quality {quality_preference} was not captured in this fresh browser session'
                }
            
            return {
                'success': True,
                'status': 'live',
                'method': 'playwright',
                'username': username,
                'url': best_url['url'],
                'quality': quality_preference,
                'allUrls': [{'url': item['url'], 'quality': quality_key_from_url(item['url'])} for item in unique_urls],
                'allUrlsCount': len(unique_urls),
                'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
            }
            
    except Exception as e:
        log(f'Playwright error: {str(e)}')
        return {
            'success': False,
            'method': 'playwright',
            'status': 'technical_error',
            'error': str(e)
        }
    finally:
        try:
            browser.close()
        except:
            pass


async def try_streamlink(username, quality):
    script_path = Path(__file__).parent / 'extraction-methods' / 'extract-tiktok-streamlink.sh'
    execution = await run_fallback(script_path, [username, quality, '--json'])
    return parse_fallback_result('streamlink', username, execution)


async def try_yt_dlp(username, quality):
    script_path = Path(__file__).parent / 'extraction-methods' / 'extract-tiktok-yt-dlp.sh'
    yt_format = {
        'original': 'hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld',
        '1080p60': 'hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
        '720p60': 'hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld',
        '720p': 'hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld',
        '540p': 'hls-sd/hls-ld/flv-sd/flv-ld',
        '360p': 'hls-ld/flv-ld',
        'auto': 'hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld',
    }.get(quality, '')
    
    execution = await run_fallback(script_path, [username, yt_format, '--json'])
    return parse_fallback_result('yt-dlp', username, execution)


async def get_stream_url(username, quality_preference='auto'):
    timestamp = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    
    # --- 1. Playwright ---
    log(f'[1/3] Trying Playwright for @{username}...')
    pw_result = extract_with_playwright(username, quality_preference)
    if pw_result.get('success'):
        pw_result['timestamp'] = timestamp
        return pw_result
    if pw_result.get('status') in ('restricted', 'overloaded'):
        return pw_result
    log(f"Playwright result: {pw_result.get('reason', pw_result.get('error', 'failed'))}")
    
    # --- 2. Streamlink ---
    log(f'[2/3] Trying streamlink for @{username} (quality: {quality_preference})...')
    sl_result = await try_streamlink(username, quality_preference)
    if sl_result.get('success'):
        return sl_result
    if sl_result.get('status') in ('restricted', 'overloaded'):
        return sl_result
    log(f"Streamlink result: {sl_result.get('message', sl_result.get('error', 'failed'))}")
    
    # --- 3. yt-dlp ---
    log(f'[3/3] Trying yt-dlp for @{username}...')
    yt_result = await try_yt_dlp(username, quality_preference)
    if yt_result.get('success'):
        return yt_result
    if yt_result.get('status') in ('restricted', 'overloaded'):
        return yt_result
    log(f"yt-dlp result: {yt_result.get('message', yt_result.get('error', 'failed'))}")
    
    # --- Alle fehlgeschlagen ---
    status = classify_final_failure([pw_result, sl_result, yt_result])
    return {
        'success': False,
        'status': status,
        'username': username,
        'message': 'All extraction methods failed (Playwright, streamlink, yt-dlp).',
        'playwrightReason': pw_result.get('reason', pw_result.get('error')),
        'streamlinkReason': sl_result.get('message', sl_result.get('error')),
        'ytdlpReason': yt_result.get('message', yt_result.get('error')),
        'timestamp': timestamp
    }


async def main():
    if len(sys.argv) < 2:
        print('Usage: python3 tiktok-get-stream.py <username> [quality: original|1080p60|720p60|720p|540p|360p|auto] [--json]', file=sys.stderr)
        sys.exit(1)
    
    try:
        cli_username = normalize_username(sys.argv[1])
    except ValueError as e:
        print(str(e), file=sys.stderr)
        sys.exit(64)
        
    enforce_load_limit('playwright_streamlink_ytdlp')
    if forced_offline('playwright_streamlink_ytdlp', cli_username):
        sys.exit(1)
        
    cli_quality = 'auto'
    args = sys.argv[2:]
    for arg in args:
        if not arg.startswith('--'):
            if arg in ['original', '1080p60', '720p60', '720p', '540p', '360p', 'auto']:
                cli_quality = arg
            else:
                print('Invalid quality; expected original, 1080p60, 720p60, 720p, 540p, 360p, or auto', file=sys.stderr)
                sys.exit(64)
                
    cli_json = '--json' in args
    
    result = await get_stream_url(cli_username, cli_quality)
    if cli_json:
        print(json.dumps(result, indent=2))
    else:
        if result.get('success'):
            print(result['url'])
        else:
            print(result.get('message', ''), file=sys.stderr)
    
    sys.exit(exit_code_for_result(result))


if __name__ == '__main__':
    asyncio.run(main())
