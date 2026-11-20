#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "d72987dccd30372cc0dde292c190e4a447a6aabbe4c5cf7aa3c936c4032298a5", "source_sha256": "d38a1b483644fdcb8d1b3d4826eb7c89f54ac769bf87debab3ab554e0544844f", "target_language": "python"}
# heapsnapshot-delta.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/.agents/skills/openclaw-test-heap-leaks/scripts/heapsnapshot-delta.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import sys
import os
import json
import re
from collections import defaultdict

def print_usage():
    print("Usage: python3 heapsnapshot-delta.py <before.heapsnapshot> <after.heapsnapshot> [--top N] [--min-kb N]", file=sys.stderr)
    print("   or: python3 heapsnapshot-delta.py --lane-dir <dir> [--pid PID] [--top N] [--min-kb N]", file=sys.stderr)

def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)

def parse_args(argv):
    options = {
        "top": 30,
        "min_kb": 64,
        "lane_dir": None,
        "pid": None,
        "files": []
    }

    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--top":
            try:
                options["top"] = int(argv[index + 1])
                index += 2
                continue
            except (IndexError, ValueError):
                fail("--top must be followed by a valid integer")
        if arg == "--min-kb":
            try:
                options["min_kb"] = int(argv[index + 1])
                index += 2
                continue
            except (IndexError, ValueError):
                fail("--min-kb must be followed by a valid integer")
        if arg == "--lane-dir":
            try:
                options["lane_dir"] = argv[index + 1]
                index += 2
                continue
            except IndexError:
                fail("--lane-dir must be followed by a directory path")
        if arg == "--pid":
            try:
                options["pid"] = int(argv[index + 1])
                index += 2
                continue
            except (IndexError, ValueError):
                fail("--pid must be followed by a valid integer")
        options["files"].append(arg)
        index += 1

    if not isinstance(options["top"], int) or options["top"] <= 0:
        fail("--top must be a positive integer")
    if not isinstance(options["min_kb"], int) or options["min_kb"] < 0:
        fail("--min-kb must be a non-negative integer")
    if options["pid"] is not None and (not isinstance(options["pid"], int) or options["pid"] <= 0):
        fail("--pid must be a positive integer")

    return options

class JsonStreamScanner:
    def __init__(self, file_path):
        self.file_path = file_path
        self.file = open(file_path, 'r', buffering=1024*1024, encoding='utf-8')
        self.buffer = ""
        self.offset = 0
        self.done = False

    def __del__(self):
        if hasattr(self, 'file') and self.file:
            self.file.close()

    def compact_buffer(self):
        if self.offset > 65536:
            self.buffer = self.buffer[self.offset:]
            self.offset = 0

    def ensure_available(self, count=1):
        while not self.done and len(self.buffer) - self.offset < count:
            chunk = self.file.read(1024)
            if not chunk:
                self.done = True
                break
            self.buffer += chunk

    def peek(self):
        self.ensure_available(1)
        if self.offset >= len(self.buffer):
            return None
        return self.buffer[self.offset]

    def next_char(self):
        self.ensure_available(1)
        if self.offset >= len(self.buffer):
            return None
        char = self.buffer[self.offset]
        self.offset += 1
        self.compact_buffer()
        return char

    def skip_whitespace(self):
        while True:
            char = self.peek()
            if char is None or not char.isspace():
                return
            self.next_char()

    def expect_char(self, expected):
        char = self.next_char()
        if char != expected:
            fail(f"Expected {expected} but found {char or '<eof>'}")

    def find(self, sequence):
        matched = 0
        while True:
            char = self.next_char()
            if char is None:
                fail(f"Could not find {sequence}")
            if char == sequence[matched]:
                matched += 1
                if matched == len(sequence):
                    return
                continue
            matched = 1 if char == sequence[0] else 0
            if matched == len(sequence):
                return

    def read_balanced_object(self):
        start = self.next_char()
        if start != "{":
            fail(f"Expected {{ but found {start or '<eof>'}")
        text = "{"
        depth = 1
        in_string = False
        escaped = False
        while depth > 0:
            char = self.next_char()
            if char is None:
                fail("Unexpected EOF while reading JSON object")
            text += char
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                continue
            if char == '"':
                in_string = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
        return text

    def parse_number_array(self, on_value):
        self.skip_whitespace()
        self.expect_char("[")
        self.skip_whitespace()
        if self.peek() == "]":
            self.next_char()
            return

        token = ""
        index = 0
        def flush():
            nonlocal token, index
            if len(token) == 0:
                fail("Unexpected empty number token")
            try:
                value = int(token)
            except ValueError:
                fail(f"Invalid numeric token: {token}")
            on_value(value, index)
            index += 1
            token = ""

        while True:
            char = self.next_char()
            if char is None:
                fail("Unexpected EOF while reading number array")
            if char == "]":
                flush()
                return
            if char == ",":
                flush()
                continue
            if char.isspace():
                continue
            token += char

    def read_json_string(self):
        self.expect_char('"')
        value = ""
        while True:
            char = self.next_char()
            if char is None:
                fail("Unexpected EOF while reading JSON string")
            if char == '"':
                return value
            if char != "\\":
                value += char
                continue
            escaped = self.next_char()
            if escaped is None:
                fail("Unexpected EOF while reading JSON string escape")
            if escaped == "u":
                hex_str = ""
                for _ in range(4):
                    hex_char = self.next_char()
                    if hex_char is None:
                        fail("Unexpected EOF while reading JSON unicode escape")
                    hex_str += hex_char
                value += chr(int(hex_str, 16))
                continue
            if escaped == "b":
                value += "\b"
            elif escaped == "f":
                value += "\f"
            elif escaped == "n":
                value += "\n"
            elif escaped == "r":
                value += "\r"
            elif escaped == "t":
                value += "\t"
            else:
                value += escaped

    def parse_string_array(self, on_value):
        self.skip_whitespace()
        self.expect_char("[")
        self.skip_whitespace()
        if self.peek() == "]":
            self.next_char()
            return

        index = 0
        while True:
            value = self.read_json_string()
            on_value(value, index)
            index += 1
            self.skip_whitespace()
            separator = self.next_char()
            if separator == "]":
                return
            if separator != ",":
                fail(f"Expected , or ] but found {separator or '<eof>'}")
            self.skip_whitespace()

