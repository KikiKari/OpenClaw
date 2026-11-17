#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "e9b114510619f82c370f91d2e82ffe506d020c2e5ecb2e81f0718fe5d24bcb26", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "ruby"}
# json_processor.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# JSON Processor mit Pydantic Validation und JSON-Repair.
# Für robuste Verarbeitung von LLM-Outputs.

require 'json'
require 'optparse'
require 'pathname'

# Prüfe ob benötigte Gems installiert sind
begin
  require 'dry-validation'
rescue LoadError
  $stderr.puts "Error: dry-validation not installed. Run: gem install dry-validation"
  exit 1
end

HAS_JSON_REPAIR = false
begin
  require 'json_repair'
  HAS_JSON_REPAIR = true
rescue LoadError
  $stderr.puts "Warning: json_repair not installed. Run: gem install json_repair"
end

class JSONProcessingError < StandardError
  # Base exception for JSON processing errors.
end

class JSONValidationError < JSONProcessingError
  # Raised when JSON validation fails.
end

class JSONRepairError < JSONProcessingError
  # Raised when JSON repair fails.
end

def repair_json_string(raw_json)
  # Repariert häufige JSON-Fehler aus LLM-Outputs.
  # 
  # Behebt:
  # - Trailing commas
  # - Einzelne statt doppelte Quotes
  # - JavaScript-Style Kommentare
  # - Unescaped Zeilenumbrüche in Strings
  
  if HAS_JSON_REPAIR
    begin
      repaired = JsonRepair.repair(raw_json)
      return repaired
    rescue => e
      raise JSONRepairError.new("JSON repair failed: #{e.message}")
    end
  else
    # Fallback: Manuelle Reparaturen
    cleaned = raw_json.strip
    
    # Entferne JavaScript-Kommentare
    cleaned = cleaned.gsub(%r{//.*?\n}, "\n")
    cleaned = cleaned.gsub(%r{/\*.*?\*/}m, '')
    
    # Entferne trailing commas vor ] oder }
    cleaned = cleaned.gsub(/,(\s*[}\]])/, '\\1')
    
    return cleaned
  end
end

def parse_json(raw_input, repair: true)
  # Parst JSON-String mit optionaler automatischer Reparatur.
  # 
  # Args:
  #     raw_input: Der zu parsende JSON-String
  #     repair: Ob JSON-Reparatur versucht werden soll (default: true)
  # 
  # Returns:
  #     Geparstes Ruby-Objekt
  # 
  # Raises:
  #     JSONProcessingError: Wenn Parsing fehlschlägt
  
  raw_input = raw_input.strip
  
  # Versuche zuerst direktes Parsing
  begin
    return JSON.parse(raw_input)
  rescue JSON::ParserError
    # continue
  end
  
  # Extrahiere JSON aus Markdown-Code-Blöcken
  if raw_input.include?("```")
    # Suche nach JSON in ```json ... ``` oder ``` ... ```
    patterns = [
      /```json\s*(.*?)\s*```/m,
      /```\s*(\{.*?\})\s*```/m,
      /```\s*(\[.*?\])\s*```/m,
    ]
    
    patterns.each do |pattern|
      raw_input.scan(pattern) do |match|
        match.each do |m|
          begin
            return JSON.parse(m)
          rescue JSON::ParserError
            next
          end
        end
      end
    end
  end
  
  # Versuche Reparatur
  if repair
    begin
      repaired = repair_json_string(raw_input)
      return JSON.parse(repaired)
    rescue JSON::ParserError, JSONRepairError => e
      raise JSONProcessingError.new("Could not parse JSON even after repair: #{e.message}")
    end
  end
  
  raise JSONProcessingError.new("Could not parse JSON")
end

