#!/usr/bin/env python3
# tiktok-common.test.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.test.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

import os
import re
import sys
import asyncio
from urllib.parse import urlparse
from playwright.async_api import async_playwright


def normalize_username(username):
    """Normalize a TikTok username by removing leading/trailing whitespace and '@' symbol"""
    if username is None:
        raise ValueError("Username cannot be None")
    
    normalized = username.strip()
    if normalized.startswith('@'):
        normalized = normalized[1:]
    
    if ';' in normalized or '?' in normalized:
        raise ValueError("Username contains invalid characters")
    
    return normalized


def live_href_selectors(username):
    """Generate CSS selectors for finding live stream links for a given username"""
    normalized = normalize_username(username)
    return [
        f'a[href="/@{normalized}/live"]',
        f'a[href^="/@{normalized}/live?"]'
    ]


def load_state(env_vars):
    """Check system load state based on environment variables"""
    try:
        test_load_per_cpu = float(env_vars.get('TIKTOK_TEST_LOAD_PER_CPU', '0'))
        max_load_per_cpu = float(env_vars.get('TIKTOK_MAX_LOAD_PER_CPU', '1.0'))
        overloaded = test_load_per_cpu > max_load_per_cpu
    except (ValueError, TypeError):
        overloaded = False
    
    return {'overloaded': overloaded}


def is_allowed_stream_url(url):
    """Check if a stream URL is from an allowed TikTok domain and uses HTTPS"""
    try:
        parsed = urlparse(url)
        if parsed.scheme != 'https':
            return False
        
        allowed_domains = [
            '.tiktokcdn.com',
            '.tiktokcdn-eu.com',
            '.tiktokcdn-us.com'
        ]
        
        for domain in allowed_domains:
            if parsed.netloc.endswith(domain):
                return True
        
        return False
    except Exception:
        return False


def is_successful_stream_response(status_code, url):
    """Check if a stream response indicates a successful connection"""
    if not is_allowed_stream_url(url):
        return False
    
    return status_code in [200, 206]


def normalize_extractor_result(result, extractor_name, username):
    """Normalize the result from a stream extractor"""
    normalized = result.copy()
    
    # Handle streamlink specific normalization
    if extractor_name == 'streamlink':
        if 'success' in normalized:
            if isinstance(normalized['success'], bool):
                if not normalized['success'] and normalized.get('status') == 'offline':
                    normalized['url'] = None
                elif normalized['success'] and normalized.get('status') == 'live':
                    pass
                else:
                    normalized['status'] = 'technical_error'
            else:
                normalized['status'] = 'technical_error'
                normalized['success'] = False
        else:
            normalized['status'] = 'technical_error'
            normalized['success'] = False
    
    return normalized


def classify_final_failure(results):
    """Classify the final failure state from multiple results"""
    if not results:
        return 'technical_error'
    
    # Prefer 'offline' over other statuses
    for result in results:
        if result.get('status') == 'offline':
            return 'offline'
    
    # Return first non-offline status or technical_error
    for result in results:
        status = result.get('status')
        if status and status != 'offline':
            return status
    
    return 'technical_error'


def exit_code_for_result(result):
    """Determine exit code based on result status"""
    status = result.get('status', 'technical_error')
    if status == 'restricted':
        return 1
    elif status == 'technical_error':
        return 2
    elif status == 'offline':
        return 3
    elif status == 'dependency_missing':
        return 4
    else:
        return 0


def classify_direct_live_state(state):
    """Classify live state based on direct page inspection"""
    username = state.get('username')
    current_path = state.get('currentPath', '')
    title = state.get('title', '')
    body_text = state.get('bodyText', '')
    successful_stream_response = state.get('successfulStreamResponse', False)
    
    expected_path = f'/@{normalize_username(username)}/live'
    if current_path != expected_path:
        return {'status': 'technical_error'}
    
    if 'LIVE has ended' in body_text:
        return {'status': 'offline'}
    
    if ('This live stream may contain content that may be inappropriate' in body_text or
        'Dieses LIVE enthält Themen, die unangenehm sein könnten' in body_text):
        return {'status': 'restricted'}
    
    if successful_stream_response:
        return {'status': 'live'}
    
    return {'status': 'offline'}