def parse_heap_filename(file_path):
    base = os.path.basename(file_path)
    match = re.match(r'^Heap\.(?P<stamp>\d{8}\.\d{6})\.(?P<pid>\d+)\.0\.(?P<seq>\d+)\.heapsnapshot$', base)
    if not match:
        return None
    return {
        "file_path": file_path,
        "pid": int(match.group("pid")),
        "stamp": match.group("stamp"),
        "sequence": int(match.group("seq"))
    }

def resolve_pair(options):
    if options["lane_dir"]:
        try:
            entries = []
            for name in os.listdir(options["lane_dir"]):
                entry = parse_heap_filename(os.path.join(options["lane_dir"], name))
                if entry and (options["pid"] is None or entry["pid"] == options["pid"]):
                    entries.append(entry)
            
            # Sort entries
            entries.sort(key=lambda x: (x["pid"], x["stamp"], x["sequence"]))
            
            if len(entries) == 0:
                fail(f"No matching heap snapshots found in {options['lane_dir']}")
                
            # Group by PID
            groups = {}
            for entry in entries:
                if entry["pid"] not in groups:
                    groups[entry["pid"]] = []
                groups[entry["pid"]].append(entry)
                
            # Find candidates with at least 2 snapshots
            candidates = []
            for pid, group in groups.items():
                if len(group) >= 2:
                    candidates.append({
                        "pid": pid,
                        "before": group[0],
                        "after": group[-1],
                        "count": len(group)
                    })
                    
            if len(candidates) == 0:
                fail(f"Need at least two snapshots for one PID in {options['lane_dir']}")
                
            # Choose candidate
            chosen = None
            if options["pid"] is not None:
                for candidate in candidates:
                    if candidate["pid"] == options["pid"]:
                        chosen = candidate
                        break
            else:
                # Sort by count descending, then by pid ascending
                candidates.sort(key=lambda x: (-x["count"], x["pid"]))
                chosen = candidates[0] if candidates else None
                
            if not chosen:
                fail(f"No PID with at least two snapshots matched in {options['lane_dir']}")
                
            return {
                "before": chosen["before"]["file_path"],
                "after": chosen["after"]["file_path"],
                "pid": chosen["pid"],
                "snapshot_count": chosen["count"]
            }
        except OSError as e:
            fail(f"Error reading directory {options['lane_dir']}: {e}")

    if len(options["files"]) != 2:
        print_usage()
        sys.exit(1)

    return {
        "before": options["files"][0],
        "after": options["files"][1],
        "pid": None,
        "snapshot_count": 2
    }

async def parse_snapshot_meta(scanner):
    scanner.find('"snapshot":')
    scanner.skip_whitespace()
    meta_object_text = scanner.read_balanced_object()
    parsed = json.loads(meta_object_text)
    return parsed.get("meta") if parsed else None

