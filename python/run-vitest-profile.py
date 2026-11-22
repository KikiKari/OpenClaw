#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "01d0dde3b0df9f9ee4aa9d7b63bcb0a973b3191c6600a680aedf65d0bf50f550", "source_sha256": "047c165dbfdfa71d13cb6cf0b23d2b60439a2e0ec23e6951411b25fd91c6dcab", "target_language": "python"}
# run-vitest-profile.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/run-vitest-profile.mjs
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os
import tempfile
import pathlib


def format_error_message(error):
    """Format error message similar to the JS version"""
    if hasattr(error, 'message'):
        return str(error.message)
    return str(error)


def parse_args(argv):
    """Parse command line arguments"""
    args = {
        'mode': '',
        'output_dir': os.environ.get('OPENCLAW_VITEST_PROFILE_DIR', '').strip()
    }

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == '--output-dir':
            args['output_dir'] = argv[i + 1] if i + 1 < len(argv) else ''
            i += 2
            continue
        if not args['mode']:
            args['mode'] = arg
            i += 1
            continue
        raise Exception(f'Unknown argument: {arg}')

    if args['mode'] not in ['main', 'runner']:
        raise Exception(
            'Usage: python run-vitest-profile.py <main|runner> [--output-dir <dir>]'
        )

    return args


def resolve_vitest_profile_dir(mode, output_dir):
    """Resolve the profile directory path"""
    if output_dir and output_dir.strip():
        return os.path.abspath(output_dir)

    temp_dir = tempfile.gettempdir()
    prefix = f'openclaw-vitest-{mode}-profile-'
    return tempfile.mkdtemp(prefix=prefix, dir=temp_dir)


def build_vitest_profile_command(mode, output_dir):
    """Build the vitest profile command"""
    if mode == 'main':
        return {
            'command': sys.executable,
            'args': [
                '--cpu-prof',
                f'--cpu-prof-dir={output_dir}',
                './node_modules/vitest/vitest.mjs',
                'run',
                '--config',
                'test/vitest/vitest.unit.config.ts',
                '--no-file-parallelism',
            ]
        }

    return {
        'command': 'pnpm',
        'args': [
            'vitest',
            'run',
            '--config',
            'test/vitest/vitest.unit.config.ts',
            '--no-file-parallelism',
            '--execArgv=--cpu-prof',
            f'--execArgv=--cpu-prof-dir={output_dir}',
            '--execArgv=--heap-prof',
            f'--execArgv=--heap-prof-dir={output_dir}',
        ]
    }


def main():
    """Main function"""
    parsed = parse_args(sys.argv[1:])
    output_dir = resolve_vitest_profile_dir(parsed['mode'], parsed['output_dir'])
    os.makedirs(output_dir, exist_ok=True)

    plan = build_vitest_profile_command(parsed['mode'], output_dir)

    print(f'[run-vitest-profile] writing {parsed["mode"]} profiles to {output_dir}')

    # Determine if we need shell on Windows
    use_shell = sys.platform == 'win32' and plan['command'] == 'pnpm'

    try:
        result = subprocess.run(
            [plan['command']] + plan['args'],
            stdout=sys.stdout,
            stderr=sys.stderr,
            stdin=sys.stdin,
            shell=use_shell,
            env=os.environ
        )
        sys.exit(result.returncode)
    except Exception as e:
        raise e


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(format_error_message(error), file=sys.stderr)
        sys.exit(1)
