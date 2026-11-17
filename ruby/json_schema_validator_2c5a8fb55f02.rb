#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f9057a88aeee8218e42a9d907d46662835eb7c053feda8ee04de865f203b4892", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "ruby"}
# json_schema_validator.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
# Erweitert Pydantic mit externen Schema-Dateien.

require 'json'
require 'pathname'

# Dynamische Imports für optionale Gems
begin
  require 'json-schema'
  HAS_JSONSCHEMA = true
rescue LoadError
  HAS_JSONSCHEMA = false
end

# Eigene Exceptions
class JSONValidationError < StandardError; end
class SchemaValidationError < JSONValidationError
  # Raised when JSON Schema validation fails.
end

# JSON Processor (vereinfachte Version)
class JSONProcessor
  class JSONProcessingError < StandardError; end

  def self.parse_json(raw_input, repair: true)
    begin
      JSON.parse(raw_input)
    rescue JSON::ParserError => e
      raise JSONProcessingError, "Invalid JSON: #{e.message}"
    end
  end
end

def load_schema(schema_source)
  # Lädt ein JSON Schema aus verschiedenen Quellen.
  #
  # Args:
  #     schema_source: Pfad zur Schema-Datei oder Schema-Dict oder JSON String
  #
  # Returns:
  #     Schema als Dictionary

  return schema_source if schema_source.is_a?(Hash)

  schema_path = Pathname.new(schema_source)
  if schema_path.exist?
    begin
      return JSON.parse(schema_path.read)
    rescue JSON::ParserError => e
      raise SchemaValidationError, "Invalid JSON in schema file: #{e.message}"
    end
  end

  # Versuche als JSON String zu parsen
  begin
    JSON.parse(schema_source)
  rescue JSON::ParserError
    raise SchemaValidationError, "Schema not found or invalid: #{schema_source}"
  end
end

def validate_with_jsonschema(data, schema, draft: 'auto')
  # Validiert Daten gegen ein JSON Schema.
  #
  # Args:
  #     data: Zu validierende Daten
  #     schema: JSON Schema (Pfad, String oder Dict)
  #     draft: JSON Schema Draft Version ("auto", "draft7", "2020-12")
  #
  # Returns:
  #     True wenn valid
  #
  # Raises:
  #     SchemaValidationError: Wenn Validierung fehlschlägt

  unless HAS_JSONSCHEMA
    raise SchemaValidationError, 'json-schema gem not installed. Run: gem install json-schema'
  end

  schema_dict = load_schema(schema)

  begin
    JSON::Validator.validate!(schema_dict, data)
    true
  rescue JSON::Schema::ValidationError => e
    raise SchemaValidationError, "Schema validation failed: #{e.message}"
  end
end

def validate_and_convert(raw_input, schema, repair: true)
  # Parst, repariert und validiert JSON gegen Schema.
  #
  # Args:
  #     raw_input: JSON-String
  #     schema: JSON Schema
  #     repair: Ob Reparatur versucht werden soll
  #
  # Returns:
  #     Validierte Daten

  data = JSONProcessor.parse_json(raw_input, repair: repair)
  validate_with_jsonschema(data, schema)
  data
end

class SchemaBuilder
  # Hilfsklasse zum Erstellen von JSON Schemas.

  def self.object(properties, required: nil)
    # Erstellt ein Object-Schema.
    schema = {
      'type' => 'object',
      'properties' => properties
    }
    schema['required'] = required if required
    schema
  end

  def self.string(enum: nil, pattern: nil, min_length: nil)
    # Erstellt ein String-Schema.
    schema = { 'type' => 'string' }
    schema['enum'] = enum if enum
    schema['pattern'] = pattern if pattern
    schema['minLength'] = min_length unless min_length.nil?
    schema
  end

  def self.integer(minimum: nil, maximum: nil)
    # Erstellt ein Integer-Schema.
    schema = { 'type' => 'integer' }
    schema['minimum'] = minimum unless minimum.nil?
    schema['maximum'] = maximum unless maximum.nil?
    schema
  end

  def self.array(items, min_items: nil)
    # Erstellt ein Array-Schema.
    schema = { 'type' => 'array', 'items' => items }
    schema['minItems'] = min_items unless min_items.nil?
    schema
  end
end

def main
  require 'optparse'

  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: json_schema_validator.rb [options] INPUT'

    opts.on('-s', '--schema SCHEMA', 'Schema file') do |s|
      options[:schema] = s
    end

    opts.on('-f', '--file', 'Input is file') do
      options[:file] = true
    end

    opts.on('-r', '--[no-]repair', 'Repair JSON (default: true)') do |r|
      options[:repair] = r
    end

    opts.on('-h', '--help', 'Show this message') do
      puts opts
      exit
    end
  end.parse!

  if ARGV.empty? || !options[:schema]
    puts 'Missing required arguments. Use --help for usage.'
    exit 1
  end

  input_arg = ARGV.first

  # Lade Input (Auto-detect file vs string)
  input_path = Pathname.new(input_arg)
  raw_input = if options[:file] || (input_path.exist? && input_path.file?)
                input_path.read
              else
                input_arg
              end

  begin
    result = validate_and_convert(raw_input, options[:schema], repair: options[:repair] || true)
    puts JSON.pretty_generate(result)
    $stderr.puts "\n✓ Validation passed"
  rescue => e
    $stderr.puts "✗ Validation failed: #{e.message}"
    exit 1
  end
end

main if __FILE__ == $0
