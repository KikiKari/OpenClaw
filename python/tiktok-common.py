#!/usr/bin/env python3
# tiktok-common.js — portiert nach python
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-common.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

"""
Shared TikTok LIVE safety contract: handle normalization, per-CPU load
preflight, exact account LIVE selectors, strict HTTPS TikTok-CDN FLV
validation, and normalized extractor statuses.
"""

import json
import os
import re
import sys
from urllib.parse import urlparse


DEFAULT_MAX_LOAD_PER_CPU = 1.5
USERNAME_PATTERN = re.compile(r'^[A-Za-z0-9._]{1,24}$')
FAILURE_STATUSES = {'offline', 'restricted', 'overloaded', 'dependency_missing', 'technical_error'}


def normalize_username(raw):
    """Normalize a TikTok username by removing leading @ symbols and validating format."""
    username = str(raw or '').strip().lstrip('@')
    if not USERNAME_PATTERN.match(username):
        raise ValueError('Invalid TikTok username; expected 1-24 letters, digits, dots, or underscores')
    return username


def load_state(env=None):
    """Check system load against configured limits."""
    if env is None:
        env = os.environ
    
    # Get CPU count (minimum 1)
    try:
        cpu_count = max(1, len(os.sched_getaffinity(0)))
    except AttributeError:
        # Fallback for systems without sched_getaffinity
        cpu_count = max(1, os.cpu_count() or 1)
    
    # Get observed load per CPU
    if 'TIKTOK_TEST_LOAD_PER_CPU' in env:
        observed = float(env['TIKTOK_TEST_LOAD_PER_CPU'])
    else:
        # Get 1-minute load average
        load_avg = os.getloadavg()[0]
        observed = load_avg / cpu_count if cpu_count > 0 else load_avg
    
    # Get maximum allowed load per CPU
    if 'TIKTOK_MAX_LOAD_PER_CPU' in env:
        maximum = float(env['TIKTOK_MAX_LOAD_PER_CPU'])
    else:
        maximum = DEFAULT_MAX_LOAD_PER_CPU
    
    if not (isinstance(observed, (int, float)) and isinstance(maximum, (int, float))) or maximum <= 0:
        raise ValueError('Invalid TikTok load configuration')
    
    return {
        'overloaded': observed > maximum,
        'load_per_cpu': round(observed, 3),
        'maximum': maximum
    }


def enforce_load_limit(method):
    """Exit with error code if system is overloaded."""
    state = load_state()
    if not state['overloaded']:
        return state
    
    error_result = {
        'status': 'overloaded',
        'method': method,
        'load_per_cpu': state['load_per_cpu'],
        'maximum': state['maximum'],
        'message': 'Host is overloaded; retry on another node or later'
    }
    
    print(json.dumps(error_result), file=sys.stderr)
    sys.exit(75)


def live_href_selectors(username):
    """Generate CSS selectors for live href links."""
    href = f'/@{username}/live'
    return [f'a[href="{href}"]', f'a[href^="{href}?"]']


def is_allowed_stream_url(value):
    """Validate if URL is an allowed TikTok stream URL."""
    try:
        url = urlparse(value)
        hostname = url.hostname.lower() if url.hostname else ''
        
        # Check protocol is HTTPS
        if url.scheme != 'https':
            return False
            
        # Check path contains .flv
        if '.flv' not in url.path.lower():
            return False
            
        # Check hostname matches TikTok CDN pattern
        return bool(re.search(r'(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$', hostname))
        
    except Exception:
        return False


def is_successful_stream_response(status, value):
    """Check if stream response is successful and from allowed source."""
    return (isinstance(status, int) and 
            200 <= status < 300 and 
            is_allowed_stream_url(value))


# Order matters: longer keys first so `_uhd_60` never matches as `hd_60`/`hd`
QUALITY_URL_PATTERN = re.compile(r'_(uhd_60|hd_60|origin|hd|sd|ld|ao)\.(?:flv|m3u8)')


def quality_key_from_url(value):
    """Extract quality key from URL."""
    try:
        url = urlparse(value)
        match = QUALITY_URL_PATTERN.search(url.path.lower())
        return match.group(1) if match else None
    except Exception:
        return None


