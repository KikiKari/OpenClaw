#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "e7d996e6362d1ebc8ac6a723f6dc047d705cc823f2ffc3bd7bdc2e7d92286fa7", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "ruby"}
# changelog-to-html.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

VERSION = ARGV[0] || ''
CHANGELOG_FILE = ARGV[1] || ''

def find_changelog_file
  script_dir = File.dirname(File.realpath(__FILE__))
  
  if File.exist?(File.join(script_dir, '..', 'CHANGELOG.md'))
    return File.join(script_dir, '..', 'CHANGELOG.md')
  elsif File.exist?('CHANGELOG.md')
    return 'CHANGELOG.md'
  elsif File.exist?(File.join('..', 'CHANGELOG.md'))
    return File.join('..', 'CHANGELOG.md')
  else
    raise "Error: Could not find CHANGELOG.md"
  end
end

def extract_version_section(version, file)
  content = []
  found = false
  
  File.readlines(file).each do |line|
    if line.start_with?('## ')
      if line.match(/^##\s+#{Regexp.escape(version)}(\s.*|$)/)
        found = true
        next
      end
      if found
        break
      end
    elsif found
      content << line
    end
  end
  
  content
end

def markdown_to_html(line)
  text = line.dup
  
  # Convert headers
  text.gsub!(/^##### (.*)$/, '<h5>\1</h5>')
  text.gsub!(/^#### (.*)$/, '<h4>\1</h4>')
  text.gsub!(/^### (.*)$/, '<h3>\1</h3>')
  text.gsub!(/^## (.*)$/, '<h2>\1</h2>')
  
  # Convert list items with strong text
  text.gsub!(/^- \*\*([^*]*)\*\*(.*)$/, '<li><strong>\1</strong>\2</li>')
  
  # Convert regular list items
  text.gsub!(/^- ([^*].*)$/, '<li>\1</li>')
  
  # Convert inline strong text
  text.gsub!(/\*\*([^*]*)\*\*/, '<strong>\1</strong>')
  
  # Convert inline code
  text.gsub!(/`([^`]*)`/, '<code>\1</code>')
  
  # Convert links
  text.gsub!(/\[([^\]]*)\]\(([^)]*)\)/, '<a href="\2">\1</a>')
  
  text
end

# Main execution
if VERSION.empty?
  STDERR.puts "Usage: #{$0} <version> [changelog_file]"
  exit 1
end

begin
  changelog_file = CHANGELOG_FILE.empty? ? find_changelog_file : CHANGELOG_FILE
  
  unless File.exist?(changelog_file)
    STDERR.puts "Error: Changelog file '#{changelog_file}' not found"
    exit 1
  end
  
  version_content = extract_version_section(VERSION, changelog_file)
  
  if version_content.empty?
    puts "<h2>OpenClaw #{VERSION}</h2>"
    puts "<p>Latest OpenClaw update.</p>"
    puts "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>"
    exit 0
  end
  
  puts "<h2>OpenClaw #{VERSION}</h2>"
  
  in_list = false
  
  version_content.each do |line|
    if line.start_with?('-')
      if !in_list
        puts "<ul>"
        in_list = true
      end
      puts markdown_to_html(line.chomp)
    else
      if in_list
        puts "</ul>"
        in_list = false
      end
      unless line.strip.empty?
        puts markdown_to_html(line.chomp)
      end
    end
  end
  
  if in_list
    puts "</ul>"
  end
  
  puts "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>"
  
rescue => e
  STDERR.puts e.message
  exit 1
end
