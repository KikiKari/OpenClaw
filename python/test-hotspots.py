#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "ffc18b63cb9af8b6c08a501573d3d8b96df7960024fbe478ce08cca14f5fd3f1", "source_sha256": "4252ea2457fcacdde20bb203479a1fcfbb9fa70ecf111838b7f2ac7c0902a093", "target_language": "python"}
# test-hotspots.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-hotspots.mjs
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, NamedTuple


class FileResult(NamedTuple):
    file: str
    duration_ms: float
    test_count: int


def format_ms(ms: float) -> str:
    """Format milliseconds as a string with unit suffix."""
    if ms >= 1000:
        return f"{ms / 1000:.1f}s"
    return f"{ms:.0f}ms"


def collect_vitest_file_durations(report: Dict[str, Any]) -> List[FileResult]:
    """Collect test file durations from a Vitest JSON report."""
    results = []
    
    for file_entry in report.get("files", []):
        file_path = file_entry.get("file", "")
        duration_ms = file_entry.get("duration", 0)
        test_count = len(file_entry.get("tasks", []))
        
        # Count nested tasks (describe blocks, etc.)
        for task in file_entry.get("tasks", []):
            test_count += count_nested_tasks(task)
            
        results.append(FileResult(
            file=file_path,
            duration_ms=duration_ms,
            test_count=test_count
        ))
    
    return results


def count_nested_tasks(task: Dict[str, Any]) -> int:
    """Recursively count nested test tasks."""
    count = 0
    for child in task.get("tasks", []):
        count += 1 + count_nested_tasks(child)
    return count


def load_vitest_report_from_args(config_path: str, report_path: str) -> Dict[str, Any]:
    """Load or generate Vitest JSON report based on provided arguments."""
    if report_path:
        with open(report_path, 'r') as f:
            return json.load(f)
    else:
        # Run vitest to generate report
        cmd = ["npx", "vitest", "--run", "--reporter=json", f"--config={config_path}"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Vitest failed: {result.stderr}")
        return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(
        description="Print the slowest test files from a Vitest JSON report.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python test-hotspots.py
  python test-hotspots.py --config test/vitest/vitest.channels.config.ts --limit 10
  python test-hotspots.py --report /tmp/vitest-report.json
        """
    )
    
    parser.add_argument(
        "--config",
        default="test/vitest/vitest.unit.config.ts",
        help="Vitest config to run when no report is supplied"
    )
    parser.add_argument(
        "--report",
        help="Reuse an existing Vitest JSON report"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=20,
        help="Number of files to print (default: 20)"
    )
    
    args = parser.parse_args()
    
    try:
        report = load_vitest_report_from_args(args.config, args.report)
        file_results = sorted(
            collect_vitest_file_durations(report),
            key=lambda x: x.duration_ms,
            reverse=True
        )
        
        top = file_results[:args.limit]
        total_duration_ms = sum(item.duration_ms for item in file_results)
        
        print(f"\n[test-hotspots] top {len(top)} by file duration ({format_ms(total_duration_ms)} total)")
        
        for index, item in enumerate(top):
            label = str(index + 1).zfill(2)
            duration = format_ms(item.duration_ms).rjust(10)
            tests = str(item.test_count).rjust(4)
            print(f"{label}. {duration} | tests={tests} | {item.file}")
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