def parse_and_validate(raw_input, schema, repair: true)
  # Parst JSON und validiert gegen ein Schema.
  # 
  # Args:
  #     raw_input: Der zu parsende JSON-String
  #     schema: Dry-validation Schema für Validierung
  #     repair: Ob JSON-Reparatur versucht werden soll
  # 
  # Returns:
  #     Validiertes Hash
  # 
  # Raises:
  #     JSONValidationError: Wenn Validierung fehlschlägt
  
  begin
    data = parse_json(raw_input, repair: repair)
  rescue JSONProcessingError => e
    raise JSONValidationError.new("JSON parsing failed: #{e.message}")
  end
  
  result = schema.call(data)
  
  if result.errors.empty?
    return result.to_h
  else
    raise JSONValidationError.new("Validation failed: #{result.errors}")
  end
end

def validate_tool_call(raw_json, tool_name = nil)
  # Validiert einen OpenClaw/Tool-Call JSON.
  # 
  # Args:
  #     raw_json: Der Tool-Call JSON-String
  #     tool_name: Optionaler erwarteter Tool-Name
  # 
  # Returns:
  #     Validiertes Tool-Call Hash
  
  tool_call_schema = Dry::Validation.Schema do
    required(:tool).filled(:str?)
    required(:arguments).hash
    optional(:reasoning).maybe(:str?)
  end
  
  tool_call = parse_and_validate(raw_json, tool_call_schema, repair: true)
  
  if tool_name && tool_call['tool'] != tool_name
    raise JSONValidationError.new(
      "Expected tool '#{tool_name}', got '#{tool_call['tool']}'"
    )
  end
  
  {
    "tool" => tool_call["tool"],
    "arguments" => tool_call["arguments"],
    "reasoning" => tool_call["reasoning"]
  }
end

def safe_json_loads(raw_input, default: nil, repair: true)
  # Sicheres JSON-Parsing mit Fallback auf Default-Wert.
  # 
  # Args:
  #     raw_input: Der zu parsende JSON-String
  #     default: Rückgabewert bei Fehlschlag (default: nil)
  #     repair: Ob Reparatur versucht werden soll
  # 
  # Returns:
  #     Geparstes Objekt oder Default-Wert
  
  begin
    parse_json(raw_input, repair: repair)
  rescue JSONProcessingError
    default
  end
end

def extract_json_from_text(text)
  # Extrahiert alle JSON-Objekte aus einem Text.
  # 
  # Args:
  #     text: Text, der JSON-Objekte enthalten könnte
  # 
  # Returns:
  #     Liste aller gefundenen und geparsten JSON-Objekte
  
  results = []
  
  # Pattern für JSON-Objekte und Arrays
  patterns = [
    /\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/,  # Objekte
    /\[[^\[\]]*(?:\[[^\[\]*\][^\[\]]*)*\]/  # Arrays
  ]
  
  patterns.each do |pattern|
    text.scan(pattern) do |match|
      begin
        parsed = parse_json(match, repair: true)
        results << parsed
      rescue JSONProcessingError
        next
      end
    end
  end
  
  results
end

if __FILE__ == $0
  # CLI-Interface
  options = {
    repair: true,
    pretty: false,
    file: false
  }
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] input"
    opts.separator ""
    opts.separator "JSON Processor with repair"
    opts.separator ""
    
    opts.on("-f", "--file", "Input is a file path") do
      options[:file] = true
    end
    
    opts.on("-r", "--[no-]repair", "Enable/disable JSON repair (default: enabled)") do |v|
      options[:repair] = v
    end
    
    opts.on("-p", "--pretty", "Pretty print output") do
      options[:pretty] = true
    end
    
    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!
  
  if ARGV.empty?
    $stderr.puts "Error: No input provided"
    exit 1
  end
  
  input = ARGV[0]
  
  begin
    if options[:file]
      content = Pathname.new(input).read
    else
      content = input
    end
    
    result = parse_json(content, repair: options[:repair])
    
    if options[:pretty]
      puts JSON.pretty_generate(result)
    else
      puts JSON.generate(result)
    end
    
  rescue JSONProcessingError => e
    $stderr.puts "Error: #{e.message}"
    exit 1
  rescue => e
    $stderr.puts "Unexpected error: #{e.message}"
    exit 1
  end
end
