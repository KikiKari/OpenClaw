#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a6d0eec825ac9f66c9d1b3b7aa5d2a5cb9243605d65196cd456bdaabb15e7ede", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "ruby"}
# glossary.go — portiert nach ruby
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'

class GlossaryEntry
  attr_accessor :source, :target

  def initialize(source:, target:)
    @source = source
    @target = target
  end

  def to_json(*args)
    { source: @source, target: @target }.to_json(*args)
  end

  def self.from_json(hash)
    new(source: hash['source'], target: hash['target'])
  end
end

def load_glossary(path)
  data = File.read(path)
  json_data = JSON.parse(data)
  json_data.map { |entry| GlossaryEntry.from_json(entry) }
rescue Errno::ENOENT
  []
rescue JSON::ParserError => e
  raise "glossary parse failed: #{e.message}"
rescue => e
  raise e
end
