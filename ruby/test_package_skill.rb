#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "98c3c25bfdf8543ba3c4260ab1b744582fc183b4da99874f97d8403d0b880abc", "source_sha256": "6b261a50fe632846e59e96b1c3e1f6787ffd534f7204d14bd7df8784873ac691", "target_language": "ruby"}
# test_package_skill.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/test_package_skill.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/test_package_skill.py
# auch in: workspace@local:git/skills/skill-creator/scripts/test_package_skill.py
# auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/test_package_skill.py
# auch in: 1 weiteren Fundstellen
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Regression tests for skill packaging security behavior.

require 'tmpdir'
require 'fileutils'
require 'zip'
require 'minitest/autorun'
require 'mocha/minitest'

# Add script directory to load path
script_dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift(script_dir) unless $LOAD_PATH.include?(script_dir)

# Mock quick_validate module
module QuickValidate
  def self.validate_skill(_path)
    [true, 'Skill is valid!']
  end
end

# Save original module if it exists
original_quick_validate = $LOADED_FEATURES.find { |f| f.include?('quick_validate') }
$LOADED_FEATURES.delete(original_quick_validate) if original_quick_validate

# Load the module under test
require_relative 'package_skill'

class TestPackageSkillSecurity < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir('test_skill_')
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  def create_skill(name = 'test-skill')
    skill_dir = File.join(@temp_dir, name)
    FileUtils.mkdir_p(skill_dir)
    
    File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: test-skill\ndescription: test\n---\n")
    File.write(File.join(skill_dir, 'script.py'), "print('ok')\n")
    
    skill_dir
  end

  def test_packages_normal_files
    skill_dir = create_skill('normal-skill')
    out_dir = File.join(@temp_dir, 'out')
    FileUtils.mkdir_p(out_dir)

    result = PackageSkill.package_skill(skill_dir, out_dir)

    refute_nil(result)
    skill_file = File.join(out_dir, 'normal-skill.skill')
    assert File.exist?(skill_file)
    
    Zip::File.open(skill_file) do |archive|
      names = archive.entries.map(&:name).to_set
      assert_includes(names, 'normal-skill/SKILL.md')
      assert_includes(names, 'normal-skill/script.py')
    end
  end

  def test_skips_symlink_to_external_file
    skill_dir = create_skill('symlink-file-skill')
    outside = File.join(@temp_dir, 'outside-secret.txt')
    File.write(outside, "super-secret\n")
    link = File.join(skill_dir, 'loot.txt')
    out_dir = File.join(@temp_dir, 'out')
    FileUtils.mkdir_p(out_dir)

    begin
      File.symlink(outside, link)
    rescue Errno::EACCES, NotImplementedError
      skip('symlink unsupported on this platform')
    end

    result = PackageSkill.package_skill(skill_dir, out_dir)
    refute_nil(result)
    skill_file = File.join(out_dir, 'symlink-file-skill.skill')
    assert File.exist?(skill_file)
    
    Zip::File.open(skill_file) do |archive|
      names = archive.entries.map(&:name).to_set
      assert_includes(names, 'symlink-file-skill/SKILL.md')
      assert_includes(names, 'symlink-file-skill/script.py')
      refute_includes(names, 'symlink-file-skill/loot.txt')
    end
  end

  def test_skips_symlink_directory
    skill_dir = create_skill('symlink-dir-skill')
    outside_dir = File.join(@temp_dir, 'outside')
    FileUtils.mkdir_p(outside_dir)
    File.write(File.join(outside_dir, 'secret.txt'), "secret\n")
    link = File.join(skill_dir, 'docs')
    out_dir = File.join(@temp_dir, 'out')
    FileUtils.mkdir_p(out_dir)

    begin
      File.symlink(outside_dir, link)
    rescue Errno::EACCES, NotImplementedError
      skip('symlink unsupported on this platform')
    end

    result = PackageSkill.package_skill(skill_dir, out_dir)
    refute_nil(result)
    skill_file = File.join(out_dir, 'symlink-dir-skill.skill')
    
    Zip::File.open(skill_file) do |archive|
      names = archive.entries.map(&:name).to_set
      assert_includes(names, 'symlink-dir-skill/SKILL.md')
      assert_includes(names, 'symlink-dir-skill/script.py')
      refute_includes(names, 'symlink-dir-skill/docs/secret.txt')
    end
  end

  def test_rejects_resolved_path_outside_skill_root
    skill_dir = create_skill('escape-skill')
    out_dir = File.join(@temp_dir, 'out')
    FileUtils.mkdir_p(out_dir)

    # Mock the _is_within method to simulate path validation failure
    PackageSkill.stub(:_is_within, ->(path_obj, _root) {
      return false if File.basename(path_obj) == 'script.py'
      true
    }) do
      result = PackageSkill.package_skill(skill_dir, out_dir)
      assert_nil(result)
    end
  end

  def test_allows_nested_regular_files
    skill_dir = create_skill('nested-skill')
    nested = File.join(skill_dir, 'lib', 'helpers')
    FileUtils.mkdir_p(nested)
    File.write(File.join(nested, 'util.py'), "def run():\n    return 1\n")
    out_dir = File.join(@temp_dir, 'out')
    FileUtils.mkdir_p(out_dir)

    result = PackageSkill.package_skill(skill_dir, out_dir)

    refute_nil(result)
    skill_file = File.join(out_dir, 'nested-skill.skill')
    
    Zip::File.open(skill_file) do |archive|
      names = archive.entries.map(&:name).to_set
      assert_includes(names, 'nested-skill/lib/helpers/util.py')
    end
  end

  def test_skips_output_archive_when_output_dir_is_skill_dir
    skill_dir = create_skill('self-output-skill')

    result = PackageSkill.package_skill(skill_dir, skill_dir)

    refute_nil(result)
    skill_file = File.join(skill_dir, 'self-output-skill.skill')
    assert File.exist?(skill_file)
    
    Zip::File.open(skill_file) do |archive|
      names = archive.entries.map(&:name).to_set
      assert_includes(names, 'self-output-skill/SKILL.md')
      assert_includes(names, 'self-output-skill/script.py')
      refute_includes(names, 'self-output-skill/self-output-skill.skill')
    end
  end
end

Minitest.run if __FILE__ == $0
