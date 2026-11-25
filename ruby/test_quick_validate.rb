#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d8585b2af13f192f494b186760bdff3e0f11c2b52687f9ca16bc0cb0614d327d", "source_sha256": "2be00c164cb61020637d0364dc8387a8085522b6bfff7606f734a5274046be44", "target_language": "ruby"}
# test_quick_validate.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_quick_validate.py
# auch in: workspace@local:git/skills/skill-creator/scripts/test_quick_validate.py
# auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_quick_validate.py
# auch in: 1 weiteren Fundstellen
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Regression tests for quick skill validation.

require 'tmpdir'
require 'fileutils'
require 'minitest/autorun'
require_relative 'quick_validate'

class TestQuickValidate < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir('test_quick_validate_')
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  def test_accepts_crlf_frontmatter
    skill_dir = File.join(@temp_dir, 'crlf-skill')
    FileUtils.mkdir_p(skill_dir)
    content = "---\r\nname: crlf-skill\r\ndescription: ok\r\n---\r\n# Skill\r\n"
    File.write(File.join(skill_dir, 'SKILL.md'), content, encoding: 'utf-8')

    valid, message = QuickValidate.validate_skill(skill_dir)

    assert valid, message
  end

  def test_rejects_missing_frontmatter_closing_fence
    skill_dir = File.join(@temp_dir, 'bad-skill')
    FileUtils.mkdir_p(skill_dir)
    content = "---\nname: bad-skill\ndescription: missing end\n# no closing fence\n"
    File.write(File.join(skill_dir, 'SKILL.md'), content, encoding: 'utf-8')

    valid, message = QuickValidate.validate_skill(skill_dir)

    refute valid
    assert_equal message, 'Invalid frontmatter format'
  end

  def test_fallback_parser_handles_multiline_frontmatter_without_pyyaml
    skill_dir = File.join(@temp_dir, 'multiline-skill')
    FileUtils.mkdir_p(skill_dir)
    content = <<~CONTENT
      ---
      name: multiline-skill
      description: Works without pyyaml
      allowed-tools:
        - gh
      metadata: |
        {
          "owners": ["team-openclaw"]
        }
      ---
      # Skill
    CONTENT
    File.write(File.join(skill_dir, 'SKILL.md'), content, encoding: 'utf-8')

    previous_yaml = QuickValidate.yaml
    QuickValidate.yaml = nil
    begin
      valid, message = QuickValidate.validate_skill(skill_dir)
    ensure
      QuickValidate.yaml = previous_yaml
    end

    assert valid, message
  end
end