async def build_summary(file_path):
    scanner = JsonStreamScanner(file_path)
    meta = await parse_snapshot_meta(scanner)
    if not meta:
        fail(f"Invalid heap snapshot: {file_path}")

    node_field_count = len(meta["node_fields"])
    type_names = meta["node_types"][0]
    type_index = meta["node_fields"].index("type")
    name_index = meta["node_fields"].index("name")
    self_size_index = meta["node_fields"].index("self_size")
    if type_index == -1 or name_index == -1 or self_size_index == -1:
        fail(f"Unsupported heap snapshot schema: {file_path}")

    summary_by_index = {}
    node_count = 0
    current_type_id = 0
    current_name_id = 0
    current_self_size = 0
    
    def on_node_value(value, index):
        nonlocal node_count, current_type_id, current_name_id, current_self_size
        field_index = index % node_field_count
        if field_index == type_index:
            current_type_id = value
            return
        if field_index == name_index:
            current_name_id = value
            return
        if field_index == self_size_index:
            current_self_size = value
        if field_index != node_field_count - 1:
            return
            
        key = f"{current_type_id}\t{current_name_id}"
        if key not in summary_by_index:
            summary_by_index[key] = {
                "type_id": current_type_id,
                "name_id": current_name_id,
                "self_size": 0,
                "count": 0
            }
        summary_by_index[key]["self_size"] += current_self_size
        summary_by_index[key]["count"] += 1
        node_count += 1

    scanner.find('"nodes":')
    scanner.parse_number_array(on_node_value)

    required_name_ids = set(entry["name_id"] for entry in summary_by_index.values() if entry["name_id"] >= 0)
    name_strings = {}
    
    def on_string_value(value, index):
        if index in required_name_ids:
            name_strings[index] = value

    scanner.find('"strings":')
    scanner.parse_string_array(on_string_value)

    summary = {}
    for entry in summary_by_index.values():
        type_name = type_names[entry["type_id"]] if entry["type_id"] < len(type_names) else "unknown"
        name_str = name_strings.get(entry["name_id"], "")
        key = f"{type_name}\t{name_str}"
        summary[key] = {
            "type": type_name,
            "name": name_str,
            "self_size": entry["self_size"],
            "count": entry["count"]
        }

    return {
        "node_count": node_count,
        "summary": summary
    }

def format_bytes(bytes_val):
    abs_bytes = abs(bytes_val)
    if abs_bytes >= 1024 ** 2:
        return f"{bytes_val / (1024 ** 2):.2f} MiB"
    if abs_bytes >= 1024:
        return f"{bytes_val / 1024:.1f} KiB"
    return f"{bytes_val} B"

def format_delta(bytes_val):
    sign = "+" if bytes_val >= 0 else "-"
    return f"{sign}{format_bytes(abs(bytes_val))}"

def truncate(text, max_length):
    if len(text) <= max_length:
        return text
    return f"{text[:max_length-1]}…"

async def main():
    options = parse_args(sys.argv[1:])
    pair = resolve_pair(options)
    before = await build_summary(pair["before"])
    after = await build_summary(pair["after"])
    min_bytes = options["min_kb"] * 1024

    rows = []
    for key, next_entry in after["summary"].items():
        previous = before["summary"].get(key, {"self_size": 0, "count": 0})
        size_delta = next_entry["self_size"] - previous["self_size"]
        count_delta = next_entry["count"] - previous["count"]
        if size_delta < min_bytes:
            continue
        rows.append({
            "type": next_entry["type"],
            "name": next_entry["name"],
            "size_delta": size_delta,
            "count_delta": count_delta,
            "after_size": next_entry["self_size"],
            "after_count": next_entry["count"]
        })

    rows.sort(key=lambda x: (-x["size_delta"], -x["count_delta"]))

    print(f"before: {pair['before']}")
    print(f"after:  {pair['after']}")
    if pair["pid"] is not None:
        print(f"pid:    {pair['pid']} ({pair['snapshot_count']} snapshots found)")
    print(f"nodes:   {before['node_count']} -> {after['node_count']} ({'+' if after['node_count'] - before['node_count'] >= 0 else ''}{after['node_count'] - before['node_count']})")
    print(f"filter:  top={options['top']} min={options['min_kb']} KiB")
    print("")

    if len(rows) == 0:
        print("No entries exceeded the minimum delta.")
        return

    for row in rows[:options["top"]]:
        sign = "+" if row["count_delta"] >= 0 else ""
        print(f"{format_delta(row['size_delta']):>11}  count {sign}{row['count_delta']:>6}  {row['type']:<16}  {truncate(row['name'] or '(empty)', 96)}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
