#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "394469df67339c79971e51c9491eacc1964bd33a6085aa3505743630890253d8", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "ruby"}
# test-embeddings.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: 4 weiteren Fundstellen
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'net/http'
require 'uri'
require 'tempfile'

# Ensure PERPLEXITY_API_KEY is set
ENV['PERPLEXITY_API_KEY'] or raise "PERPLEXITY_API_KEY is required"

out = "#{ENV['TMPDIR'] || '/tmp'}/perplexity-embeddings-test.json"

# Create the payload
payload = {
  input: [
    "Scientists explore the universe driven by curiosity.",
    "Curiosity compels us to seek explanations, not just observations.",
    "Historical discoveries began with curious questions.",
    "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
    "Philosophy examines the nature of curiosity."
  ],
  model: "pplx-embed-v1-4b"
}.to_json

# Make the HTTP request
uri = URI('https://api.perplexity.ai/v1/embeddings')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{ENV['PERPLEXITY_API_KEY']}"
request['Content-Type'] = 'application/json'
request.body = payload

response = http.request(request)

# Write response body to file
File.write(out, response.body)

puts "embeddings_http=#{response.code}"

# Process and display the response summary
begin
  data = JSON.parse(response.body)
  result = {
    keys: data.keys,
    model: data['model'] || nil,
    item_count: data['data']&.length || 0,
    first_dim: data['data']&.first&.dig('embedding')&.length || 0,
    error: data['error'] || nil
  }
  puts result.to_json
rescue => e
  puts({ error: "Failed to parse response: #{e.message}" }.to_json)
end
