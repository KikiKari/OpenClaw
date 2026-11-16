#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "9cfefd352b141cd0614cdef57d1e361c433dd1e1cc76a3395ae048957a5e6a8c", "source_sha256": "646ce6bf1521c1200f2204aa19a05521f8f53d734ec8c000b61f4290f2a05074", "target_language": "python"}
# changelog.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/pr-lib/changelog.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import re
import tempfile


def normalize_pr_changelog_entries(pr):
    changelog_path = "CHANGELOG.md"

    if not os.path.exists(changelog_path):
        return

    with open(changelog_path, 'r', encoding='utf-8') as f:
        original = f.read()

    lines = original.split('\n')
    pr_pattern = re.compile(r'(?:\(#' + str(pr) + r'\)|openclaw#' + str(pr) + r')', re.IGNORECASE)

    def find_active_section_index(arr):
        try:
            return arr.index("## Unreleased")
        except ValueError:
            return -1

    def find_section_end(arr, start):
        for i in range(start + 1, len(arr)):
            if re.match(r'^## ', arr[i]):
                return i
        return len(arr)

    def ensure_active_section(arr):
        active_index = find_active_section_index(arr)
        if active_index != -1:
            return active_index

        insert_at = -1
        for idx, line in enumerate(arr):
            if idx > 0 and re.match(r'^## ', line):
                insert_at = idx
                break
        if insert_at == -1:
            insert_at = len(arr)

        block = ["## Unreleased", "", "### Changes", ""]
        if insert_at > 0 and arr[insert_at - 1] != "":
            block.insert(0, "")
        arr[insert_at:insert_at] = block
        return find_active_section_index(arr)

    def context_for(arr, index):
        major = ""
        minor = ""
        for i in range(index, -1, -1):
            line = arr[i]
            if not minor and re.match(r'^### ', line):
                minor = line.strip()
            if re.match(r'^## ', line):
                major = line.strip()
                break
        return {"major": major, "minor": minor}

    def ensure_subsection(arr, subsection):
        active_index = ensure_active_section(arr)
        active_end = find_section_end(arr, active_index)
        desired = subsection if subsection and re.match(r'^### ', subsection) else "### Changes"
        for i in range(active_index + 1, active_end):
            if arr[i].strip() == desired:
                return i

        insert_at = active_end
        while insert_at > active_index + 1 and arr[insert_at - 1] == "":
            insert_at -= 1
        block = ["", desired, ""]
        arr[insert_at:insert_at] = block
        return insert_at + 1

    def section_tail_insert_index(arr, subsection_index):
        next_heading = len(arr)
        for i in range(subsection_index + 1, len(arr)):
            if re.match(r'^### ', arr[i]) or re.match(r'^## ', arr[i]):
                next_heading = i
                break

        insert_at = next_heading
        while insert_at > subsection_index + 1 and arr[insert_at - 1] == "":
            insert_at -= 1
        return insert_at

    ensure_active_section(lines)

    moved = []
    for i in range(len(lines)):
        if not pr_pattern.search(lines[i]):
            continue
        ctx = context_for(lines, i)
        if ctx["major"] == "## Unreleased":
            continue
        moved.append({
            "line": lines[i],
            "subsection": ctx["minor"] or "### Changes",
            "index": i,
        })

    if len(moved) == 0:
        return

    remove_indexes = set(entry["index"] for entry in moved)
    next_lines = [lines[i] for i in range(len(lines)) if i not in remove_indexes]

    for entry in moved:
        subsection_index = ensure_subsection(next_lines, entry["subsection"])
        insert_at = section_tail_insert_index(next_lines, subsection_index)

        next_heading = len(next_lines)
        for i in range(subsection_index + 1, len(next_lines)):
            if re.match(r'^### ', next_lines[i]) or re.match(r'^## ', next_lines[i]):
                next_heading = i
                break

        already_present = any(
            line == entry["line"]
            for line in next_lines[subsection_index + 1:next_heading]
        )
        if already_present:
            continue
        next_lines.insert(insert_at, entry["line"])

    updated = '\n'.join(next_lines)
    if updated != original:
        with open(changelog_path, 'w', encoding='utf-8') as f:
            f.write(updated)


