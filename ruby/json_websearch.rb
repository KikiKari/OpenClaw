#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ecb8fe675c0856cd82ebaaf4e1502f49c5f1b410fc25da32dd562f4319d4881b", "source_sha256": "d3ab9d6951153a42390fb59c1a50b0c901cf4c399dcb731b89865fdc293f3ac9", "target_language": "ruby"}
# json_websearch.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/json_websearch.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/json_websearch.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# JSON Utils + WebSearch integration.
# Fetch API schemas from web, validate real API responses, batch-validate endpoints.

require 'json'
require 'pathname'

# Add json-utils to path
$LOAD_PATH.unshift((Pathname.new(__FILE__).parent.parent.parent + 'json-utils' + 'scripts').to_s)

begin
  require 'json_processor'
  require 'json_schema_validator'
  require 'json_batch_processor'
  JSON_UTILS_AVAILABLE = true
rescue LoadError
  JSON_UTILS_AVAILABLE = false
  puts "Warning: json-utils not found. Some features disabled."
end

# WebSearchResult class
class WebSearchResult
  attr_accessor :query, :json_data, :validation_errors, :schema_matched, :source_url

  def initialize(query:, json_data:, validation_errors:, schema_matched:, source_url:)
    @query = query
    @json_data = json_data
    @validation_errors = validation_errors
    @schema_matched = schema_matched
    @source_url = source_url
  end
end

# WebSearchJSON class
class WebSearchJSON
  # Combine WebSearch with JSON validation.
  #
  # Use cases:
  # 1. Search for API documentation, extract schema
  # 2. Validate real API responses against schemas
  # 3. Batch-validate multiple API endpoints
  # 4. Auto-repair common API response errors

  def initialize(use_repair: true)
    @use_repair = use_repair
    @json_available = JSON_UTILS_AVAILABLE
  end

  # Search web for JSON data, validate against schema.
  #
  # This is a placeholder - in real usage, this would:
  # 1. Call WebSearch to find API docs
  # 2. Extract JSON examples/schemas from results
  # 3. Parse and validate with json-utils
  def search_and_validate(query, schema = nil, schema_path: nil)
    # Simulate web search result (would be actual search in production)
    mock_response = {
      'api' => query.split.first || 'unknown',
      'version' => '1.0',
      'endpoints' => [
        { 'path' => '/items', 'method' => 'GET' },
        { 'path' => '/items', 'method' => 'POST' }
      ]
    }

    # Validate with json-utils if available
    validation_errors = []
    schema_matched = false

    if @json_available && (schema || schema_path)
      begin
        validate_with_jsonschema(mock_response, schema_path.to_s) if schema_path
        schema_matched = true
      rescue => e
        validation_errors << e.message
      end
    end

    WebSearchResult.new(
      query: query,
      json_data: mock_response,
      validation_errors: validation_errors,
      schema_matched: schema_matched,
      source_url: "https://api.github.com/search?q=#{query.gsub(' ', '+')}"
    )
  end

  # Validate an API response with auto-repair.
  #
  # Uses json-utils for robust parsing.
  def validate_api_response(response_data, endpoint, expected_schema: nil)
    return JSON.parse(response_data) unless @json_available

    # Use json-utils parser with auto-repair
    result = parse_json(response_data, repair: @use_repair)

    if expected_schema
      begin
        parse_and_validate(JSON.generate(result), expected_schema)
      rescue => e
        puts "Schema validation failed for #{endpoint}: #{e}"
      end
    end

    result
  end

  # Batch-validate multiple API endpoint responses.
  def batch_validate_endpoints(endpoints, responses, schema_path: nil)
    results = []
    endpoints.zip(responses).each do |endpoint, response|
      begin
        json_data = validate_api_response(response, endpoint)
        results.push(WebSearchResult.new(
                       query: endpoint,
                       json_data: json_data,
                       validation_errors: [],
                       schema_matched: true,
                       source_url: endpoint
                     ))
      rescue => e
        results.push(WebSearchResult.new(
                       query: endpoint,
                       json_data: {},
                       validation_errors: [e.message],
                       schema_matched: false,
                       source_url: endpoint
                     ))
      end
    end
    results
  end

  # Generate JSON Schema from sample API response.
  def generate_api_schema(sample_response, endpoint)
    return {} unless @json_available

    data = parse_json(sample_response)

    # Basic schema generation
    infer_schema = lambda do |obj, path = 'root'|
      case obj
      when Hash
        {
          'type' => 'object',
          'properties' => obj.transform_values.with_index { |v, i| infer_schema.call(v, "#{path}.#{obj.keys[i]}") }
        }
      when Array
        {
          'type' => 'array',
          'items' => obj.empty? ? {} : infer_schema.call(obj.first, "#{path}[]")
        }
      when String
        { 'type' => 'string' }
      when Integer
        { 'type' => 'integer' }
      when Float
        { 'type' => 'number' }
      when TrueClass, FalseClass
        { 'type' => 'boolean' }
      else
        { 'type' => 'null' }
      end
    end

    schema = {
      '$schema' => 'http://json-schema.org/draft-07/schema#',
      'title' => "#{endpoint} Response Schema"
    }.merge(infer_schema.call(data))

    schema
  end
end

def main
  require 'optparse'

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.on('--search QUERY', 'Search query for API docs') { |v| options[:search] = v }
    opts.on('--validate-file PATH', 'JSON file to validate') { |v| options[:validate_file] = Pathname.new(v) }
    opts.on('--schema PATH', 'Schema file path') { |v| options[:schema] = Pathname.new(v) }
    opts.on('--generate-schema PATH', 'Generate schema from sample JSON file') { |v| options[:generate_schema] = Pathname.new(v) }
    opts.on('--endpoint ENDPOINT', 'API endpoint identifier') { |v| options[:endpoint] = v }
  end.parse!

  ws = WebSearchJSON.new

  if options[:search]
    result = ws.search_and_validate(options[:search], schema_path: options[:schema])
    puts "Query: #{result.query}"
    puts "Data: #{JSON.pretty_generate(result.json_data)}"
    puts "Schema matched: #{result.schema_matched}"
    puts "Errors: #{result.validation_errors}" unless result.validation_errors.empty?
  elsif options[:generate_schema] && options[:endpoint]
    sample = options[:generate_schema].read
    schema = ws.generate_api_schema(sample, options[:endpoint])
    puts JSON.pretty_generate(schema)
  end
end

main if __FILE__ == $0
