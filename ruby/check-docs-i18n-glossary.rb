#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b8abcdb7c53ed9bf542eee153678bf6f120d0dbdd46524519683c47ed7b22f7b", "source_sha256": "e290d06e27f18dbd9a54def6168fe32ba54f3cdb01ec2175510727f412ff6a70", "target_language": "ruby"}
# check-docs-i18n-glossary.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/check-docs-i18n-glossary.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'open3'
require 'pathname'

ROOT = Dir.pwd
GLOSSARY_PATH = File.join(ROOT, 'docs', '.i18n', 'glossary.zh-CN.json')
DOC_FILE_RE = %r{^docs/(?!zh-CN/).+\.(md|mdx)$}i
LIST_ITEM_LINK_RE = /^\s*(?:[-*]|\d+\.)\s+\[([^\]]+)\]\((\/[^)]+)\)/
MAX_TITLE_WORDS = 8
MAX_LABEL_WORDS = 6
MAX_TERM_LENGTH = 80

def parse_args(argv)
  args = { base: '', head: '' }
  i = 0
  while i < argv.length
    if argv[i] == '--base'
      args[:base] = argv[i + 1] || ''
      i += 1
    elsif argv[i] == '--head'
      args[:head] = argv[i + 1] || ''
      i += 1
    end
    i += 1
  end
  args
end

def run_git(args)
  stdout, stderr, status = Open3.capture3('git', *args, chdir: ROOT)
  unless status.success?
    raise "git command failed: #{stderr}"
  end
  stdout.strip
end

def resolve_base(explicit_base)
  return explicit_base if explicit_base&.strip&.length&.positive?

  env_base = ENV['DOCS_I18N_GLOSSARY_BASE']&.strip
  return env_base if env_base&.length&.positive?

  ['origin/main', 'fork/main', 'main'].each do |candidate|
    begin
      return run_git(['merge-base', candidate, 'HEAD'])
    rescue
      # Try the next candidate
    end
  end

  ''
end

def list_changed_docs(base, head)
  args = ['diff', '--name-only', '--diff-filter=ACMR', base]
  args << head if head&.length&.positive?
  args.concat(['--', 'docs'])

  run_git(args)
    .split("\n")
    .map(&:strip)
    .select { |line| line.match?(DOC_FILE_RE) }
end

def load_glossary_sources
  data = File.read(GLOSSARY_PATH)
  entries = JSON.parse(data)
  sources = entries.map { |entry| (entry['source'] || '').to_s.strip }.select(&:length)
  Set.new(sources)
end

def contains_latin(text)
  !!text.match(/[A-Za-z]/)
end

def word_count(text)
  text.strip.split(/\s+/).select(&:length).length
end

def unquote_scalar(raw)
  value = raw.strip
  if (value.start_with?('"') && value.end_with?('"')) ||
     (value.start_with?("'") && value.end_with?("'"))
    value[1..-2].strip
  else
    value
  end
end

def is_glossary_candidate(term, max_words)
  return false if !term || term.empty?
  return false unless contains_latin(term)
  return false if term.include?('`')
  return false if term.length > MAX_TERM_LENGTH
  word_count(term) <= max_words
end

def read_git_file(base, rel_path)
  run_git(['show', "#{base}:#{rel_path}"])
rescue
  ''
end

def extract_terms(file, text)
  terms = {}
  lines = text.split("\n")

  if lines[0]&.strip == '---'
    in_frontmatter = true
    lines[1..].each_with_index do |line, index|
      break if line.strip == '---'
      
      match = line.match(/^title:\s*(.+)\s*$/)
      if match
        title = unquote_scalar(match[1])
        if is_glossary_candidate(title, MAX_TITLE_WORDS)
          terms[title] = { file: file, line: index + 2, kind: 'title', term: title }
        end
        break
      end
    end
  end

  lines.each_with_index do |line, index|
    match = line.match(LIST_ITEM_LINK_RE)
    next unless match

    label = match[1].strip
    next unless is_glossary_candidate(label, MAX_LABEL_WORDS)

    unless terms.key?(label)
      terms[label] = { file: file, line: index + 1, kind: 'link label', term: label }
    end
  end

  terms
end

def main
  args = parse_args(ARGV)
  base = resolve_base(args[:base])

  if base.empty?
    puts 'docs:check-i18n-glossary: no merge base found; skipping glossary coverage check.'
    exit(0)
  end

  changed_docs = list_changed_docs(base, args[:head])
  exit(0) if changed_docs.empty?

  glossary = load_glossary_sources
  missing = []

  changed_docs.each do |rel_path|
    abs_path = File.join(ROOT, rel_path)
    next unless File.exist?(abs_path)

    current_text = File.read(abs_path)
    current_terms = extract_terms(rel_path, current_text)
    base_terms = extract_terms(rel_path, read_git_file(base, rel_path))

    current_terms.each do |term, match|
      next if base_terms.key?(term)
      next if glossary.include?(term)
      missing << match
    end
  end

  if missing.empty?
    exit(0)
  end

  puts 'docs:check-i18n-glossary: missing zh-CN glossary entries for changed doc labels:'
  missing.each do |match|
    puts "- #{match[:file]}:#{match[:line]} #{match[:kind]} \"#{match[:term]}\""
  end
  puts ''
  puts 'Add exact source terms to docs/.i18n/glossary.zh-CN.json before rerunning docs-i18n.'
  puts "Checked changed English docs relative to #{base}."
  exit(1)
end

main if __FILE__ == $0
