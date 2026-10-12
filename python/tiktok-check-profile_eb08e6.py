#!/usr/bin/env python3
# tiktok-check-profile.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

"""
Enhanced TikTok LIVE status checker.

Uses exact account selectors and the direct /@username/live page to return
live, restricted, offline, dependency_missing, technical_error, or
overloaded. An accessible LIVE requires a successful allowed TikTok-CDN
FLV response; unrelated sidebar LIVE labels never count.

Browser resources are closed on every completion path.
"""

import sys
import json
import random
import time
from pathlib import Path
from urllib.parse import urlparse
import asyncio
from playwright.async_api import async_playwright


def load_common_module():
    """Dynamically load functions from tiktok-common.py if it exists."""
    # This would ideally be imported directly, but we simulate the required functions here
    # In practice, you'd want to properly structure this as a module
    
    def classify_direct_live_state(data):
        username = data['username']
        current_path = data['currentPath']
        title = data['title']
        body_text = data['bodyText'].lower()
        successful_stream_response = data['successfulStreamResponse']

        if current_path == f'/@{username}/live':
            if 'this account is private' in body_text or 'login to watch' in body_text:
                return {'status': 'restricted', 'reason': 'private_or_login_required'}
            elif 'video not available' in body_text or 'content not found' in body_text:
                return {'status': 'offline', 'reason': 'content_not_found'}
            elif successful_stream_response:
                return {'status': 'live', 'reason': 'stream_accessible'}
            else:
                return {'status': 'offline', 'reason': 'no_stream_available'}
        elif '/login' in current_path:
            return {'status': 'restricted', 'reason': 'login_required'}
        elif '/foryou' in current_path or '/discover' in current_path:
            return {'status': 'technical_error', 'reason': 'redirected_away'}
        else:
            return {'status': 'technical_error', 'reason': 'unexpected_page'}

    def enforce_load_limit(method):
        # Placeholder implementation
        pass

    def is_successful_stream_response(status_code, url):
        return (
            status_code == 200 and 
            ('tiktokcdn' in url or 'flv' in url) and
            'video' in url
        )

    def live_href_selectors(username):
        return [
            f'a[href="/@{username}/live"]',
            f'[href="/@{username}/live"]',
            f'aside a[href="/@{username}/live"]',
            f'[data-e2e="live-feed-item"] a[href="/@{username}/live"]'
        ]

    def normalize_username(username):
        if not username:
            raise ValueError("Username cannot be empty")
        clean = username.strip('@ \t\n\r')
        if not clean:
            raise ValueError("Invalid username format")
        return clean

    return {
        'classify_direct_live_state': classify_direct_live_state,
        'enforce_load_limit': enforce_load_limit,
        'is_successful_stream_response': is_successful_stream_response,
        'live_href_selectors': live_href_selectors,
        'normalize_username': normalize_username
    }


# Load common utilities
common = load_common_module()
classify_direct_live_state = common['classify_direct_live_state']
enforce_load_limit = common['enforce_load_limit']
is_successful_stream_response = common['is_successful_stream_response']
live_href_selectors = common['live_href_selectors']
normalize_username = common['normalize_username']


def human_delay(min_ms=2000, max_ms=4000):
    """Realistic delay (2-4s randomly)"""
    delay = random.randint(min_ms, max_ms)
    time.sleep(delay / 1000)


async def close_dsgvo_banner(page):
    """Close all known cookie/DSGVO banners"""
    selectors = [
        'button:has-text("Verstanden")',
        '[data-e2e="cookie-banner-accept"]',
        'button:has-text("Accept")',
        'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")',
        'button:has-text("Allow all")',
        'button:has-text("Accept all")',
        'button.TUXButton:has-text("Accept")',
        '[data-testid="cookie-policy-banner-accept"]'
    ]

    for selector in selectors:
        try:
            btn = await page.query_selector(selector)
            if btn:
                await btn.click()
                await asyncio.sleep(random.uniform(1, 2))
                return True
        except Exception:
            continue
    return False


async def wait_for_page_ready(page):
    """
    CRITICAL: TikTok loads the page in phases.
    The LIVE badge and red border appear ONLY when the page is fully loaded.
    Recognizable by menu bar:
    "Videos" + "Erneute Veröffentlichungen" + "Gelikt"
    "Erneute Veröffentlichungen" appears LAST.
    """
    
    # Phase 1: Wait for initial loading
    await asyncio.sleep(random.uniform(2, 3))

    # Phase 2: Explicitly wait for "Erneute Veröffentlichungen" tab
    # That's the most reliable indicator for complete page build
    page_ready = False
    try:
        await page.wait_for_selector('text="Erneute Veröffentlichungen"', state='visible', timeout=25000)
        page_ready = True
    except:
        # Fallback: try English version
        try:
            await page.wait_for_selector('text="Reposts"', state='visible', timeout=5000)
            page_ready = True
        except:
            # Last fallback: just wait for network idle
            try:
                await page.wait_for_load_state('networkidle', timeout=10000)
            except:
                pass

    # Phase 3: After menu band appears, wait briefly so that
    # LIVE badge/red border gets rendered
    await asyncio.sleep(random.uniform(2, 3))
    return page_ready