async def main():
    # Test normalize_username
    assert normalize_username('@example_creator') == 'example_creator'
    assert normalize_username(' example_creator ') == 'example_creator'
    try:
        normalize_username('example_creator;id')
        assert False, "Should have raised ValueError"
    except ValueError:
        pass
    
    # Test live_href_selectors
    selectors = live_href_selectors('example_creator')
    expected = [
        'a[href="/@example_creator/live"]',
        'a[href^="/@example_creator/live?"]'
    ]
    assert selectors == expected
    
    # Test load_state
    env_vars = {
        'TIKTOK_TEST_LOAD_PER_CPU': '2',
        'TIKTOK_MAX_LOAD_PER_CPU': '1.5'
    }
    assert load_state(env_vars)['overloaded'] == True
    
    # Test is_allowed_stream_url
    assert is_allowed_stream_url('https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x') == True
    assert is_allowed_stream_url('https://attacker.example/path/tiktokcdn/video.flv') == False
    assert is_allowed_stream_url('http://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv') == False
    
    # Test is_successful_stream_response
    allowed_url = 'https://pull-flv-f77-tt04.tiktokcdn-eu.com/game/live.flv?sign=x'
    assert is_successful_stream_response(200, allowed_url) == True
    assert is_successful_stream_response(206, allowed_url) == True
    assert is_successful_stream_response(404, allowed_url) == False
    
    # Test normalize_extractor_result
    result = normalize_extractor_result(
        {'success': 'false', 'status': 'offline'},
        'streamlink',
        'example_creator'
    )
    assert result['status'] == 'technical_error'
    
    result = normalize_extractor_result(
        {'success': True, 'status': 'live'},
        'streamlink',
        'example_creator'
    )
    assert result['status'] == 'technical_error'
    
    result = normalize_extractor_result(
        {'success': False, 'status': 'offline', 'url': allowed_url},
        'streamlink',
        'example_creator'
    )
    assert result['status'] == 'offline'
    assert 'url' not in result or result['url'] is None
    
    result = normalize_extractor_result(
        {'success': True, 'status': 'live', 'url': allowed_url},
        'streamlink',
        'example_creator'
    )
    assert result['status'] == 'live'
    
    # Test classify_final_failure
    assert classify_final_failure([
        {'status': 'offline'},
        {'status': 'dependency_missing'}
    ]) == 'offline'
    
    # Test exit_code_for_result
    assert exit_code_for_result({'success': False, 'status': 'restricted'}) == 1
    assert exit_code_for_result({'success': False, 'status': 'technical_error'}) == 2
    
    # Test classify_direct_live_state
    state = {
        'username': 'example_creator',
        'currentPath': '/@example_creator/live',
        'title': 'Example (@example_creator) is LIVE - TikTok LIVE',
        'bodyText': 'Dieses LIVE enthält Themen, die unangenehm sein könnten.',
        'successfulStreamResponse': False
    }
    assert classify_direct_live_state(state)['status'] == 'restricted'
    
    state['bodyText'] = 'LIVE has ended'
    assert classify_direct_live_state(state)['status'] == 'offline'
    
    state['bodyText'] = 'Suggested LIVE creators'
    state['successfulStreamResponse'] = True
    assert classify_direct_live_state(state)['status'] == 'live'
    
    # Test with Playwright
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        try:
            page = await browser.new_page()
            await page.set_content("""
                <aside><a href="/@other_creator/live"><span>LIVE</span></a></aside>
                <main><header><h1>example_creator</h1></header></main>
            """)
            
            selectors = live_href_selectors('example_creator')
            own_live_link = await page.query_selector(selectors[0])
            if not own_live_link:
                own_live_link = await page.query_selector(selectors[1]) if len(selectors) > 1 else None
            
            assert own_live_link is None, 'sidebar LIVE for another account must not match'
        finally:
            await browser.close()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