def validate_changelog_entry_for_pr(pr, contrib):
    result = subprocess.run(
        ['git', 'diff', '--unified=0', 'origin/main...HEAD', '--', 'CHANGELOG.md'],
        capture_output=True,
        text=True,
        check=True
    )
    diff_output = result.stdout

    added_lines = []
    for line in diff_output.splitlines():
        if line.startswith('+++'):
            continue
        if line.startswith('+'):
            added_lines.append(line[1:])

    if not added_lines:
        print("CHANGELOG.md is in diff but no added lines were detected.")
        sys.exit(1)

    pr_pattern = f"(#{pr}|openclaw#{pr})"
    with_pr = [line for line in added_lines if re.search(pr_pattern, line, re.IGNORECASE)]

    if not with_pr:
        print(f"CHANGELOG.md update must reference PR #{pr} (for example, (#{pr})).")
        sys.exit(1)

    with tempfile.NamedTemporaryFile(mode='w+', delete=False) as tmp_diff_file:
        tmp_diff_file.write(diff_output)
        tmp_diff_file_path = tmp_diff_file.name

    try:
        awk_script = '''
BEGIN {
  line_no = 0
  file_line_count = 0
  issue_count = 0
}
FNR == NR {
  if ($0 ~ /^@@ /) {
    if (match($0, /\\+[0-9]+/)) {
      line_no = substr($0, RSTART + 1, RLENGTH - 1) + 0
    } else {
      line_no = 0
    }
    next
  }
  if ($0 ~ /^\\+\\+\\+/) {
    next
  }
  if ($0 ~ /^\\+/) {
    if (line_no > 0) {
      added[line_no] = 1
      added_text = substr($0, 2)
      if (added_text ~ pattern) {
        pr_added_lines[++pr_added_count] = line_no
        pr_added_text[line_no] = added_text
      }
      line_no++
    }
    next
  }
  if ($0 ~ /^-/) {
    next
  }
  if (line_no > 0) {
    line_no++
  }
  next
}
{
  changelog[FNR] = $0
  file_line_count = FNR
}
END {
  for (idx = 1; idx <= pr_added_count; idx++) {
    entry_line = pr_added_lines[idx]
    release_line = 0
    section_line = 0
    for (i = entry_line; i >= 1; i--) {
      if (section_line == 0 && changelog[i] ~ /^### /) {
        section_line = i
        continue
      }
      if (changelog[i] ~ /^## /) {
        release_line = i
        break
      }
    }
    if (release_line == 0 || changelog[release_line] != "## Unreleased") {
      printf "CHANGELOG.md PR-linked entry must be in ## Unreleased: line %d: %s\\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }
    if (section_line == 0) {
      printf "CHANGELOG.md entry must be inside a subsection (### ...): line %d: %s\\n", entry_line, pr_added_text[entry_line]
      issue_count++
      continue
    }

    section_name = changelog[section_line]
    next_heading = file_line_count + 1
    for (i = entry_line + 1; i <= file_line_count; i++) {
      if (changelog[i] ~ /^### / || changelog[i] ~ /^## /) {
        next_heading = i
        break
      }
    }

    for (i = entry_line + 1; i < next_heading; i++) {
      line_text = changelog[i]
      if (line_text ~ /^[[:space:]]*$/) {
        continue
      }
      if (i in added) {
        continue
      }
      printf "CHANGELOG.md PR-linked entry must be appended at the end of section %s: line %d: %s\\n", section_name, entry_line, pr_added_text[entry_line]
      printf "Found existing non-added line below it at line %d: %s\\n", i, line_text
      issue_count++
      break
    }
  }

  if (issue_count > 0) {
    print "Move this PR changelog entry to the end of its section (just before the next heading)."
    exit 1
  }
}
'''
        result = subprocess.run(
            ['awk', '-v', f'pattern={pr_pattern}', awk_script, tmp_diff_file_path, 'CHANGELOG.md'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(result.stderr)
            sys.exit(1)
    finally:
        os.unlink(tmp_diff_file_path)

    print("changelog placement validated: PR-linked entries are appended at section tail")

    if contrib and contrib != "null":
        with_pr_and_thanks = [
            line for line in with_pr
            if re.search(r'thanks @' + contrib, line, re.IGNORECASE)
        ]
        if not with_pr_and_thanks:
            print(f"CHANGELOG.md update must include both PR #{pr} and thanks @{contrib} on the changelog entry line.")
            sys.exit(1)
        print(f"changelog validated: found PR #{pr} + thanks @{contrib}")
        return

    print(f"changelog validated: found PR #{pr} (contributor handle unavailable, skipping thanks check)")


def validate_changelog_merge_hygiene():
    result = subprocess.run(
        ['git', 'diff', '--unified=0', 'origin/main...HEAD', '--', 'CHANGELOG.md'],
        capture_output=True,
        text=True,
        check=True
    )
    diff_output = result.stdout

    removed_lines = []
    for line in diff_output.splitlines():
        if line.startswith('---'):
            continue
        if line.startswith('-'):
            removed_lines.append(line[1:])

    if not removed_lines:
        return

    removed_refs = set()
    for line in removed_lines:
        matches = re.findall(r'#([0-9]+)', line)
        removed_refs.update(matches)

    if not removed_refs:
        return

    added_lines = []
    for line in diff_output.splitlines():
        if line.startswith('+++'):
            continue
        if line.startswith('+'):
            added_lines.append(line[1:])

    for ref in removed_refs:
        full_ref = '#' + ref
        if not any(full_ref in line for line in added_lines):
            print(f"CHANGELOG.md drops existing entry reference {full_ref} without re-adding it.")
            print("Likely merge conflict loss; restore the dropped entry (or keep the same PR ref in rewritten text).")
            sys.exit(1)

    print("changelog merge hygiene validated: no dropped PR references")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: changelog.py <command> [args...]")
        sys.exit(1)

    command = sys.argv[1]
    if command == "normalize_pr_changelog_entries":
        if len(sys.argv) < 3:
            print("Missing PR number")
            sys.exit(1)
        normalize_pr_changelog_entries(sys.argv[2])
    elif command == "validate_changelog_entry_for_pr":
        if len(sys.argv) < 4:
            print("Missing PR number and contributor")
            sys.exit(1)
        validate_changelog_entry_for_pr(sys.argv[2], sys.argv[3])
    elif command == "validate_changelog_merge_hygiene":
        validate_changelog_merge_hygiene()
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