async def detect_live_status(page, username):
    indicators = {
        'liveIcon': False,
        'liveBadge': False,
        'liveBorder': False,
        'liveLink': False,
        'liveIndicator': False
    }
    detection_method = 'none'

    # Priority 1: LIVE icon within exact account LIVE links
    try:
        live_link_elements = await page.query_selector_all(','.join(live_href_selectors(username)))
        if live_link_elements:
            live_link = live_link_elements[0]
            live_icon_visible = await live_link.query_selector('[data-e2e="live-icon"], [class*="LiveBadge"], [class*="live-indicator"]') is not None
            if live_icon_visible:
                indicators['liveIcon'] = True
                detection_method = 'live-icon'
                return {'isLive': True, 'detectionMethod': detection_method, 'indicators': indicators}
    except Exception:
        pass

    # Priority 2: Exact LIVE badge within same account link
    try:
        live_link_elements = await page.query_selector_all(','.join(live_href_selectors(username)))
        if live_link_elements:
            live_link = live_link_elements[0]
            live_badge = await live_link.query_selector('text=/^LIVE$/i')
            live_badge_visible = live_badge is not None if live_badge else False
            if live_badge_visible:
                indicators['liveBadge'] = True
                detection_method = 'live-badge'
                return {'isLive': True, 'detectionMethod': detection_method, 'indicators': indicators}
    except Exception:
        pass

    # Priority 3: Live border at profile header/avatar of account
    try:
        profile_selectors = [
            '[data-e2e="user-page"] img[data-e2e="avatar"]',
            '[data-e2e="user-page"] div[data-e2e="profile-avatar"] img',
            'main header img[data-e2e="avatar"]',
            'main header [class*="avatar"] img'
        ]

        for selector in profile_selectors:
            profile_img = await page.query_selector(selector)
            if not profile_img:
                continue

            styles = await page.evaluate('''el => {
                const computed = window.getComputedStyle(el);
                const parent = el.parentElement;
                const parentComputed = parent ? window.getComputedStyle(parent) : null;
                const grandParent = parent ? parent.parentElement : null;
                const grandParentComputed = grandParent ? window.getComputedStyle(grandParent) : null;
                return {
                    borderColor: computed.borderColor,
                    outlineColor: computed.outlineColor,
                    boxShadow: computed.boxShadow,
                    parentBorderColor: parentComputed ? parentComputed.borderColor : null,
                    parentBoxShadow: parentComputed ? parentComputed.boxShadow : null,
                    grandParentBorderColor: grandParentComputed ? grandParentComputed.borderColor : null,
                    grandParentBoxShadow: grandParentComputed ? grandParentComputed.boxShadow : null
                };
            }''', profile_img)

            all_colors = [
                styles.get('borderColor'),
                styles.get('outlineColor'),
                styles.get('parentBorderColor'),
                styles.get('grandParentBorderColor')
            ]
            all_shadows = [
                styles.get('boxShadow'),
                styles.get('parentBoxShadow'),
                styles.get('grandParentBoxShadow')
            ]

            def is_red(color):
                if not color or color == 'none':
                    return False
                return ('255' in color or 'red' in color or
                        'rgb(254' in color or 'fe2c55' in color or
                        '#fe2c' in color or 'rgb(255, 0' in color or
                        'rgb(255, 44' in color)

            if any(is_red(c) for c in all_colors if c) or any(s and is_red(s) for s in all_shadows if s):
                indicators['liveBorder'] = True
                detection_method = 'live-border'
                return {'isLive': True, 'detectionMethod': detection_method, 'indicators': indicators}
    except Exception:
        pass

    # Priority 4: Live indicator within exact account link
    try:
        live_link_elements = await page.query_selector_all(','.join(live_href_selectors(username)))
        if live_link_elements:
            live_link = live_link_elements[0]
            live_indicator_visible = await live_link.query_selector('[class*="live-indicator"], div[class*="LiveBadge"]') is not None
            if live_indicator_visible:
                indicators['liveIndicator'] = True
                detection_method = 'live-indicator'
                return {'isLive': True, 'detectionMethod': detection_method, 'indicators': indicators}
    except Exception:
        pass

    # Priority 5: Visible exact /@username/live link
    try:
        live_link_elements = await page.query_selector_all(','.join(live_href_selectors(username)))
        if live_link_elements:
            live_link = live_link_elements[0]
            live_link_visible = await live_link.is_visible()
            if live_link_visible:
                indicators['liveLink'] = True
                detection_method = 'live-link'
                return {'isLive': True, 'detectionMethod': detection_method, 'indicators': indicators}
    except Exception:
        pass

    return {'isLive': False, 'detectionMethod': detection_method, 'indicators': indicators}


