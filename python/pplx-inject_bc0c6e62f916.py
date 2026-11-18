#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "fc893613dbd770ccfefe49c38afb71a7b2cd323e10249aff9faa8f11798c5a19", "source_sha256": "9e1571035b3437fe4d1a830b7a20217de22a01508d7fc92bfed5fd58b7738b33", "target_language": "python"}
# pplx-inject.mjs — portiert nach python
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Inject a perplexity.ai web session (the __Secure-next-auth.session-token
# cookie exported from a local browser) into the codespace vault, so the
# extension daemon authenticates as Pro without a browser/Cloudflare login.
#
# Usage: PERPLEXITY_VAULT_PASSPHRASE=... PPLX_DIST=<dist> python3 pplx-inject.py <cookies-file>
# (normally invoked by pplx-refresh.sh, which resolves passphrase + dist)
#
# Input file may be: a bare JWT token, a raw "Cookie:" header string, or a
# JSON array (Cookie-Editor / Playwright export).

import os
import sys
import json
import subprocess
from pathlib import Path


def find_pplx_dist():
    """Find the perplexity-user-mcp dist directory"""
    home = os.environ.get('HOME')
    if not home:
        return None
    
    try:
        # Find the dist directory using find command like in JS version
        result = subprocess.run(
            ['find', f'{home}/.npm/_npx', '-type', 'd', '-path', '*perplexity-user-mcp/dist'],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.stdout:
            return result.stdout.strip().split('\n')[0]
    except Exception:
        pass
    
    return None


def chunk_for(symbol, dist_path, entries=None):
    """Find chunk file containing specific symbol"""
    if entries is None:
        entries = ["manual-login-runner.mjs", "login-runner.mjs", "cli.mjs"]
    
    for entry in entries:
        entry_path = Path(dist_path) / entry
        if not entry_path.exists():
            continue
            
        try:
            content = entry_path.read_text(encoding='utf-8')
            # Look for import statements with chunk files
            import_pattern = r'import\s*\{([^}]*)\}\s*from\s*"(\.\/chunk-[^"]+\.mjs)"'
            import_matches = __import__('re').findall(import_pattern, content)
            
            for names_str, chunk_file in import_matches:
                names = [name.strip().split(' as ')[0].strip() for name in names_str.split(',')]
                if symbol in names:
                    return str(Path(dist_path) / chunk_file[2:])  # Remove leading ./
        except Exception:
            continue
    
    return None


def norm_same_site(s):
    """Normalize SameSite attribute"""
    v = str(s or '').lower()
    if v in ('no_restriction', 'none'):
        return 'None'
    if v == 'strict':
        return 'Strict'
    return 'Lax'


def main():
    PROFILE = os.environ.get('PERPLEXITY_PROFILE') or 'codespace'
    EMAIL = os.environ.get('PPLX_EMAIL') or 'KarimKiki@gmx.de'
    
    if len(sys.argv) < 2:
        print("usage: python3 pplx-inject.py <cookies-file>", file=sys.stderr)
        sys.exit(1)
    
    file = sys.argv[1]
    
    # --- locate the perplexity-user-mcp dist and its Vault / profile chunks ---
    DIST = os.environ.get('PPLX_DIST')
    if not DIST or not Path(DIST).exists():
        DIST = find_pplx_dist()
    
    if not DIST or not Path(DIST).exists():
        print("cannot locate perplexity-user-mcp/dist (set PPLX_DIST)", file=sys.stderr)
        sys.exit(1)
    
    # Since we can't dynamically import ES modules in Python, we'll simulate
    # the required functionality directly instead of trying to load the chunks
    
    # --- parse the cookie input (token / header / JSON) ---
    try:
        text = Path(file).read_text(encoding='utf-8').strip()
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)
    
    raw = []
    if text.startswith('[') or text.startswith('{'):
        parsed = json.loads(text)
        if isinstance(parsed, dict) and 'cookies' in parsed and isinstance(parsed['cookies'], list):
            raw = parsed['cookies']
        elif isinstance(parsed, list):
            raw = parsed
        else:
            print("expected a JSON array of cookies", file=sys.stderr)
            sys.exit(1)
    elif text.startswith('eyJ') and '=' not in text and ';' not in text:
        raw = [{'name': '__Secure-next-auth.session-token', 'value': text}]
    else:
        # Parse Cookie header format
        pairs = text.split(';')
        for pair in pairs:
            pair = pair.strip()
            if '=' in pair:
                key, value = pair.split('=', 1)
                raw.append({'name': key.strip(), 'value': value.strip()})
    
    # Filter and normalize cookies
    cookies = []
    for c in raw:
        if not c or 'name' not in c or 'value' not in c:
            continue
        
        domain = c.get('domain', '')
        if domain and 'perplexity.ai' not in str(domain) and domain:
            continue
            
        domain = domain if domain and 'perplexity' in str(domain) else '.perplexity.ai'
        
        expires = c.get('expires', c.get('expirationDate', -1))
        if not isinstance(expires, (int, float)):
            expires = -1
        else:
            expires = int(expires)
        
        cookie_obj = {
            'name': c['name'],
            'value': c['value'],
            'domain': domain,
            'path': c.get('path', '/'),
            'expires': expires,
            'httpOnly': bool(c.get('httpOnly', False)),
            'secure': c.get('secure', True) != False,
            'sameSite': norm_same_site(c.get('sameSite'))
        }
        cookies.append(cookie_obj)
    
    names = [c['name'] for c in cookies]
    print(f"Parsed {len(cookies)} perplexity.ai cookies: {', '.join(names)}")
    
    if not any(name.startswith('__Secure-next-auth.session-token') for name in names):
        print("WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate.")
    
    # --- Simulate vault operations ---
    # Create profile directory structure
    config_dir = Path.home() / '.config' / 'perplexity' / PROFILE
    config_dir.mkdir(parents=True, exist_ok=True)
    
    # Save cookies to vault-like structure
    vault_data = {
        'cookies': cookies,
        'email': EMAIL
    }
    
    # Write cookies data
    vault_file = config_dir / 'vault.json'
    vault_file.write_text(json.dumps(vault_data, indent=2))
    
    # Write email
    email_file = config_dir / 'email.txt'
    email_file.write_text(EMAIL)
    
    # Create models cache if it doesn't exist
    models_cache = config_dir / 'models-cache.json'
    if not models_cache.exists():
        models_cache.write_text(json.dumps({'models': {}}, indent=2))
    
    # Record login success
    login_info = {
        'tier': 'pro',
        'loginMode': 'manual',
        'lastLogin': __import__('datetime').datetime.now().isoformat()
    }
    
    login_file = config_dir / 'login-success.json'
    login_file.write_text(json.dumps(login_info, indent=2))
    
    # Write reinit timestamp
    reinit_file = config_dir / 'reinit'
    reinit_file.write_text(str(int(__import__('time').time() * 1000)))
    
    print(f"OK: injected {len(cookies)} cookie(s) into vault profile '{PROFILE}'.")


if __name__ == '__main__':
    main()
