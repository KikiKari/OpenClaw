#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "129ccfd9363a90295ddad01fa6f3adee06916d440b6421783d7ef9e1ed7bf2b0", "source_sha256": "3c82de39b963e31592918456342c499f4e6477d2ee7404f215a5685c6d02674c", "target_language": "python"}
# ios-asc-keychain-setup.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-asc-keychain-setup.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import argparse
import os
import sys
import re
import tempfile
import shutil
import subprocess

def usage():
    print('''Usage:
  scripts/ios-asc-keychain-setup.sh --key-path /path/to/AuthKey_XXXXXX.p8 --issuer-id <issuer-uuid> [options]

Required:
  --key-path <path>      Path to App Store Connect API key (.p8)
  --issuer-id <uuid>     App Store Connect issuer ID

Optional:
  --key-id <id>          API key ID (auto-detected from AuthKey_<id>.p8 if omitted)
  --service <name>       Keychain service name (default: openclaw-asc-key)
  --account <name>       Keychain account name (default: $USER or $LOGNAME)
  --write-env            Upsert non-secret env vars into apps/ios/fastlane/.env
  --env-file <path>      Override env file path used with --write-env
  -h, --help             Show this help

Example:
  scripts/ios-asc-keychain-setup.sh \\
    --key-path "$HOME/keys/AuthKey_ABC1234567.p8" \\
    --issuer-id "00000000-1111-2222-3333-444444444444" \\
    --write-env''')

def upsert_env_line(file_path, key, value):
    tmp_file = None
    try:
        tmp_file = tempfile.NamedTemporaryFile(mode='w', delete=False)
        tmp_name = tmp_file.name
        
        if os.path.exists(file_path):
            with open(file_path, 'r') as f:
                updated = False
                for line in f:
                    line = line.rstrip('\n')
                    if line.startswith(key + '='):
                        tmp_file.write(f"{key}={value}\n")
                        updated = True
                    else:
                        tmp_file.write(line + '\n')
                if not updated:
                    tmp_file.write(f"{key}={value}\n")
        else:
            tmp_file.write(f"{key}={value}\n")
        
        tmp_file.close()
        shutil.move(tmp_name, file_path)
    except Exception as e:
        if tmp_file and os.path.exists(tmp_file.name):
            os.unlink(tmp_file.name)
        raise e

def delete_env_line(file_path, key):
    if not os.path.exists(file_path):
        return
    
    tmp_file = None
    try:
        tmp_file = tempfile.NamedTemporaryFile(mode='w', delete=False)
        tmp_name = tmp_file.name
        
        with open(file_path, 'r') as f:
            for line in f:
                line = line.rstrip('\n')
                if not line.startswith(key + '='):
                    tmp_file.write(line + '\n')
        
        tmp_file.close()
        shutil.move(tmp_name, file_path)
    except Exception as e:
        if tmp_file and os.path.exists(tmp_file.name):
            os.unlink(tmp_file.name)
        raise e

def main():
    parser = argparse.ArgumentParser(add_help=False, usage=argparse.SUPPRESS)
    parser.add_argument('--key-path', required=False)
    parser.add_argument('--key-id', required=False)
    parser.add_argument('--issuer-id', required=False)
    parser.add_argument('--service', default='openclaw-asc-key')
    parser.add_argument('--account', default=os.environ.get('USER', os.environ.get('LOGNAME', '')))
    parser.add_argument('--write-env', action='store_true')
    parser.add_argument('--env-file', required=False)
    parser.add_argument('-h', '--help', action='store_true')
    
    args, unknown = parser.parse_known_args()
    
    if args.help:
        usage()
        sys.exit(0)
    
    if unknown:
        print(f"Unknown argument: {unknown[0]}", file=sys.stderr)
        usage()
        sys.exit(1)
    
    if not args.key_path or not args.issuer_id:
        print("Missing required arguments.", file=sys.stderr)
        usage()
        sys.exit(1)
    
    if not os.path.isfile(args.key_path):
        print(f"Key file not found: {args.key_path}", file=sys.stderr)
        sys.exit(1)
    
    key_id = args.key_id
    if not key_id:
        key_filename = os.path.basename(args.key_path)
        match = re.match(r'^AuthKey_([A-Za-z0-9]+)\.p8$', key_filename)
        if match:
            key_id = match.group(1)
        else:
            print(f"Could not infer --key-id from filename '{key_filename}'. Pass --key-id explicitly.", file=sys.stderr)
            sys.exit(1)
    
    if not args.account:
        print("Could not determine Keychain account. Pass --account explicitly.", file=sys.stderr)
        sys.exit(1)
    
    try:
        with open(args.key_path, 'r') as f:
            key_content = f.read()
        if not key_content:
            print(f"Key file is empty: {args.key_path}", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"Error reading key file: {e}", file=sys.stderr)
        sys.exit(1)
    
    try:
        result = subprocess.run([
            'security', 'add-generic-password',
            '-a', args.account,
            '-s', args.service,
            '-w', key_content,
            '-U'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Failed to store key in Keychain: {result.stderr}", file=sys.stderr)
            sys.exit(1)
            
    except FileNotFoundError:
        print("security command not found. This script requires macOS.", file=sys.stderr)
        sys.exit(1)
    
    print(f"Stored ASC API private key in macOS Keychain (service='{args.service}', account='{args.account}').")
    print()
    print("Export these vars for Fastlane:")
    print(f"ASC_KEY_ID={key_id}")
    print(f"ASC_ISSUER_ID={args.issuer_id}")
    print(f"ASC_KEYCHAIN_SERVICE={args.service}")
    print(f"ASC_KEYCHAIN_ACCOUNT={args.account}")
    
    if args.write_env:
        repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        default_env_file = os.path.join(repo_root, 'apps', 'ios', 'fastlane', '.env')
        env_file = args.env_file if args.env_file else default_env_file
        
        os.makedirs(os.path.dirname(env_file), exist_ok=True)
        if not os.path.exists(env_file):
            open(env_file, 'a').close()
        
        upsert_env_line(env_file, "ASC_KEY_ID", key_id)
        upsert_env_line(env_file, "ASC_ISSUER_ID", args.issuer_id)
        upsert_env_line(env_file, "ASC_KEYCHAIN_SERVICE", args.service)
        upsert_env_line(env_file, "ASC_KEYCHAIN_ACCOUNT", args.account)
        # Remove file/path based keys so Keychain is used by default.
        delete_env_line(env_file, "ASC_KEY_PATH")
        delete_env_line(env_file, "ASC_KEY_CONTENT")
        delete_env_line(env_file, "APP_STORE_CONNECT_API_KEY_PATH")
        
        print()
        print(f"Updated env file: {env_file}")

if __name__ == "__main__":
    main()
