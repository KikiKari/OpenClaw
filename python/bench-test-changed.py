#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "622ef93a068921b5ccef1a6325447d4fb903adbca2fca20a92fe08933f53d094", "source_sha256": "671775b966561d4c6120ff043a4bb70e355d548215a9adf110f38e78918fc1e2", "target_language": "python"}
# bench-test-changed.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bench-test-changed.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def parse_args(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--cwd', default=os.getcwd())
    parser.add_argument('--ref', default='origin/main')
    parser.add_argument('--no-rss', action='store_true')
    parser.add_argument('--worktree', action='store_true')
    parser.add_argument('--max-workers', type=int, metavar='N')

    # Collect unknown arguments to pass through
    args, unknown = parser.parse_known_args(argv)

    return {
        'cwd': Path(args.cwd).resolve(),
        'mode': 'worktree' if args.worktree else 'ref',
        'ref': args.ref,
        'rss': not args.no_rss,
        'maxWorkers': args.max_workers,
        'unknown_args': unknown
    }


def quote_arg(arg):
    if re.search(r'[^A-Za-z0-9_./:-]', arg):
        return json.dumps(arg)
    return arg


def run_git_list(args, cwd):
    try:
        result = subprocess.run(
            ['git'] + args,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split('\n')
        return [line.strip() for line in lines if line.strip()]
    except subprocess.CalledProcessError as e:
        error_msg = e.stderr or e.stdout or f"git {' '.join(args)} failed"
        raise RuntimeError(error_msg)


def list_changed_paths(opts):
    if opts['mode'] == 'worktree':
        diff_files = run_git_list(['diff', '--name-only', '--relative', 'HEAD', '--'], opts['cwd'])
        untracked_files = run_git_list(['ls-files', '--others', '--exclude-standard'], opts['cwd'])
        all_files = list(set(diff_files + untracked_files))
        return sorted(all_files)
    else:
        return run_git_list(['diff', '--name-only', f"{opts['ref']}...HEAD"], opts['cwd'])


def parse_max_rss_kb(output):
    match = re.search(r'(\d+)\s+maximum resident set size', output)
    return int(match.group(1)) if match else None


def format_rss(value_kb):
    if value_kb is None:
        return 'n/a'
    return f'{value_kb / 1024:.1f}MB'


def format_ms(ms):
    if ms < 1000:
        return f'{ms:.1f}ms'
    elif ms < 60000:
        return f'{ms / 1000:.1f}s'
    else:
        minutes = int(ms // 60000)
        seconds = (ms % 60000) / 1000
        return f'{minutes}m{seconds:.1f}s'


def run_bench_command(params):
    import time

    env = os.environ.copy()
    if params.get('maxWorkers') is not None:
        env['OPENCLAW_VITEST_MAX_WORKERS'] = str(params['maxWorkers'])

    start_time = time.perf_counter()

    if params['rss']:
        command_args = ['/usr/bin/time', '-l'] + params['command']
        executable = '/usr/bin/time'
    else:
        command_args = params['command']
        executable = command_args[0]

    try:
        result = subprocess.run(
            command_args,
            cwd=params['cwd'],
            env=env,
            capture_output=True,
            text=True,
            executable=executable
        )
        status = result.returncode
        output = result.stdout + result.stderr
    except Exception as e:
        status = 1
        output = str(e)

    elapsed_ms = (time.perf_counter() - start_time) * 1000

    return {
        'elapsedMs': elapsed_ms,
        'maxRssKb': parse_max_rss_kb(output) if params['rss'] else None,
        'status': status,
        'output': output
    }


def print_run_summary(label, result):
    wall_time = format_ms(result['elapsedMs']).rjust(9)
    rss_usage = format_rss(result['maxRssKb']).rjust(9)
    print(f"{label.ljust(8)} wall={wall_time} rss={rss_usage}")


def main():
    opts = parse_args(sys.argv[1:])
    changed_paths = list_changed_paths(opts)

    if len(changed_paths) == 0:
        if opts['mode'] == 'worktree':
            print('[bench-test-changed] no changed paths in worktree')
        else:
            print(f'[bench-test-changed] no changed paths for {opts["ref"]}...HEAD')
        sys.exit(0)

    print('[bench-test-changed] mode=worktree' if opts['mode'] == 'worktree' 
          else f'[bench-test-changed] ref={opts["ref"]}')
    print('[bench-test-changed] changed paths:')
    for changed_path in changed_paths:
        print(f'- {changed_path}')

    if opts['mode'] == 'worktree':
        routed_command = [sys.executable, 'scripts/test-projects.mjs'] + changed_paths
    else:
        routed_command = [sys.executable, 'scripts/test-projects.mjs', '--changed', opts['ref']]

    root_command = [sys.executable, 'scripts/run-vitest.mjs', 'run', '--config', 'vitest.config.ts'] + changed_paths

    print(f"[bench-test-changed] routed: {' '.join(quote_arg(arg) for arg in routed_command)}")
    routed = run_bench_command({
        'command': routed_command,
        'cwd': opts['cwd'],
        'rss': opts['rss'],
        'maxWorkers': opts['maxWorkers']
    })

    if routed['status'] != 0:
        sys.stderr.write(routed['output'])
        sys.exit(routed['status'])

    print(f"[bench-test-changed] root:   {' '.join(quote_arg(arg) for arg in root_command)}")
    root = run_bench_command({
        'command': root_command,
        'cwd': opts['cwd'],
        'rss': opts['rss'],
        'maxWorkers': opts['maxWorkers']
    })

    if root['status'] != 0:
        sys.stderr.write(root['output'])
        sys.exit(root['status'])

    print_run_summary('routed', routed)
    print_run_summary('root', root)

    delta_wall = root['elapsedMs'] - routed['elapsedMs']
    
    if routed['maxRssKb'] is not None and root['maxRssKb'] is not None:
        delta_rss = root['maxRssKb'] - routed['maxRssKb']
        rss_delta_str = format_rss(delta_rss)
    else:
        rss_delta_str = 'n/a'

    print(f'[bench-test-changed] delta wall={format_ms(delta_wall)} rss={rss_delta_str}')


if __name__ == '__main__':
    main()
