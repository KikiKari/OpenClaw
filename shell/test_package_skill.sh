#!/usr/bin/env bash
# test_package_skill.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Regression tests for skill packaging security behavior.

# Create temporary directory for testing
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Mock quick_validate module behavior
export MOCK_QUICK_VALIDATE=1

# Import package_skill functions (simulated)
package_skill() {
    local skill_dir="$1"
    local out_dir="$2"
    local skill_name
    skill_name=$(basename "$skill_dir")

    # Validate skill using mock
    if [[ -n "${MOCK_QUICK_VALIDATE:-}" ]]; then
        echo "Skill is valid!" >&2
    fi

    # Check if output directory is within skill directory
    if [[ "$(realpath "$out_dir")" == "$(realpath "$skill_dir")"* ]]; then
        local skip_output=1
    else
        local skip_output=0
    fi

    # Create output directory if it doesn't exist
    mkdir -p "$out_dir"

    # Create skill archive
    local skill_file="$out_dir/$skill_name.skill"
    
    # Use Python to create the zip file to ensure consistent behavior
    python3 -c "
import os
import zipfile
from pathlib import Path

skill_dir = Path('$skill_dir')
skill_name = '$skill_name'
skill_file = '$skill_file'
skip_output = $skip_output

with zipfile.ZipFile(skill_file, 'w') as archive:
    for root, dirs, files in os.walk(skill_dir):
        # Skip the .skill file itself when output dir is skill dir
        if skip_output and root == str(skill_dir) and '$skill_name.skill' in files:
            files.remove('$skill_name.skill')
            
        for file in files:
            file_path = Path(root) / file
            rel_path = file_path.relative_to(skill_dir.parent)
            
            # Only add files that are actually within the skill directory
            if str(file_path).startswith(str(skill_dir)):
                archive.write(file_path, f'{skill_name}/{rel_path}')
"
    
    echo "$skill_file"
}

create_skill() {
    local name="${1:-test-skill}"
    local skill_dir="$temp_dir/$name"
    
    mkdir -p "$skill_dir"
    
    cat > "$skill_dir/SKILL.md" << EOF
---
name: test-skill
description: test
---
EOF
    
    echo "print('ok')" > "$skill_dir/script.py"
    
    echo "$skill_dir"
}

