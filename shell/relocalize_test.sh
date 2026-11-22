#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "12d1b72ba3f049fa1bedb412bf4d804da49b68b1fc190eebcead48ed360df507", "source_sha256": "0ea8eb8a8b99710853b26300ab5929582995da3d28a8c027c201b8c2daca6811", "target_language": "shell"}
# relocalize_test.go — portiert nach shell
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/relocalize_test.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Test cases for postprocessLocalizedDocs function
# These tests verify that the function correctly rewrites links in localized documentation files

test_postprocess_fixes_stale_links() {
    local docs_root
    docs_root=$(mktemp -d)
    trap 'rm -rf "$docs_root"' EXIT

    # Create test files
    mkdir -p "$docs_root/gateway" "$docs_root/zh-CN/gateway"
    
    echo '{"redirects":[]}' > "$docs_root/docs.json"
    echo "# Gateway" > "$docs_root/gateway/index.md"
    echo "# Troubleshooting" > "$docs_root/gateway/troubleshooting.md"
    
    cat > "$docs_root/zh-CN/gateway/index.md" <<'EOF'
---
title: 网关
x-i18n:
  source_hash: test
---

See [Troubleshooting](/gateway/troubleshooting).
EOF

    cat > "$docs_root/zh-CN/gateway/troubleshooting.md" <<'EOF'
---
title: 故障排除
x-i18n:
  source_hash: test
---

# 故障排除
EOF

    # Run the function under test
    if ! postprocessLocalizedDocs "$docs_root" "zh-CN" \
        "$docs_root/zh-CN/gateway/index.md" \
        "$docs_root/zh-CN/gateway/troubleshooting.md"; then
        echo "postprocessLocalizedDocs failed" >&2
        return 1
    fi

    local got
    got=$(cat "$docs_root/zh-CN/gateway/index.md")
    
    if [[ ! "$got" =~ "---"$'\n'"title: 网关"$'\n'"x-i18n:"$'\n'"  source_hash: test"$'\n'"---"$'\n' ]]; then
        echo "front matter corrupted after rewrite:" >&2
        echo "$got" >&2
        return 1
    fi
    
    local want="See [Troubleshooting](/zh-CN/gateway/troubleshooting)."
    if ! contains_line "$got" "$want"; then
        echo "expected rewritten localized link '$want' in output:" >&2
        echo "$got" >&2
        return 1
    fi
}

