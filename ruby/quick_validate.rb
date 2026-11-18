#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "199f0d316ca84a6c1d5daeb2b28b06a134ce8c8433175513e47219ba188cbdfa", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "ruby"}
# quick_validate.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
# auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Quick validation script for skills - minimal version

require 'pathname'
require 'yaml'

MAX_SKILL_NAME_LENGTH = 64

def extract_frontmatter(content)
  lines = content.split("\n")
  return nil if lines.empty? || lines[0].strip != '---'
  
  (1...lines.length).each do |i|
    return lines[1...i].join("\n") if lines[i].strip == '---'
  end
  
  nil
end

def parse_simple_frontmatter(frontmatter_text)
  # Minimal fallback parser used when PyYAML is unavailable.
  # Supports simple `key: value` mappings used by SKILL.md frontmatter.
  parsed = {}
  current_key = nil
  
  frontmatter_text.split("\n").each do |raw_line|
    stripped = raw_line.strip
    next if stripped.empty? || stripped.start_with?('#')
    
    is_indented = raw_line[0]&.match?(/\s/)
    if is_indented
      return nil if current_key.nil?
      
      current_value = parsed[current_key]
      parsed[current_key] = current_value ? "#{current_value}\n#{stripped}" : stripped
      next
    end
    
    return nil unless stripped.include?(':')
    
    key, value = stripped.split(':', 2)
    key = key.strip
    value = value.strip
    return nil if key.empty?
    
    if (value.start_with?('"') && value.end_with?('"')) || 
       (value.start_with?("'") && value.end_with?("'"))
      value = value[1..-2]
    end
    
    parsed[key] = value
    current_key = key
  end
  
  parsed
rescue => e
  nil
end

def validate_skill(skill_path)
  # Basic validation of a skill
  skill_path = Pathname.new(skill_path)
  
  skill_md = skill_path / 'SKILL.md'
  return [false, 'SKILL.md not found'] unless skill_md.exist?
  
  begin
    content = skill_md.read(Encoding::UTF_8)
  rescue => e
    return [false, "Could not read SKILL.md: #{e}"]
  end
  
  frontmatter_text = extract_frontmatter(content)
  return [false, 'Invalid frontmatter format'] if frontmatter_text.nil?
  
  begin
    frontmatter = YAML.safe_load(frontmatter_text)
    return [false, 'Frontmatter must be a YAML dictionary'] unless frontmatter.is_a?(Hash)
  rescue Psych::SyntaxError => e
    return [false, "Invalid YAML in frontmatter: #{e}"]
  rescue LoadError
    frontmatter = parse_simple_frontmatter(frontmatter_text)
    return [false, 'Invalid YAML in frontmatter: unsupported syntax without PyYAML installed'] if frontmatter.nil?
  end
  
  allowed_properties = Set.new(['name', 'description', 'license', 'allowed-tools', 'metadata'])
  
  unexpected_keys = frontmatter.keys.to_set - allowed_properties
  unless unexpected_keys.empty?
    allowed = allowed_properties.sort.join(', ')
    unexpected = unexpected_keys.sort.join(', ')
    return [false, "Unexpected key(s) in SKILL.md frontmatter: #{unexpected}. Allowed properties are: #{allowed}"]
  end
  
  return [false, "Missing 'name' in frontmatter"] unless frontmatter.key?('name')
  return [false, "Missing 'description' in frontmatter"] unless frontmatter.key?('description')
  
  name = frontmatter['name']
  return [false, "Name must be a string, got #{name.class.name}"] unless name.is_a?(String)
  name = name.strip
  if !name.empty?
    return [false, "Name '#{name}' should be hyphen-case (lowercase letters, digits, and hyphens only)"] unless name.match?(/^[a-z0-9-]+$/)
    return [false, "Name '#{name}' cannot start/end with hyphen or contain consecutive hyphens"] if name.start_with?('-') || name.end_with?('-') || name.include?('--')
    if name.length > MAX_SKILL_NAME_LENGTH
      return [false, "Name is too long (#{name.length} characters). Maximum is #{MAX_SKILL_NAME_LENGTH} characters."]
    end
  end
  
  description = frontmatter['description']
  return [false, "Description must be a string, got #{description.class.name}"] unless description.is_a?(String)
  description = description.strip
  if !description.empty?
    return [false, 'Description cannot contain angle brackets (< or >)'] if description.include?('<') || description.include?('>')
    if description.length > 1024
      return [false, "Description is too long (#{description.length} characters). Maximum is 1024 characters."]
    end
  end
  
  [true, 'Skill is valid!']
end

if __FILE__ == $0
  if ARGV.length != 1
    puts 'Usage: ruby quick_validate.rb <skill_directory>'
    exit(1)
  end
  
  valid, message = validate_skill(ARGV[0])
  puts message
  exit(valid ? 0 : 1)
end