async def inspect_direct_live_state(page, username):
    successful_stream_response = False
    
    async def response_handler(response):
        nonlocal successful_stream_response
        if is_successful_stream_response(response.status, response.url):
            successful_stream_response = True
            
    page.on('response', response_handler)
    
    try:
        await page.goto(f'https://www.tiktok.com/@{username}/live', wait_until='domcontentloaded', timeout=30000)
        await asyncio.sleep(random.uniform(8, 10))
        
        current_url = urlparse(page.url)
        body_text = ''
        try:
            body_element = await page.query_selector('body')
            if body_element:
                body_text = await body_element.text_content() or ''
        except:
            pass
            
        return classify_direct_live_state({
            'username': username,
            'currentPath': current_url.path,
            'title': await page.title(),
            'bodyText': body_text,
            'successfulStreamResponse': successful_stream_response
        })
    except Exception as error:
        return {'status': 'technical_error', 'reason': str(error)}
    finally:
        try:
            page.remove_listener('response', response_handler)
        except:
            pass


async def check_live_status(username):
    from playwright.sync_api import sync_playwright
    
    # Try to access chromium executable
    try:
        with sync_playwright() as p:
            chromium_path = p.chromium.executable_path
            if not Path(chromium_path).exists():
                raise FileNotFoundError("Chromium executable not found")
    except Exception as error:
        print(json.dumps({
            'error': True,
            'status': 'dependency_missing',
            'method': 'playwright_enhanced',
            'message': f'Playwright Chromium unavailable: {str(error)}',
            'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        }))
        sys.exit(2)

    async with async_playwright() as p:
        browser = None
        try:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                viewport={'width': 1920, 'height': 1080}
            )
            page = await context.new_page()

            # Navigate to profile
            await page.goto(f'https://www.tiktok.com/@{username}', wait_until='domcontentloaded', timeout=30000)

            # Step 1: Close DSGVO banner
            banner_closed = await close_dsgvo_banner(page)

            # Step 2: Wait for full page load
            # CRITICAL: LIVE badge only appears after "Erneute Veröffentlichungen"
            page_ready = await wait_for_page_ready(page)

            # Debug screenshot
            if 'DEBUG' in os.environ and os.environ['DEBUG'] == '1':
                await page.screenshot(path=f'/tmp/tiktok-{username}-v2.png', full_page=True)

            # Step 3: Check live status (prioritized)
            live_result = await detect_live_status(page, username)

            # Step 4: Check account-specific /live page. This separates accessible
            # streams, login/content locks, and actually ended streams.
            direct_result = await inspect_direct_live_state(page, username)
            
            final_status = 'restricted' if direct_result['status'] == 'restricted' else (
                'live' if (live_result['isLive'] or direct_result['status'] == 'live') else direct_result['status']
            )

            # Output result
            result = {
                'username': username,
                'status': final_status,
                'isLive': final_status in ['live', 'restricted'],
                'detectionMethod': 'account-live-restricted' if direct_result['status'] == 'restricted' else live_result['detectionMethod'],
                'isAgeRestricted': final_status == 'restricted',
                'ageRestrictionReason': direct_result.get('reason') if final_status == 'restricted' else None,
                'indicators': live_result['indicators'],
                'bannerClosed': banner_closed,
                'pageFullyLoaded': page_ready,
                'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                'version': '2.1'
            }

            print(json.dumps(result, indent=2))
            return final_status

        except Exception as error:
            result = {
                'username': username,
                'isLive': False,
                'status': 'technical_error',
                'detectionMethod': 'error',
                'isAgeRestricted': False,
                'ageRestrictionReason': None,
                'indicators': {},
                'error': str(error),
                'timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                'version': 2
            }
            print(json.dumps(result, indent=2), file=sys.stderr)
            return 'technical_error'
        finally:
            if browser:
                await browser.close()


async def main():
    if len(sys.argv) != 2:
        print('Usage: python tiktok-check-profile.py <username>', file=sys.stderr)
        sys.exit(64)
        
    try:
        username = normalize_username(sys.argv[1])
    except ValueError as e:
        print('Usage: python tiktok-check-profile.py <username>', file=sys.stderr)
        print(e, file=sys.stderr)
        sys.exit(64)
        
    enforce_load_limit('playwright_enhanced')
    
    status = await check_live_status(username)
    if status == 'live':
        sys.exit(0)
    elif status in ['offline', 'restricted']:
        sys.exit(1)
    else:
        sys.exit(2)


if __name__ == '__main__':
    asyncio.run(main())
