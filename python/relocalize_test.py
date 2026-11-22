#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "85cfb7766011227a51cf7a0669cc18e3ea938a805fe6b51e1d9214730222a35e", "source_sha256": "0ea8eb8a8b99710853b26300ab5929582995da3d28a8c027c201b8c2daca6811", "target_language": "python"}
# relocalize_test.go — portiert nach python
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/relocalize_test.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import os
import tempfile
import unittest
from pathlib import Path

# Import the functions to be tested (assuming they are in a module named 'relocalize')
# You may need to adjust this import based on your actual module structure
try:
    from relocalize import postprocessLocalizedDocs
except ImportError:
    # If the module is not available, we'll define mock functions for syntax checking
    def postprocessLocalizedDocs(docsRoot, lang, files):
        return None

def stringsJoin(*lines):
    return "\n".join(lines)

def mustReadFile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def containsLine(text, want):
    return want in text.split("\n")

class TestPostprocessLocalizedDocs(unittest.TestCase):
    
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp())
        
    def tearDown(self):
        # Clean up temp directory
        import shutil
        shutil.rmtree(self.test_dir)
    
    def test_postprocessLocalizedDocs_fixes_stale_links_after_later_pages_exist(self):
        docs_root = self.test_dir
        
        # Create test files
        (docs_root / "docs.json").write_text('{"redirects":[]}')
        (docs_root / "gateway").mkdir(exist_ok=True)
        (docs_root / "gateway" / "index.md").write_text("# Gateway\n")
        (docs_root / "gateway" / "troubleshooting.md").write_text("# Troubleshooting\n")
        (docs_root / "zh-CN").mkdir()
        (docs_root / "zh-CN" / "gateway").mkdir()
        
        (docs_root / "zh-CN" / "gateway" / "index.md").write_text(stringsJoin(
            "---",
            "title: 网关",
            "x-i18n:",
            "  source_hash: test",
            "---",
            "",
            "See [Troubleshooting](/gateway/troubleshooting)."
        ))
        
        (docs_root / "zh-CN" / "gateway" / "troubleshooting.md").write_text(stringsJoin(
            "---",
            "title: 故障排除",
            "x-i18n:",
            "  source_hash: test",
            "---",
            "",
            "# 故障排除"
        ))

        try:
            postprocessLocalizedDocs(str(docs_root), "zh-CN", [
                str(docs_root / "zh-CN" / "gateway" / "index.md"),
                str(docs_root / "zh-CN" / "gateway" / "troubleshooting.md")
            ])
        except Exception as err:
            self.fail(f"postprocessLocalizedDocs failed: {err}")

        got = mustReadFile(docs_root / "zh-CN" / "gateway" / "index.md")
        if not ("---\ntitle: 网关\nx-i18n:\n  source_hash: test\n---\n\n" in got or 
                "---\ntitle: 网关\nx-i18n:\n  source_hash: test\n---\n#" in got):
            self.fail(f"front matter corrupted after rewrite:\n{got}")
            
        want = "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."
        if not containsLine(got, want):
            self.fail(f'expected rewritten localized link "{want}" in output:\n{got}')

    def test_postprocessLocalizedDocs_rewrites_published_page_links_for_each_locale(self):
        tests = [
            {"name": "zh-CN", "lang": "zh-CN", "title": "网关", "wantPrefix": "/zh-CN"},
            {"name": "ja-JP", "lang": "ja-JP", "title": "ゲートウェイ", "wantPrefix": "/ja-JP"}
        ]

        for tt in tests:
            with self.subTest(tt["name"]):
                docs_root = Path(tempfile.mkdtemp())
                
                # Create test files
                (docs_root / "docs.json").write_text('{"redirects":[]}')
                (docs_root / "gateway").mkdir(exist_ok=True)
                (docs_root / "gateway" / "index.md").write_text("# Gateway\n")
                (docs_root / "gateway" / "troubleshooting.md").write_text("# Troubleshooting\n")
                (docs_root / "providers").mkdir(exist_ok=True)
                (docs_root / "providers" / "example-provider.md").write_text("# Example provider\n")
                (docs_root / tt["lang"]).mkdir()
                (docs_root / tt["lang"] / "gateway").mkdir()
                (docs_root / tt["lang"] / "providers").mkdir()
                (docs_root / tt["lang"] / "gateway" / "troubleshooting.md").write_text("# Localized troubleshooting\n")
                (docs_root / tt["lang"] / "providers" / "example-provider.md").write_text("# Localized example provider\n")

                page_path = docs_root / tt["lang"] / "gateway" / "index.md"
                page_path.write_text(stringsJoin(
                    "---",
                    "title: " + tt["title"],
                    "x-i18n:",
                    "  source_hash: test",
                    "---",
                    "",
                    "See [Troubleshooting](/gateway/troubleshooting).",
                    "",
                    "See [Example provider](/providers/example-provider).",
                    "",
                    '<Card href="/gateway/troubleshooting" title="Troubleshooting" />',
                    '<Card href="' + tt["wantPrefix"] + '/providers/example-provider" title="Example provider" />'
                ))

                try:
                    postprocessLocalizedDocs(str(docs_root), tt["lang"], [str(page_path)])
                except Exception as err:
                    self.fail(f"postprocessLocalizedDocs failed: {err}")

                got = mustReadFile(page_path)
                expected_links = [
                    "See [Troubleshooting](" + tt["wantPrefix"] + "/gateway/troubleshooting).",
                    "See [Example provider](" + tt["wantPrefix"] + "/providers/example-provider).",
                    '<Card href="' + tt["wantPrefix"] + '/gateway/troubleshooting" title="Troubleshooting" />',
                    '<Card href="' + tt["wantPrefix"] + '/providers/example-provider" title="Example provider" />'
                ]
                
                for want in expected_links:
                    if not containsLine(got, want):
                        self.fail(f'expected rewritten link "{want}" in output:\n{got}')
                        
                # Clean up
                import shutil
                shutil.rmtree(docs_root)

    def test_postprocessLocalizedDocs_only_touches_scoped_files(self):
        docs_root = self.test_dir
        
        # Create test files
        (docs_root / "docs.json").write_text('{"redirects":[]}')
        (docs_root / "gateway").mkdir(exist_ok=True)
        (docs_root / "gateway" / "troubleshooting.md").write_text("# Troubleshooting\n")
        (docs_root / "zh-CN").mkdir()
        (docs_root / "zh-CN" / "gateway").mkdir()
        (docs_root / "zh-CN" / "help").mkdir()
        
        scoped_path = docs_root / "zh-CN" / "gateway" / "index.md"
        unscoped_path = docs_root / "zh-CN" / "help" / "index.md"

        scoped_path.write_text(stringsJoin(
            "---",
            "title: 网关",
            "---",
            "",
            "See [Troubleshooting](/gateway/troubleshooting)."
        ))
        
        unscoped_path.write_text(stringsJoin(
            "---",
            "title: 帮助",
            "---",
            "",
            "See [Troubleshooting](/gateway/troubleshooting)."
        ))

        before_unscoped = mustReadFile(unscoped_path)
        try:
            postprocessLocalizedDocs(str(docs_root), "zh-CN", [str(scoped_path)])
        except Exception as err:
            self.fail(f"postprocessLocalizedDocs failed: {err}")

        got_scoped = mustReadFile(scoped_path)
        if not containsLine(got_scoped, "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."):
            self.fail(f"expected scoped file rewrite, got:\n{got_scoped}")

        after_unscoped = mustReadFile(unscoped_path)
        if after_unscoped != before_unscoped:
            self.fail(f"expected unscoped file to remain unchanged\nbefore:\n{before_unscoped}\nafter:\n{after_unscoped}")

    def test_postprocessLocalizedDocs_continues_after_unchanged_file(self):
        docs_root = self.test_dir
        
        # Create test files
        (docs_root / "docs.json").write_text('{"redirects":[]}')
        (docs_root / "gateway").mkdir(exist_ok=True)
        (docs_root / "gateway" / "troubleshooting.md").write_text("# Troubleshooting\n")
        (docs_root / "zh-CN").mkdir()
        (docs_root / "zh-CN" / "gateway").mkdir()
        
        unchanged_path = docs_root / "zh-CN" / "gateway" / "already-localized.md"
        needs_rewrite_path = docs_root / "zh-CN" / "gateway" / "index.md"

        unchanged_path.write_text(stringsJoin(
            "---",
            "title: 已本地化",
            "---",
            "",
            "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."
        ))
        
        needs_rewrite_path.write_text(stringsJoin(
            "---",
            "title: 网关",
            "---",
            "",
            "See [Troubleshooting](/gateway/troubleshooting)."
        ))

        try:
            postprocessLocalizedDocs(str(docs_root), "zh-CN", [str(unchanged_path), str(needs_rewrite_path)])
        except Exception as err:
            self.fail(f"postprocessLocalizedDocs failed: {err}")

        got = mustReadFile(needs_rewrite_path)
        if not containsLine(got, "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."):
            self.fail(f"expected later file rewrite after unchanged file, got:\n{got}")


if __name__ == '__main__':
    unittest.main()