def normalize_extractor_result(value, method, username):
    """Normalize extractor result to standard format."""
    technical_error = {
        'success': False,
        'status': 'technical_error',
        'method': method,
        'username': username,
        'message': 'invalid extractor result'
    }
    
    # Validate basic structure
    if not isinstance(value, dict):
        return technical_error
    
    # Handle successful case
    if value.get('success') is True:
        if value.get('status') != 'live' or not is_allowed_stream_url(value.get('url', '')):
            return technical_error
        return {**value, 'success': True, 'status': 'live'}
    
    # Handle failure case
    if value.get('success') is not False:
        return technical_error
    
    # Build result with defaults
    result = {
        **value,
        'success': False,
        'status': value.get('status') if value.get('status') in FAILURE_STATUSES else 'technical_error',
        'method': value.get('method', method) if isinstance(value.get('method'), str) else method,
        'username': value.get('username', username) if isinstance(value.get('username'), str) else username
    }
    
    # Remove stream-related fields
    result.pop('url', None)
    result.pop('streams', None)
    result.pop('allUrls', None)
    
    return result


def classify_final_failure(results):
    """Classify final failure status from multiple results."""
    statuses = set()
    for result in results:
        if result and result.get('status') in FAILURE_STATUSES:
            statuses.add(result['status'])
    
    priority_order = ['overloaded', 'restricted', 'technical_error', 'offline', 'dependency_missing']
    for status in priority_order:
        if status in statuses:
            return status
    
    return 'technical_error'


def exit_code_for_result(result):
    """Get appropriate exit code for result."""
    if result and result.get('success') is True and result.get('status') == 'live':
        return 0
    if result and result.get('status') == 'overloaded':
        return 75
    if result and result.get('status') in ['offline', 'restricted']:
        return 1
    return 2


def classify_direct_live_state(params):
    """Classify direct live state based on page content."""
    username = params['username']
    current_path = params['currentPath']
    title = params.get('title', '')
    body_text = params.get('bodyText', '')
    successful_stream_response = params.get('successfulStreamResponse', False)
    
    expected_path = f'/@{username}/live'
    
    if current_path != expected_path:
        return {'status': 'offline', 'reason': 'target live page redirected'}
    
    if successful_stream_response:
        return {'status': 'live', 'reason': 'successful TikTok CDN stream response'}
    
    normalized_body = re.sub(r'\s+', ' ', str(body_text or '')).lower()
    normalized_title = str(title or '').lower()
    account_live_title = f'(@{username.lower()}) is live' in normalized_title
    
    ended_markers = [
        'live has ended',
        'das live ist beendet',
        'live wurde beendet',
        'dieses live ist beendet',
        'stream has ended'
    ]
    
    if any(marker in normalized_body for marker in ended_markers):
        return {'status': 'offline', 'reason': 'target live page reports ended stream'}
    
    restriction_markers = [
        'dieses live enthält themen, die von einigen als unangenehm empfunden werden könnten',
        'melde dich an, um das beste aus deiner tiktok-erfahrung herauszuholen',
        'bei tiktok anmelden',
        'melde dich an für das volle live-erlebnis',
        'melde dich an für das vollständige erlebnis',
        'this live may contain content that could be uncomfortable',
        'log in to tiktok',
        'log in for the full live experience',
        'mature content',
        'age-restricted',
        'viewer discretion'
    ]
    
    if account_live_title and any(marker in normalized_body for marker in restriction_markers):
        return {'status': 'restricted', 'reason': 'target live page requires authentication'}
    
    if account_live_title:
        return {
            'status': 'restricted',
            'reason': 'target is live but no accessible media response was available'
        }
    
    return {'status': 'offline', 'reason': 'no account-specific live signal'}


def forced_offline(method, username):
    """Check if forced offline mode is enabled."""
    if os.environ.get('TIKTOK_TEST_OFFLINE') != '1':
        return False
    
    error_result = {
        'success': False,
        'status': 'offline',
        'method': method,
        'username': username,
        'message': 'forced offline test mode'
    }
    
    print(json.dumps(error_result), file=sys.stderr)
    return True
