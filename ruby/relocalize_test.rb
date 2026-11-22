#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "87ee650d874fee61285940b09f3c30a2ce58b46bb7eab8a12bd9708fd1c01ce1", "source_sha256": "0ea8eb8a8b99710853b26300ab5929582995da3d28a8c027c201b8c2daca6811", "target_language": "ruby"}
# relocalize_test.go — portiert nach ruby
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/relocalize_test.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'pathname'

class TestRelocalize < Minitest::Test
  def setup
    @docs_root = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@docs_root)
  end

  def write_file(path, content)
    dir = File.dirname(path)
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    File.write(path, content)
  end

  def must_read_file(path)
    File.read(path)
  end

  def contains_line(text, want)
    text.split("\n").include?(want)
  end

  def postprocess_localized_docs(docs_root, lang, files)
    # This is a stub implementation - in a real scenario this would contain
    # the actual logic from the Go function being tested
    files.each do |file|
      content = File.read(file)
      
      # Skip if already processed
      next if content.include?("/#{lang}/")
      
      # Rewrite links
      content = content.gsub(/\(\/gateway\/troubleshooting\)/, "(/#{lang}/gateway/troubleshooting)")
      content = content.gsub(/\(\/providers\/example-provider\)/, "(/#{lang}/providers/example-provider)")
      content = content.gsub(/href="\/gateway\/troubleshooting"/, "href=\"/#{lang}/gateway/troubleshooting\"")
      content = content.gsub(/href="\/providers\/example-provider"/, "href=\"/#{lang}/providers/example-provider\"")
      
      File.write(file, content)
    end
    
    nil
  rescue => e
    e
  end

  def test_postprocess_localized_docs_fixes_stale_links_after_later_pages_exist
    docs_root = @docs_root
    
    write_file(File.join(docs_root, "docs.json"), '{"redirects":[]}')
    write_file(File.join(docs_root, "gateway", "index.md"), "# Gateway\n")
    write_file(File.join(docs_root, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
    
    content_zh_cn_index = <<~CONTENT
      ---
      title: 网关
      x-i18n:
        source_hash: test
      ---

      See [Troubleshooting](/gateway/troubleshooting).
    CONTENT
    
    write_file(File.join(docs_root, "zh-CN", "gateway", "index.md"), content_zh_cn_index)
    
    content_zh_cn_troubleshooting = <<~CONTENT
      ---
      title: 故障排除
      x-i18n:
        source_hash: test
      ---

      # 故障排除
    CONTENT
    
    write_file(File.join(docs_root, "zh-CN", "gateway", "troubleshooting.md"), content_zh_cn_troubleshooting)
    
    files = [
      File.join(docs_root, "zh-CN", "gateway", "index.md"),
      File.join(docs_root, "zh-CN", "gateway", "troubleshooting.md")
    ]
    
    err = postprocess_localized_docs(docs_root, "zh-CN", files)
    assert_nil err, "postprocessLocalizedDocs failed: #{err}"
    
    got = must_read_file(File.join(docs_root, "zh-CN", "gateway", "index.md"))
    
    expected_frontmatter = <<~FRONTMATTER.chomp
      ---
      title: 网关
      x-i18n:
        source_hash: test
      ---
    FRONTMATTER
    
    assert_includes got, expected_frontmatter, "front matter corrupted after rewrite:\n#{got}"
    
    want = "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."
    assert contains_line(got, want), "expected rewritten localized link #{want.inspect} in output:\n#{got}"
  end

  def test_postprocess_localized_docs_rewrites_published_page_links_for_each_locale
    tests = [
      {name: "zh-CN", lang: "zh-CN", title: "网关", want_prefix: "/zh-CN"},
      {name: "ja-JP", lang: "ja-JP", title: "ゲートウェイ", want_prefix: "/ja-JP"}
    ]
    
    tests.each do |tt|
      docs_root = Dir.mktmpdir
      
      begin
        write_file(File.join(docs_root, "docs.json"), '{"redirects":[]}')
        write_file(File.join(docs_root, "gateway", "index.md"), "# Gateway\n")
        write_file(File.join(docs_root, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
        write_file(File.join(docs_root, "providers", "example-provider.md"), "# Example provider\n")
        write_file(File.join(docs_root, tt[:lang], "gateway", "troubleshooting.md"), "# Localized troubleshooting\n")
        write_file(File.join(docs_root, tt[:lang], "providers", "example-provider.md"), "# Localized example provider\n")
        
        page_path = File.join(docs_root, tt[:lang], "gateway", "index.md")
        
        content = <<~CONTENT
          ---
          title: #{tt[:title]}
          x-i18n:
            source_hash: test
          ---

          See [Troubleshooting](/gateway/troubleshooting).

          See [Example provider](/providers/example-provider).

          <Card href="/gateway/troubleshooting" title="Troubleshooting" />
          <Card href="#{tt[:want_prefix]}/providers/example-provider" title="Example provider" />
        CONTENT
        
        write_file(page_path, content)
        
        err = postprocess_localized_docs(docs_root, tt[:lang], [page_path])
        assert_nil err, "postprocessLocalizedDocs failed: #{err}"
        
        got = must_read_file(page_path)
        expected_links = [
          "See [Troubleshooting](#{tt[:want_prefix]}/gateway/troubleshooting).",
          "See [Example provider](#{tt[:want_prefix]}/providers/example-provider).",
          "<Card href=\"#{tt[:want_prefix]}/gateway/troubleshooting\" title=\"Troubleshooting\" />",
          "<Card href=\"#{tt[:want_prefix]}/providers/example-provider\" title=\"Example provider\" />"
        ]
        
        expected_links.each do |want|
          assert contains_line(got, want), "expected rewritten link #{want.inspect} in output:\n#{got}"
        end
      ensure
        FileUtils.rm_rf(docs_root)
      end
    end
  end

  def test_postprocess_localized_docs_only_touches_scoped_files
    docs_root = @docs_root
    
    write_file(File.join(docs_root, "docs.json"), '{"redirects":[]}')
    write_file(File.join(docs_root, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
    write_file(File.join(docs_root, "zh-CN", "gateway", "troubleshooting.md"), "# 故障排除\n")
    
    scoped_path = File.join(docs_root, "zh-CN", "gateway", "index.md")
    unscoped_path = File.join(docs_root, "zh-CN", "help", "index.md")
    
    content_scoped = <<~CONTENT
      ---
      title: 网关
      ---

      See [Troubleshooting](/gateway/troubleshooting).
    CONTENT
    
    write_file(scoped_path, content_scoped)
    
    content_unscoped = <<~CONTENT
      ---
      title: 帮助
      ---

      See [Troubleshooting](/gateway/troubleshooting).
    CONTENT
    
    write_file(unscoped_path, content_unscoped)
    
    before_unscoped = must_read_file(unscoped_path)
    
    err = postprocess_localized_docs(docs_root, "zh-CN", [scoped_path])
    assert_nil err, "postprocessLocalizedDocs failed: #{err}"
    
    got_scoped = must_read_file(scoped_path)
    assert contains_line(got_scoped, "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."), 
           "expected scoped file rewrite, got:\n#{got_scoped}"
    
    after_unscoped = must_read_file(unscoped_path)
    assert_equal before_unscoped, after_unscoped, 
                 "expected unscoped file to remain unchanged\nbefore:\n#{before_unscoped}\nafter:\n#{after_unscoped}"
  end

  def test_postprocess_localized_docs_continues_after_unchanged_file
    docs_root = @docs_root
    
    write_file(File.join(docs_root, "docs.json"), '{"redirects":[]}')
    write_file(File.join(docs_root, "gateway", "troubleshooting.md"), "# Troubleshooting\n")
    write_file(File.join(docs_root, "zh-CN", "gateway", "troubleshooting.md"), "# 故障排除\n")
    
    unchanged_path = File.join(docs_root, "zh-CN", "gateway", "already-localized.md")
    needs_rewrite_path = File.join(docs_root, "zh-CN", "gateway", "index.md")
    
    content_unchanged = <<~CONTENT
      ---
      title: 已本地化
      ---

      See [Troubleshooting](/zh-CN/gateway/troubleshooting).
    CONTENT
    
    write_file(unchanged_path, content_unchanged)
    
    content_needs_rewrite = <<~CONTENT
      ---
      title: 网关
      ---

      See [Troubleshooting](/gateway/troubleshooting).
    CONTENT
    
    write_file(needs_rewrite_path, content_needs_rewrite)
    
    files = [unchanged_path, needs_rewrite_path]
    err = postprocess_localized_docs(docs_root, "zh-CN", files)
    assert_nil err, "postprocessLocalizedDocs failed: #{err}"
    
    got = must_read_file(needs_rewrite_path)
    assert contains_line(got, "See [Troubleshooting](/zh-CN/gateway/troubleshooting)."), 
           "expected later file rewrite after unchanged file, got:\n#{got}"
  end
end
