#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d2ed041b727a45ea6f7cbd2a42e48f11326c18c596a30702a86bb9c56c1e37e3", "source_sha256": "d8cfbb58894cc82e4e8ba7def8f5bcc6b6c011986e853dba0f1c96ca81a4b49e", "target_language": "ruby"}
# docs-list.js — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/docs-list.js
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'pathname'
require 'json'

# Handle broken pipe errors gracefully
trap('PIPE', 'EXIT')

DOCS_DIR = Pathname.new(Dir.pwd) / 'docs'

unless DOCS_DIR.exist?
  STDERR.puts 'docs:list: missing docs directory. Run from repo root.'
  exit 1
end

unless DOCS_DIR.directory?
  STDERR.puts 'docs:list: docs path is not a directory.'
  exit 1
end

EXCLUDED_DIRS = Set.new(['archive', 'research'])

##
# Filters out nil/empty values and converts to strings
#
def compact_strings(values)
  result = []
  values.each do |value|
    next if value.nil?

    normalized = case value
                 when String
                   value.strip
                 when Numeric, TrueClass, FalseClass
                   value.to_s.strip
                 else
                   nil
                 end

    result << normalized if normalized&.length&.> 0
  end
  result
end

##
# Recursively walks through directories to find markdown files
#
def walk_markdown_files(dir, base = dir)
  files = []
  Dir.children(dir).sort.each do |entry_name|
    next if entry_name.start_with?('.')

    full_path = File.join(dir, entry_name)
    if File.directory?(full_path)
      next if EXCLUDED_DIRS.include?(entry_name)

      files.concat(walk_markdown_files(full_path, base))
    elsif File.file?(full_path) && entry_name.end_with?('.md')
      files << Pathname.new(full_path).relative_path_from(base).to_s
    end
  end
  files
end

##
# Extracts metadata from markdown file's front matter
#
def extract_metadata(full_path)
  content = File.read(full_path, encoding: 'UTF-8')

  unless content.start_with?('---')
    return { summary: nil, read_when: [], error: 'missing front matter' }
  end

  end_index = content.index("\n---", 3)
  if end_index.nil?
    return { summary: nil, read_when: [], error: 'unterminated front matter' }
  end

  front_matter = content[3...end_index].strip
  lines = front_matter.split("\n")

  summary_line = nil
  read_when = []
  collecting_field = nil

  lines.each do |raw_line|
    line = raw_line.strip

    if line.start_with?('summary:')
      summary_line = line
      collecting_field = nil
      next
    end

    if line.start_with?('read_when:')
      collecting_field = 'read_when'
      inline = line['read_when:'.length..].strip
      if inline.start_with?('[') && inline.end_with?(']')
        begin
          parsed = JSON.parse(inline.gsub("'", '"'))
          read_when.concat(compact_strings(parsed)) if parsed.is_a?(Array)
        rescue JSON::ParserError
          # ignore malformed inline arrays
        end
      end
      next
    end

    if collecting_field == 'read_when'
      if line.start_with?('- ')
        hint = line[2..].strip
        read_when << hint if hint&.length&.> 0
      elsif line.empty?
        # allow blank lines inside the list
      else
        collecting_field = nil
      end
    end
  end

  unless summary_line
    return { summary: nil, read_when: read_when, error: 'summary key missing' }
  end

  summary_value = summary_line['summary:'.length..].strip
  normalized = summary_value.gsub(/^['"]|['"]$/, '').gsub(/\s+/, ' ').strip

  if normalized.empty?
    return { summary: nil, read_when: read_when, error: 'summary is empty' }
  end

  { summary: normalized, read_when: read_when }
end

puts 'Listing all markdown files in docs folder:'

markdown_files = walk_markdown_files(DOCS_DIR)

markdown_files.each do |relative_path|
  full_path = File.join(DOCS_DIR, relative_path)
  metadata = extract_metadata(full_path)
  summary = metadata[:summary]
  read_when = metadata[:read_when]
  error = metadata[:error]

  if summary
    puts "#{relative_path} - #{summary}"
    unless read_when.empty?
      puts "  Read when: #{read_when.join('; ')}"
    end
  else
    reason = error ? " - [#{error}]" : ''
    puts "#{relative_path}#{reason}"
  end
end

puts <<~REMINDER

  Reminder: keep docs up to date as behavior changes. When your task matches any "Read when" hint above (React hooks, cache directives, database work, tests, etc.), read that doc before coding, and suggest new coverage when it is missing.
REMINDER
