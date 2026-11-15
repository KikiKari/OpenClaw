#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "6ca79be172f2ccd858eca67f16c12d52d441c7ab9b598333b5278094a9c1db2b", "source_sha256": "eb21431dabeaafc82a1e3ccf24278616e46ed082eca1de4d328c758ee82ee2c7", "target_language": "ruby"}
# language_validator.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/language_validator.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/language_validator.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Multi-language script validator supporting 8+ languages.
# WebSearch integration for documentation lookup.

require 'open3'
require 'optparse'
require 'pathname'

# Result of validation process
class ValidationResult
  attr_reader :language, :valid, :errors, :warnings, :doc_url

  def initialize(language:, valid:, errors: [], warnings: [], doc_url: nil)
    @language = language
    @valid = valid
    @errors = errors
    @warnings = warnings
    @doc_url = doc_url
  end
end

# Validator for multiple scripting languages
class LanguageValidator
  LANGUAGES = {
    'bash' => { cmd: 'bash', args: ['-n'], linter: 'shellcheck' },
    'sh' => { cmd: 'sh', args: ['-n'], linter: 'shellcheck' },
    'python' => { cmd: 'python3', args: ['-m', 'py_compile'], linter: 'pylint' },
    'perl' => { cmd: 'perl', args: ['-c'], linter: 'perlcritic' },
    'raku' => { cmd: 'raku', args: ['-c'], linter: nil },
    'powershell' => { cmd: 'pwsh', args: ['-Command', 'Get-Command'], linter: nil },
    'javascript' => { cmd: 'node', args: ['--check'], linter: 'eslint' },
    'tcl' => { cmd: 'tclsh', args: [], linter: nil }
  }.freeze

  def initialize(language, use_websearch: true)
    @language = language.downcase
    @use_websearch = use_websearch
    @config = LANGUAGES[@language]
    raise ArgumentError, "Unsupported language: #{language}" unless @config
  end

  def validate(script_path)
    errors = []
    warnings = []

    # Syntax check
    begin
      stdin, stdout, stderr, wait_thr = Open3.popen3(*([@config[:cmd]] + @config[:args] + [script_path.to_s]))
      stdin.close
      output = stdout.read
      error_output = stderr.read
      exit_status = wait_thr.value

      if exit_status != 0
        errors << error_output
      end
    rescue Errno::ENOENT
      errors << "Command not found: #{@config[:cmd]}"
      doc_url = fetch_docs if @use_websearch
      return ValidationResult.new(
        language: @language,
        valid: false,
        errors: errors,
        warnings: warnings,
        doc_url: doc_url
      )
    rescue Timeout::Error
      errors << 'Validation timeout'
    end

    # Linter check if available
    if @config[:linter]
      linter_warnings = run_linter(script_path)
      warnings.concat(linter_warnings)
    end

    ValidationResult.new(
      language: @language,
      valid: errors.empty?,
      errors: errors,
      warnings: warnings
    )
  end

  private

  def run_linter(script_path)
    linter = @config[:linter]
    warnings = []

    begin
      case linter
      when 'shellcheck'
        stdin, stdout, stderr, wait_thr = Open3.popen3('shellcheck', '-f', 'gcc', script_path.to_s)
        stdin.close
        output = stdout.read
        stderr.read # Read but don't use stderr
        wait_thr.value
        warnings.concat(output.strip.split("\n")) unless output.strip.empty?
      when 'pylint'
        stdin, stdout, stderr, wait_thr = Open3.popen3('pylint', '--output-format=parseable', script_path.to_s)
        stdin.close
        output = stdout.read
        stderr.read # Read but don't use stderr
        wait_thr.value
        warnings.concat(output.strip.split("\n")) unless output.strip.empty?
      end
    rescue Errno::ENOENT
      warnings << "Linter not installed: #{linter}"
    end

    warnings
  end

  def fetch_docs
    return nil unless @use_websearch

    docs = {
      'powershell' => 'https://docs.microsoft.com/powershell/',
      'raku' => 'https://docs.raku.org/',
      'tcl' => 'https://www.tcl.tk/'
    }
    docs[@language]
  end
end

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: language_validator.rb [options] SCRIPT'
    opts.on('--lang LANGUAGE', 'Language (bash/python/perl/etc.)') do |lang|
      options[:lang] = lang
    end
    opts.on('--no-websearch', 'Disable WebSearch') do
      options[:no_websearch] = true
    end
  end.parse!

  if ARGV.empty? || !options[:lang]
    puts 'Missing required arguments. Use --help for usage.'
    exit 1
  end

  script_path = Pathname.new(ARGV[0])
  validator = LanguageValidator.new(options[:lang], use_websearch: !options[:no_websearch])
  result = validator.validate(script_path)

  puts "Language: #{result.language}"
  puts "Valid: #{result.valid}"
  unless result.errors.empty?
    puts "Errors: #{result.errors.length}"
    result.errors.first(5).each do |err|
      puts "  - #{err}"
    end
  end
  unless result.warnings.empty?
    puts "Warnings: #{result.warnings.length}"
    result.warnings.first(5).each do |warn|
      puts "  - #{warn}"
    end
  end
  puts "Docs: #{result.doc_url}" if result.doc_url

  exit(result.valid ? 0 : 1)
end

main if __FILE__ == $PROGRAM_NAME
