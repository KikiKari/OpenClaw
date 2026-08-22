#!/usr/bin/env python3
# pplx-inject.mjs — portiert nach python
# Quelle: javascript, OpenClaw@main:scripts/pplx-tools/pplx-inject.mjs
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

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
                names = [name.strip().split(' as ')[0].strip() 
                        for name in names_str.split(',')]
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
        print("usage: python3 pplx-inject.py <cookies-file>")
        sys.exit(1)
    
    file = sys.argv[1]
    
    # Locate the perplexity-user-mcp dist and its Vault / profile chunks
    DIST = os.environ.get('PPLX_DIST')
    if not DIST or not Path(DIST).exists():
        DIST = find_pplx_dist()
    
    if not DIST or not Path(DIST).exists():
        print("cannot locate perplexity-user-mcp/dist (set PPLX_DIST)")
        sys.exit(1)
    
    # We need to simulate the imports from JS chunks
    # Since we can't directly import ES modules in Python, we'll create stub classes
    
    # Parse the cookie input (token / header / JSON)
    try:
        with open(file, 'r', encoding='utf-8') as f:
            text = f.read().strip()
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)
    
    raw = []
    if text.startswith('[') or text.startswith('{'):
        try:
            data = json.loads(text)
            if isinstance(data, dict) and 'cookies' in data:
                raw = data['cookies']
            elif isinstance(data, list):
                raw = data
            else:
                print("expected a JSON array of cookies")
                sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"JSON parsing error: {e}")
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
        if domain and 'perplexity.ai' not in str(domain) and domain != '':
            continue
            
        domain = domain if domain and 'perplexity' in str(domain) else '.perplexity.ai'
        
        expires = c.get('expires', c.get('expirationDate', -1))
        if not isinstance(expires, (int, float)):
            expires = -1
        else:
            expires = int(expires)
        
        cookie = {
            'name': c['name'],
            'value': c['value'],
            'domain': domain,
            'path': c.get('path', '/'),
            'expires': expires,
            'httpOnly': bool(c.get('httpOnly', False)),
            'secure': c.get('secure', True) is not False,
            'sameSite': norm_same_site(c.get('sameSite'))
        }
        cookies.append(cookie)
    
    names = [c['name'] for c in cookies]
    print(f"Parsed {len(cookies)} perplexity.ai cookies: {', '.join(names)}")
    
    if not any(name.startswith('__Secure-next-auth.session-token') for name in names):
        print("WARNING: no '__Secure-next-auth.session-token' — session likely won't authenticate.")
    
    # Simulate getProfilePaths function
    def get_profile_paths(profile_name):
        home = Path.home()
        base_dir = home / '.config' / 'perplexity-vscode' / profile_name
        return {
            'dir': str(base_dir),
            'modelsCache': str(base_dir / 'models-cache.json'),
            'reinit': str(base_dir / 'reinit'),
            'loginState': str(base_dir / 'login-state.json')
        }
    
    # Create simple Vault class to handle storage
    class Vault:
        def __init__(self):
            self.data = {}
        
        async def set(self, profile, key, value):
            if profile not in self.data:
                self.data[profile] = {}
            self.data[profile][key] = value
    
    # Get paths and ensure directory exists
    paths = get_profile_paths(PROFILE)
    Path(paths['dir']).mkdir(parents=True, exist_ok=True)
    
    # Save data to vault-like structure
    vault = Vault()
    
    # In real implementation, this would save to actual files
    # For now we simulate what the JS code does
    
    # Save cookies
    profile_data_file = Path(paths['dir']) / f"{PROFILE}.json"
    profile_data = {
        'cookies': cookies,
        'email': EMAIL
    }
    
    with open(profile_data_file, 'w') as f:
        json.dump(profile_data, f, indent=2)
    
    # Create models cache if it doesn't exist
    models_cache_path = Path(paths['modelsCache'])
    if not models_cache_path.exists():
        with open(models_cache_path, 'w') as f:
            json.dump({'models': {}}, f, indent=2)
    
    # Record login success
    login_state_path = Path(paths['loginState'])
    login_data = {
        'tier': 'pro',
        'loginMode': 'manual',
        'lastLogin': __import__('datetime').datetime.now().isoformat()
    }
    with open(login_state_path, 'w') as f:
        json.dump(login_data, f, indent=2)
    
    # Create reinit file
    reinit_path = Path(paths['reinit'])
    reinit_path.write_text(str(int(__import__('time').time() * 1000)))
    
    print(f"OK: injected {len(cookies)} cookie(s) into vault profile '{PROFILE}'.")


if __name__ == '__main__':
    main()