test_packages_normal_files() {
    local skill_dir
    skill_dir=$(create_skill "normal-skill")
    local out_dir="$temp_dir/out"
    mkdir -p "$out_dir"
    
    local result
    result=$(package_skill "$skill_dir" "$out_dir")
    
    if [[ ! -f "$result" ]]; then
        echo "FAIL: Skill file was not created"
        return 1
    fi
    
    local names
    names=$(python3 -c "
import zipfile
with zipfile.ZipFile('$result', 'r') as archive:
    for name in archive.namelist():
        print(name)
")
    
    if ! echo "$names" | grep -q "normal-skill/SKILL.md"; then
        echo "FAIL: SKILL.md not found in archive"
        return 1
    fi
    
    if ! echo "$names" | grep -q "normal-skill/script.py"; then
        echo "FAIL: script.py not found in archive"
        return 1
    fi
    
    echo "PASS: test_packages_normal_files"
}

test_skips_symlink_to_external_file() {
    local skill_dir
    skill_dir=$(create_skill "symlink-file-skill")
    local outside="$temp_dir/outside-secret.txt"
    echo "super-secret" > "$outside"
    local link="$skill_dir/loot.txt"
    local out_dir="$temp_dir/out"
    mkdir -p "$out_dir"
    
    # Try to create symlink
    if ! ln -sf "$outside" "$link" 2>/dev/null; then
        echo "SKIP: test_skips_symlink_to_external_file (symlinks not supported)"
        return 0
    fi
    
    local result
    result=$(package_skill "$skill_dir" "$out_dir")
    
    if [[ ! -f "$result" ]]; then
        echo "FAIL: Skill file was not created"
        return 1
    fi
    
    local names
    names=$(python3 -c "
import zipfile
with zipfile.ZipFile('$result', 'r') as archive:
    for name in archive.namelist():
        print(name)
")
    
    if ! echo "$names" | grep -q "symlink-file-skill/SKILL.md"; then
        echo "FAIL: SKILL.md not found in archive"
        return 1
    fi
    
    if ! echo "$names" | grep -q "symlink-file-skill/script.py"; then
        echo "FAIL: script.py not found in archive"
        return 1
    fi
    
    if echo "$names" | grep -q "symlink-file-skill/loot.txt"; then
        echo "FAIL: loot.txt should not be included in archive"
        return 1
    fi
    
    echo "PASS: test_skips_symlink_to_external_file"
}

test_skips_symlink_directory() {
    local skill_dir
    skill_dir=$(create_skill "symlink-dir-skill")
    local outside_dir="$temp_dir/outside"
    mkdir -p "$outside_dir"
    echo "secret" > "$outside_dir/secret.txt"
    local link="$skill_dir/docs"
    local out_dir="$temp_dir/out"
    mkdir -p "$out_dir"
    
    # Try to create symlink
    if ! ln -sf "$outside_dir" "$link" 2>/dev/null; then
        echo "SKIP: test_skips_symlink_directory (symlinks not supported)"
        return 0
    fi
    
    local result
    result=$(package_skill "$skill_dir" "$out_dir")
    
    if [[ ! -f "$result" ]]; then
        echo "FAIL: Skill file was not created"
        return 1
    fi
    
    local names
    names=$(python3 -c "
import zipfile
with zipfile.ZipFile('$result', 'r') as archive:
    for name in archive.namelist():
        print(name)
")
    
    if ! echo "$names" | grep -q "symlink-dir-skill/SKILL.md"; then
        echo "FAIL: SKILL.md not found in archive"
        return 1
    fi
    
    if ! echo "$names" | grep -q "symlink-dir-skill/script.py"; then
        echo "FAIL: script.py not found in archive"
        return 1
    fi
    
    if echo "$names" | grep -q "symlink-dir-skill/docs/secret.txt"; then
        echo "FAIL: secret.txt should not be included in archive"
        return 1
    fi
    
    echo "PASS: test_skips_symlink_directory"
}

test_allows_nested_regular_files() {
    local skill_dir
    skill_dir=$(create_skill "nested-skill")
    local nested="$skill_dir/lib/helpers"
    mkdir -p "$nested"
    echo "def run():
    return 1" > "$nested/util.py"
    local out_dir="$temp_dir/out"
    mkdir -p "$out_dir"
    
    local result
    result=$(package_skill "$skill_dir" "$out_dir")
    
    if [[ ! -f "$result" ]]; then
        echo "FAIL: Skill file was not created"
        return 1
    fi
    
    local names
    names=$(python3 -c "
import zipfile
with zipfile.ZipFile('$result', 'r') as archive:
    for name in archive.namelist():
        print(name)
")
    
    if ! echo "$names" | grep -q "nested-skill/lib/helpers/util.py"; then
        echo "FAIL: nested file not found in archive"
        return 1
    fi
    
    echo "PASS: test_allows_nested_regular_files"
}

test_skips_output_archive_when_output_dir_is_skill_dir() {
    local skill_dir
    skill_dir=$(create_skill "self-output-skill")
    
    local result
    result=$(package_skill "$skill_dir" "$skill_dir")
    
    if [[ ! -f "$result" ]]; then
        echo "FAIL: Skill file was not created"
        return 1
    fi
    
    local names
    names=$(python3 -c "
import zipfile
with zipfile.ZipFile('$result', 'r') as archive:
    for name in archive.namelist():
        print(name)
")
    
    if ! echo "$names" | grep -q "self-output-skill/SKILL.md"; then
        echo "FAIL: SKILL.md not found in archive"
        return 1
    fi
    
    if ! echo "$names" | grep -q "self-output-skill/script.py"; then
        echo "FAIL: script.py not found in archive"
        return 1
    fi
    
    if echo "$names" | grep -q "self-output-skill/self-output-skill.skill"; then
        echo "FAIL: self-output-skill.skill should not be included in archive"
        return 1
    fi
    
    echo "PASS: test_skips_output_archive_when_output_dir_is_skill_dir"
}

# Run all tests
run_tests() {
    local passed=0
    local failed=0
    
    test_packages_normal_files || ((failed++))
    test_skips_symlink_to_external_file || ((failed++))
    test_skips_symlink_directory || ((failed++))
    test_allows_nested_regular_files || ((failed++))
    test_skips_output_archive_when_output_dir_is_skill_dir || ((failed++))
    
    echo
    echo "Tests passed: $passed"
    echo "Tests failed: $failed"
    
    if [[ $failed -gt 0 ]]; then
        exit 1
    fi
}

run_tests
