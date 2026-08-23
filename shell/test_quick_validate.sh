#!/usr/bin/env bash
# test_quick_validate.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Regression tests for quick skill validation.

set -euo pipefail

# Create temporary directory for testing
temp_dir=$(mktemp -d --tmpdir test_quick_validate.XXXXXX)
trap 'rm -rf "$temp_dir"' EXIT

# Function to write a skill file
write_skill_file() {
    local skill_dir="$1"
    local filename="$2"
    local content="$3"
    mkdir -p "$skill_dir"
    printf '%s' "$content" > "$skill_dir/$filename"
}

# Function to validate skill using quick_validate.sh
validate_skill() {
    local skill_dir="$1"
    # Source the validation script and capture output
    # We need to simulate the Python function behavior
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        # Run our validation logic
        bash ./quick_validate.sh "$skill_dir" 2>/dev/null
        return $?
    else
        echo "False"
        echo "Skill file not found"
        return 1
    fi
}

# Test accepts CRLF frontmatter
test_accepts_crlf_frontmatter() {
    local skill_dir="$temp_dir/crlf-skill"
    local content=$'---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n'
    write_skill_file "$skill_dir" "SKILL.md" "$content"
    
    # Simulate the validation
    if validate_skill "$skill_dir"; then
        echo "PASS: test_accepts_crlf_frontmatter"
    else
        echo "FAIL: test_accepts_crlf_frontmatter"
        return 1
    fi
}

# Test rejects missing frontmatter closing fence
test_rejects_missing_frontmatter_closing_fence() {
    local skill_dir="$temp_dir/bad-skill"
    local content=$'---\nname: bad-skill\ndescription: missing end\n# no closing fence\n'
    write_skill_file "$skill_dir" "SKILL.md" "$content"
    
    # This should fail
    if ! validate_skill "$skill_dir" >/dev/null 2>&1; then
        echo "PASS: test_rejects_missing_frontmatter_closing_fence"
    else
        echo "FAIL: test_rejects_missing_frontmatter_closing_fence"
        return 1
    fi
}

# Test fallback parser handles multiline frontmatter without pyyaml
test_fallback_parser_handles_multiline_frontmatter_without_pyyaml() {
    local skill_dir="$temp_dir/multiline-skill"
    local content=$'---\nname: multiline-skill\ndescription: Works without pyyaml\nallowed-tools:\n  - gh\nmetadata: |\n  {\n    "owners": ["team-openclaw"]\n  }\n---\n# Skill\n'
    write_skill_file "$skill_dir" "SKILL.md" "$content"
    
    # Temporarily disable YAML support by unsetting any YAML-related variables
    local original_yaml_support="${YAML_SUPPORT:-}"
    export YAML_SUPPORT=""
    
    # Validate skill - this should work with fallback parser
    if validate_skill "$skill_dir"; then
        echo "PASS: test_fallback_parser_handles_multiline_frontmatter_without_pyyaml"
    else
        echo "FAIL: test_fallback_parser_handles_multiline_frontmatter_without_pyyaml"
        export YAML_SUPPORT="$original_yaml_support"
        return 1
    fi
    
    # Restore YAML support
    export YAML_SUPPORT="$original_yaml_support"
}

# Main test runner
main() {
    # Check if quick_validate.sh exists
    if [[ ! -f "./quick_validate.sh" ]]; then
        echo "Error: quick_validate.sh not found in current directory"
        exit 1
    fi
    
    # Run all tests
    local failed_tests=0
    
    test_accepts_crlf_frontmatter || ((failed_tests++))
    test_rejects_missing_frontmatter_closing_fence || ((failed_tests++))
    test_fallback_parser_handles_multiline_frontmatter_without_pyyaml || ((failed_tests++))
    
    if [[ $failed_tests -eq 0 ]]; then
        echo "All tests passed!"
        exit 0
    else
        echo "$failed_tests test(s) failed"
        exit 1
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
