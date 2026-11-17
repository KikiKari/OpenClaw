#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "065d906302e9df6664b30fb29ce68facbe478793889931eaa97177438bf671fb", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "ruby"}
# json_batch_processor.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

require 'json'
require 'optparse'
require 'pathname'
require 'thread'

# Versuche, das JSON-Schema gem zu laden (entspricht Pydantic)
begin
  require 'json-schema'
  HAS_JSON_SCHEMA = true
rescue LoadError
  HAS_JSON_SCHEMA = false
end

# JSON Processing Error Klasse
class JSONProcessingError < StandardError; end

# Batch Result Klasse
class BatchResult
  attr_accessor :index, :source, :success, :data, :error

  def initialize(index:, source:, success:, data: nil, error: nil)
    @index = index
    @source = source
    @success = success
    @data = data
    @error = error
  end

  def to_h
    {
      index: @index,
      source: @source,
      success: @success,
      data: @data,
      error: @error
    }
  end
end

# Liest JSON-Lines (NDJSON) Datei Zeile für Zeile
def read_jsonl(file_path)
  lines = []
  File.open(file_path, 'r:utf-8') do |f|
    f.each_with_index do |line, line_num|
      line = line.strip
      next if line.empty?
      begin
        lines << JSON.parse(line)
      rescue JSON::ParserError => e
        lines << BatchResult.new(
          index: line_num + 1,
          source: "#{file_path}:#{line_num + 1}",
          success: false,
          error: "JSON decode error: #{e.message}"
        )
      end
    end
  end
  lines
end

# Verarbeitet eine Liste von Inputs parallel
def process_batch(inputs, processor, max_workers: 4)
  results = []
  queue = Queue.new
  
  inputs.each_with_index { |inp, idx| queue << [inp, idx] }
  
  threads = []
  max_workers.times do
    threads << Thread.new do
      while !queue.empty?
        begin
          inp, idx = queue.pop(true)
          result = processor.call(inp, idx)
          results.push(result)
        rescue ThreadError
          break # Queue ist leer
        end
      end
    end
  end
  
  threads.each(&:join)
  
  results.sort_by! { |r| r.index }
  results
end

# Verarbeitet mehrere JSON-Dateien im Batch
def process_file_batch(file_paths, repair: true, validate_schema: nil, max_workers: 4)
  processor = lambda do |path, idx|
    begin
      content = File.read(path, encoding: 'utf-8')
      
      if validate_schema && HAS_JSON_SCHEMA
        data = parse_and_validate(content, validate_schema, repair: repair)
      else
        data = parse_json(content, repair: repair)
      end
      
      BatchResult.new(
        index: idx,
        source: path.to_s,
        success: true,
        data: data
      )
    rescue JSONProcessingError => e
      BatchResult.new(
        index: idx,
        source: path.to_s,
        success: false,
        error: e.message
      )
    rescue => e
      BatchResult.new(
        index: idx,
        source: path.to_s,
        success: false,
        error: "#{e.class.name}: #{e.message}"
      )
    end
  end
  
  process_batch(file_paths, processor, max_workers: max_workers)
end

# Verarbeitet eine JSON-Lines Datei
def process_jsonl_file(file_path, repair: true, validate_schema: nil)
  results = []
  
  File.open(file_path, 'r:utf-8') do |f|
    f.each_with_index do |line, line_num|
      line = line.strip
      next if line.empty?
      
      begin
        if validate_schema && HAS_JSON_SCHEMA
          data = parse_and_validate(line, validate_schema, repair: repair)
        else
          data = parse_json(line, repair: repair)
        end
        
        results.push(BatchResult.new(
          index: line_num + 1,
          source: "#{file_path}:#{line_num + 1}",
          success: true,
          data: data
        ))
      rescue JSONProcessingError => e
        results.push(BatchResult.new(
          index: line_num + 1,
          source: "#{file_path}:#{line_num + 1}",
          success: false,
          error: e.message
        ))
      end
    end
  end
  
  results
end

# Schreibt BatchResult-Liste als JSON-Lines
def write_jsonl(results, output_path, only_successful: true)
  File.open(output_path, 'w:utf-8') do |f|
    results.each do |result|
      next if only_successful && !result.success
      f.write(JSON.generate(result.to_h, ascii_only: false) + "\n")
    end
  end
end

# JSON parsen mit optionaler Reparatur
def parse_json(content, repair: true)
  begin
    JSON.parse(content)
  rescue JSON::ParserError => e
    if repair
      # Einfache Reparaturversuche
      repaired = content.gsub(/,\s*([\]}])/m, '\1') # Entferne trailing commas
      JSON.parse(repaired)
    else
      raise JSONProcessingError, "JSON parse error: #{e.message}"
    end
  end
end

# JSON parsen und validieren gegen ein Schema
def parse_and_validate(content, schema, repair: true)
  data = parse_json(content, repair: repair)
  
  if HAS_JSON_SCHEMA
    validation = JSON::Validator.validate(schema, data, errors_as_hash: true)
    unless validation[:valid]
      raise JSONProcessingError, "Validation failed: #{validation[:errors].join(', ')}"
    end
  end
  
  data
rescue JSON::Schema::ValidationError => e
  raise JSONProcessingError, "Schema validation error: #{e.message}"
end

# Hauptprogramm
def main
  options = {
    jsonl: false,
    repair: true,
    workers: 4,
    output: nil,
    summary: false
  }
  
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] INPUTS..."
    opts.separator ""
    opts.separator "Batch JSON Processor"
    opts.separator ""
    
    opts.on("--jsonl", "-l", "Treat inputs as JSON-Lines files") do
      options[:jsonl] = true
    end
    
    opts.on("--repair", "-r", "Enable JSON repair") do
      options[:repair] = true
    end
    
    opts.on("--workers NUM", "-w", Integer, "Parallel workers") do |w|
      options[:workers] = w
    end
    
    opts.on("--output FILE", "-o", "Output JSON-Lines file") do |o|
      options[:output] = o
    end
    
    opts.on("--summary", "-s", "Show summary only") do
      options[:summary] = true
    end
    
    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end
  
  begin
    opt_parser.parse!
  rescue OptionParser::InvalidOption => e
    STDERR.puts e.message
    STDERR.puts opt_parser
    exit 1
  end
  
  if ARGV.empty?
    STDERR.puts "No input files provided"
    STDERR.puts opt_parser
    exit 1
  end
  
  all_results = []
  
  if options[:jsonl]
    # JSON-Lines Modus
    ARGV.each do |input_path|
      results = process_jsonl_file(Pathname.new(input_path), repair: options[:repair])
      all_results.concat(results)
    end
  else
    # Standard JSON Batch
    file_paths = ARGV.map { |p| Pathname.new(p) }
    all_results = process_file_batch(
      file_paths,
      repair: options[:repair],
      max_workers: options[:workers]
    )
  end
  
  # Ausgabe
  successful = all_results.count(&:success)
  failed = all_results.size - successful
  
  if options[:summary]
    puts "Processed: #{all_results.size}"
    puts "Successful: #{successful}"
    puts "Failed: #{failed}"
  else
    all_results.each do |result|
      if result.success
        puts JSON.generate(result.data, ascii_only: false)
      else
        STDERR.puts "ERROR [#{result.source}]: #{result.error}"
      end
    end
  end
  
  # Optional: JSONL Output
  if options[:output]
    write_jsonl(all_results, Pathname.new(options[:output]), only_successful: false)
    STDERR.puts "\nResults written to: #{options[:output]}"
  end
  
  # Exit code
  exit(failed == 0 ? 0 : 1)
end

if __FILE__ == $0
  main
end
