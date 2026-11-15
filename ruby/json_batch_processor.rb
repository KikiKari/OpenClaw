#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1e83ec3ffb6d1f1bdbe16287100eaec72db2a551f2a00815bab7e1993f7034cb", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "ruby"}
# json_batch_processor.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).

require 'json'
require 'pathname'
require 'optparse'
require 'thread'

# Custom exception class for JSON processing errors
class JSONProcessingError < StandardError; end

# Placeholder for parse_json function - should be implemented separately
def parse_json(content, repair: true)
  # This is a simplified version - actual implementation would depend on your needs
  begin
    JSON.parse(content)
  rescue JSON::ParserError => e
    raise JSONProcessingError, "JSON parsing failed: #{e.message}" if !repair

    # Simple repair attempt (remove trailing commas)
    repaired = content.gsub(/,\s*(\]|\})/, '\\1')
    JSON.parse(repaired)
  end
end

# Placeholder for parse_and_validate function
def parse_and_validate(content, model_class, repair: true)
  # In a real implementation, this would use a validation library similar to Pydantic
  parse_json(content, repair: repair)
end

# Ergebnis einer Batch-Verarbeitung.
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
      "index" => @index,
      "source" => @source,
      "success" => @success,
      "data" => @data,
      "error" => @error
    }
  end
end

# Liest JSON-Lines (NDJSON) Datei Zeile für Zeile.
#
# @param file_path [Pathname] Pfad zur .jsonl oder .ndjson Datei
# @return [Enumerator] Geparste JSON-Objekte
def read_jsonl(file_path)
  Enumerator.new do |yielder|
    File.open(file_path, 'r', encoding: 'utf-8') do |f|
      f.each_with_index do |line, line_num|
        line = line.strip
        next if line.empty?

        begin
          yielder << JSON.parse(line)
        rescue JSON::ParserError => e
          yielder << BatchResult.new(
            index: line_num + 1,
            source: "#{file_path}:#{line_num + 1}",
            success: false,
            error: "JSON decode error: #{e}"
          )
        end
      end
    end
  end
end

# Verarbeitet eine Liste von Inputs parallel.
#
# @param inputs [Array] Liste der zu verarbeitenden Eingaben (Strings oder Pfade)
# @param processor [Proc] Funktion, die (input, index) -> BatchResult zurückgibt
# @param max_workers [Integer] Anzahl paralleler Worker
# @return [Array<BatchResult>] Liste der BatchResult-Objekte
def process_batch(inputs, processor, max_workers: 4)
  results = []
  mutex = Mutex.new

  threads = []
  queue = Queue.new

  inputs.each_with_index { |inp, idx| queue.push([inp, idx]) }

  max_workers.times do
    threads << Thread.new do
      while !queue.empty?
        begin
          inp, idx = queue.pop(true)
          result = processor.call(inp, idx)
          mutex.synchronize { results << result }
        rescue ThreadError
          # Queue is empty, thread can exit
          break
        rescue => e
          mutex.synchronize do
            results << BatchResult.new(
              index: idx,
              source: inp.to_s,
              success: false,
              error: "Unexpected error: #{e}"
            )
          end
        end
      end
    end
  end

  threads.each(&:join)

  # Sortiere nach Index
  results.sort_by!(&:index)
  results
end

# Verarbeitet mehrere JSON-Dateien im Batch.
#
# @param file_paths [Array<Pathname>] Liste der Datei-Pfade
# @param repair [Boolean] Ob JSON-Reparatur angewendet werden soll
# @param validate_model [Class, nil] Optionales Validierungsmodell
# @param max_workers [Integer] Parallele Worker
# @return [Array<BatchResult>] Liste der BatchResult-Objekte
def process_file_batch(file_paths, repair: true, validate_model: nil, max_workers: 4)
  processor = lambda do |path, idx|
    begin
      content = Pathname.new(path).read(encoding: 'utf-8')

      if validate_model
        data = parse_and_validate(content, validate_model, repair: repair)
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

# Verarbeitet eine JSON-Lines Datei.
#
# @param file_path [Pathname] Pfad zur .jsonl Datei
# @param repair [Boolean] Ob Reparatur angewendet werden soll
# @param validate_model [Class, nil] Optionales Validierungsmodell
# @return [Array<BatchResult>] Liste der BatchResult-Objekte
def process_jsonl_file(file_path, repair: true, validate_model: nil)
  results = []

  File.open(file_path, 'r', encoding: 'utf-8') do |f|
    f.each_with_index do |line, line_num|
      line = line.strip
      next if line.empty?

      begin
        if validate_model
          data = parse_and_validate(line, validate_model, repair: repair)
        else
          data = parse_json(line, repair: repair)
        end

        results << BatchResult.new(
          index: line_num + 1,
          source: "#{file_path}:#{line_num + 1}",
          success: true,
          data: data
        )
      rescue JSONProcessingError => e
        results << BatchResult.new(
          index: line_num + 1,
          source: "#{file_path}:#{line_num + 1}",
          success: false,
          error: e.message
        )
      end
    end
  end

  results
end

# Schreibt BatchResult-Liste als JSON-Lines.
#
# @param results [Array<BatchResult>] Liste der Ergebnisse
# @param output_path [Pathname] Ausgabedatei
# @param only_successful [Boolean] Nur erfolgreiche Ergebnisse schreiben
def write_jsonl(results, output_path, only_successful: true)
  File.open(output_path, 'w', encoding: 'utf-8') do |f|
    results.each do |result|
      next if only_successful && !result.success

      f.write(JSON.generate(result.to_h, ascii_only: false) + "\n")
    end
  end
end

def main
  options = {
    jsonl: false,
    repair: true,
    workers: 4,
    output: nil,
    summary: false
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] INPUTS..."
    opts.separator ""
    opts.separator "Batch JSON Processor"

    opts.on("--jsonl", "-l", "Treat inputs as JSON-Lines files") do
      options[:jsonl] = true
    end

    opts.on("--repair", "-r", "Enable JSON repair") do
      options[:repair] = true
    end

    opts.on("--workers WORKERS", "-w", Integer, "Parallel workers") do |w|
      options[:workers] = w
    end

    opts.on("--output FILE", "-o", "Output JSON-Lines file") do |file|
      options[:output] = file
    end

    opts.on("--summary", "-s", "Show summary only") do
      options[:summary] = true
    end

    opts.on("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end

  begin
    parser.parse!
    raise OptionParser::MissingArgument if ARGV.empty?
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts parser.help
    exit 1
  end

  inputs = ARGV

  all_results = []

  if options[:jsonl]
    # JSON-Lines Modus
    inputs.each do |input_path|
      results = process_jsonl_file(Pathname.new(input_path), repair: options[:repair])
      all_results.concat(results)
    end
  else
    # Standard JSON Batch
    file_paths = inputs.map { |p| Pathname.new(p) }
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
        $stderr.puts "ERROR [#{result.source}]: #{result.error}"
      end
    end
  end

  # Optional: JSONL Output
  if options[:output]
    write_jsonl(all_results, Pathname.new(options[:output]), only_successful: false)
    $stderr.puts "\nResults written to: #{options[:output]}"
  end

  # Exit code
  exit(failed == 0 ? 0 : 1)
end

main if __FILE__ == $0