test_postprocess_rewrites_published_page_links() {
    local docs_root
    docs_root=$(mktemp -d)
    trap 'rm -rf "$docs_root"' EXIT

    # Test both languages
    local tests_lang_title_prefix=(
        "zh-CN|网关|/zh-CN"
        "ja-JP|ゲートウェイ|/ja-JP"
    )
    
    for test_case in "${tests_lang_title_prefix[@]}"; do
        IFS='|' read -r lang title want_prefix <<< "$test_case"
        
        # Reset for each language
        rm -rf "$docs_root"/*
        mkdir -p "$docs_root/gateway" "$docs_root/providers" \
                 "$docs_root/$lang/gateway" "$docs_root/$lang/providers"
        
        echo '{"redirects":[]}' > "$docs_root/docs.json"
        echo "# Gateway" > "$docs_root/gateway/index.md"
        echo "# Troubleshooting" > "$docs_root/gateway/troubleshooting.md"
        echo "# Example provider" > "$docs_root/providers/example-provider.md"
        echo "# Localized troubleshooting" > "$docs_root/$lang/gateway/troubleshooting.md"
        echo "# Localized example provider" > "$docs_root/$lang/providers/example-provider.md"

        local page_path="$docs_root/$lang/gateway/index.md"
        cat > "$page_path" <<EOF
---
title: $title
x-i18n:
  source_hash: test
---

See [Troubleshooting](/gateway/troubleshooting).

See [Example provider](/providers/example-provider).

<Card href="/gateway/troubleshooting" title="Troubleshooting" />
<Card href="$want_prefix/providers/example-provider" title="Example provider" />
EOF

        if ! postprocessLocalizedDocs "$docs_root" "$lang" "$page_path"; then
            echo "postprocessLocalizedDocs failed for $lang" >&2
            return 1
        fi

        local got
        got=$(cat "$page_path")
        local expected_links=(
            "See [Troubleshooting]($want_prefix/gateway/troubleshooting)."
            "See [Example provider]($want_prefix/providers/example-provider)."
            "<Card href=\"$want_prefix/gateway/troubleshooting\" title=\"Troubleshooting\" />"
            "<Card href=\"$want_prefix/providers/example-provider\" title=\"Example provider\" />"
        )
        
        for want in "${expected_links[@]}"; do
            if ! contains_line "$got" "$want"; then
                echo "expected rewritten link '$want' in output:" >&2
                echo "$got" >&2
                return 1
            fi
        done
    done
}

test_postprocess_only_touches_scoped_files() {
    local docs_root
    docs_root=$(mktemp -d)
    trap 'rm -rf "$docs_root"' EXIT

    mkdir -p "$docs_root/gateway" "$docs_root/zh-CN/gateway" "$docs_root/zh-CN/help"
    
    echo '{"redirects":[]}' > "$docs_root/docs.json"
    echo "# Troubleshooting" > "$docs_root/gateway/troubleshooting.md"
    echo "# 故障排除" > "$docs_root/zh-CN/gateway/troubleshooting.md"

    local scoped_path="$docs_root/zh-CN/gateway/index.md"
    local unscoped_path="$docs_root/zh-CN/help/index.md"

    cat > "$scoped_path" <<'EOF'
---
title: 网关
---

See [Troubleshooting](/gateway/troubleshooting).
EOF

    cat > "$unscoped_path" <<'EOF'
---
title: 帮助
---

See [Troubleshooting](/gateway/troubleshooting).
EOF

    local before_unscoped
    before_unscoped=$(cat "$unscoped_path")
    
    if ! postprocessLocalizedDocs "$docs_root" "zh-CN" "$scoped_path"; then
        echo "postprocessLocalizedDocs failed" >&2
        return 1
    fi

    local got_scoped
    got_scoped=$(cat "$scoped_path")
    if ! contains_line "$got_scoped" "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."; then
        echo "expected scoped file rewrite, got:" >&2
        echo "$got_scoped" >&2
        return 1
    fi

    local after_unscoped
    after_unscoped=$(cat "$unscoped_path")
    if [[ "$after_unscoped" != "$before_unscoped" ]]; then
        echo "expected unscoped file to remain unchanged" >&2
        echo "before:" >&2
        echo "$before_unscoped" >&2
        echo "after:" >&2
        echo "$after_unscoped" >&2
        return 1
    fi
}

test_postprocess_continues_after_unchanged_file() {
    local docs_root
    docs_root=$(mktemp -d)
    trap 'rm -rf "$docs_root"' EXIT

    mkdir -p "$docs_root/gateway" "$docs_root/zh-CN/gateway"
    
    echo '{"redirects":[]}' > "$docs_root/docs.json"
    echo "# Troubleshooting" > "$docs_root/gateway/troubleshooting.md"
    echo "# 故障排除" > "$docs_root/zh-CN/gateway/troubleshooting.md"

    local unchanged_path="$docs_root/zh-CN/gateway/already-localized.md"
    local needs_rewrite_path="$docs_root/zh-CN/gateway/index.md"

    cat > "$unchanged_path" <<'EOF'
---
title: 已本地化
---

See [Troubleshooting](/zh-CN/gateway/troubleshooting).
EOF

    cat > "$needs_rewrite_path" <<'EOF'
---
title: 网关
---

See [Troubleshooting](/gateway/troubleshooting).
EOF

    if ! postprocessLocalizedDocs "$docs_root" "zh-CN" "$unchanged_path" "$needs_rewrite_path"; then
        echo "postprocessLocalizedDocs failed" >&2
        return 1
    fi

    local got
    got=$(cat "$needs_rewrite_path")
    if ! contains_line "$got" "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."; then
        echo "expected later file rewrite after unchanged file, got:" >&2
        echo "$got" >&2
        return 1
    fi
}

# Helper functions (simulating the Go helper functions)

contains_line() {
    local text="$1"
    local want="$2"
    
    while IFS= read -r line; do
        if [[ "$line" == "$want" ]]; then
            return 0
        fi
    done <<< "$text"
    
    return 1
}

# Main test runner
main() {
    echo "Running tests..."
    
    test_postprocess_fixes_stale_links
    echo "✓ TestPostprocessLocalizedDocsFixesStaleLinksAfterLaterPagesExist passed"
    
    test_postprocess_rewrites_published_page_links
    echo "✓ TestPostprocessLocalizedDocsRewritesPublishedPageLinksForEachLocale passed"
    
    test_postprocess_only_touches_scoped_files
    echo "✓ TestPostprocessLocalizedDocsOnlyTouchesScopedFiles passed"
    
    test_postprocess_continues_after_unchanged_file
    echo "✓ TestPostprocessLocalizedDocsContinuesAfterUnchangedFile passed"
    
    echo "All tests passed!"
}

# Execute main function
main "$@"
