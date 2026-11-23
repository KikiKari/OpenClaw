#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "495ad60eec3a9e782390e729768c14d7b62170aa0f5e2ff45138b62a6cfbb613", "source_sha256": "c6c7301dda8709e6c39c53f79a83f8f7938854384f4e21e1114095d876e51a6d", "target_language": "python"}
# test-cli-startup-bench-budget.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-cli-startup-bench-budget.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os
import json
import argparse
from pathlib import Path
from typing import Dict, Any, Optional, List, Union


CLI_STARTUP_BENCH_FIXTURE_PATH = "test/fixtures/cli-startup-bench.json"


def format_ms(value: float) -> str:
    return f"{value:.1f}ms"


def format_mb(value: float) -> str:
    return f"{value:.1f}MB"


def read_json_file(path: str) -> Dict[str, Any]:
    """Read and parse a JSON file."""
    with open(path, 'r') as f:
        return json.load(f)


def index_cases(report: Dict[str, Any]) -> Dict[str, Any]:
    """Index cases by their ID."""
    cases = report.get('primary', {}).get('cases', [])
    return {entry['id']: entry for entry in cases}


def resolve_current_report_path(opts: argparse.Namespace) -> str:
    """Resolve or generate the current benchmark report path."""
    if opts.report:
        return opts.report
    
    report_path = ".artifacts/cli-startup-bench.current.json"
    os.makedirs(".artifacts", exist_ok=True)
    
    args = [
        "node",
        "--import",
        "tsx",
        "scripts/bench-cli-startup.ts",
        "--entry",
        opts.entry,
        "--preset",
        opts.preset,
        "--runs",
        str(opts.runs),
        "--warmup",
        str(opts.warmup),
        "--timeout-ms",
        str(opts.timeout_ms),
        "--output",
        report_path,
    ]
    
    result = subprocess.run(args, cwd=os.getcwd(), env=os.environ)
    if result.returncode != 0:
        sys.exit(result.returncode)
    
    return report_path


def main():
    parser = argparse.ArgumentParser(
        description="Compare current CLI benchmark results against the checked-in fixture.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example:
  python test-cli-startup-bench-budget.py --preset real --max_duration_regression_pct 15
        """
    )
    
    parser.add_argument("--baseline", default=CLI_STARTUP_BENCH_FIXTURE_PATH,
                       help="Baseline fixture path")
    parser.add_argument("--report", default="",
                       help="Reuse an existing current benchmark report")
    parser.add_argument("--entry", default="openclaw.mjs",
                       help="CLI entry to benchmark when report is omitted")
    parser.add_argument("--preset", default="all",
                       help="startup | real | all (default: all)")
    parser.add_argument("--runs", type=int, default=1,
                       help="Measured runs per case (default: 1)")
    parser.add_argument("--warmup", type=int, default=0,
                       help="Warmup runs per case (default: 0)")
    parser.add_argument("--timeout_ms", type=int, default=30000,
                       help="Per-run timeout (default: 30000)")
    parser.add_argument("--max_duration_regression_pct", type=float,
                       default=float(os.environ.get("OPENCLAW_STARTUP_BENCH_MAX_DURATION_REGRESSION_PCT", 20)),
                       help="Fail if avg duration regresses more than this percent")
    parser.add_argument("--max_rss_regression_pct", type=float,
                       default=float(os.environ.get("OPENCLAW_STARTUP_BENCH_MAX_RSS_REGRESSION_PCT", 20)),
                       help="Fail if avg RSS regresses more than this percent")
    parser.add_argument("--help", action="help", help="Show this help text")

    # Manually handle --help to match JS behavior exactly
    if "--help" in sys.argv or "-h" in sys.argv:
        print("""
Usage: python test-cli-startup-bench-budget.py [options]

Compare current CLI benchmark results against the checked-in fixture.

Options:
  --baseline <path>             Baseline fixture path
  --report <path>               Reuse an existing current benchmark report
  --entry <path>                CLI entry to benchmark when report is omitted
  --preset <name>               startup | real | all (default: all)
  --runs <n>                    Measured runs per case (default: 1)
  --warmup <n>                  Warmup runs per case (default: 0)
  --timeout-ms <ms>             Per-run timeout (default: 30000)
  --max-duration-regression-pct <n>
                                Fail if avg duration regresses more than this percent
  --max-rss-regression-pct <n>  Fail if avg RSS regresses more than this percent
  --help                        Show this help text

Example:
  python test-cli-startup-bench-budget.py --preset real --max-duration-regression-pct 15
        """.strip())
        sys.exit(0)

    opts = parser.parse_args()

    # Read baseline and current reports
    baseline = read_json_file(opts.baseline)
    current_path = resolve_current_report_path(opts)
    current = read_json_file(current_path)
    
    baseline_cases = index_cases(baseline)
    current_cases = index_cases(current)
    
    failed = False
    
    for case_id, baseline_case in baseline_cases.items():
        current_case = current_cases.get(case_id)
        if not current_case:
            print(f"[test-cli-startup-bench-budget] missing current case {case_id}")
            failed = True
            continue
        
        # Check duration regression
        baseline_duration = baseline_case.get('summary', {}).get('durationMs', {}).get('avg')
        current_duration = current_case.get('summary', {}).get('durationMs', {}).get('avg')
        
        if (isinstance(baseline_duration, (int, float)) and 
            isinstance(current_duration, (int, float)) and 
            baseline_duration > 0):
            
            allowed_duration = baseline_duration * (1 + opts.max_duration_regression_pct / 100)
            if current_duration > allowed_duration:
                print(
                    f"[test-cli-startup-bench-budget] {baseline_case['name']} avg duration "
                    f"{format_ms(current_duration)} exceeded {format_ms(allowed_duration)} "
                    f"(baseline {format_ms(baseline_duration)}, +{opts.max_duration_regression_pct}%)."
                )
                failed = True
        
        # Check RSS regression
        baseline_rss = baseline_case.get('summary', {}).get('maxRssMb', {}).get('avg')
        current_rss = current_case.get('summary', {}).get('maxRssMb', {}).get('avg')
        
        if (isinstance(baseline_rss, (int, float)) and 
            isinstance(current_rss, (int, float)) and 
            baseline_rss > 0):
            
            allowed_rss = baseline_rss * (1 + opts.max_rss_regression_pct / 100)
            if current_rss > allowed_rss:
                print(
                    f"[test-cli-startup-bench-budget] {baseline_case['name']} avg RSS "
                    f"{format_mb(current_rss)} exceeded {format_mb(allowed_rss)} "
                    f"(baseline {format_mb(baseline_rss)}, +{opts.max_rss_regression_pct}%)."
                )
                failed = True
        
        # Print summary line
        print(
            f"[test-cli-startup-bench-budget] {baseline_case['name']} "
            f"duration={format_ms(current_duration) if isinstance(current_duration, (int, float)) else 'n/a'} "
            f"baseline={format_ms(baseline_duration) if isinstance(baseline_duration, (int, float)) else 'n/a'} "
            f"rss={format_mb(current_rss) if isinstance(current_rss, (int, float)) else 'n/a'} "
            f"baselineRss={format_mb(baseline_rss) if isinstance(baseline_rss, (int, float)) else 'n/a'}"
        )
    
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
