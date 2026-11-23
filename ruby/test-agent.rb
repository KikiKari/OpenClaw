#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "129d585a458df106114cbb87b00041099b0b5e8ccde4cfec36167fdfaea12671", "source_sha256": "4206ddea85e6e63865388488399d2e874412555d623d8758c0369a860e6a0315", "target_language": "ruby"}
# test-agent.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-agent.sh
# auch in: 4 weiteren Fundstellen
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'net/http'
require 'uri'

# Ensure PERPLEXITY_API_KEY is set
ENV['PERPLEXITY_API_KEY'] or raise "PERPLEXITY_API_KEY is required"

# Get prompt from first argument or use default
prompt = ARGV[0] || "Compare recent open-source LLMs in terms of performance, licensing, and practical use."

# Set output file path
out = "#{ENV['TMPDIR'] || '/tmp'}/perplexity-agent-test.json"

# Prepare request data
data = {
  preset: "fast-search",
  input: prompt
}.to_json

# Make HTTP request
uri = URI('https://api.perplexity.ai/v1/agent')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{ENV['PERPLEXITY_API_KEY']}"
request['Content-Type'] = 'application/json'
request.body = data

response = http.request(request)

# Write response body to file
File.write(out, response.body)

# Output HTTP status code
puts "agent_http=#{response.code}"

# Process and output JSON response
json_data = JSON.parse(response.body)
result = {
  keys: json_data.keys,
  id: json_data['id'],
  status: json_data['status'],
  output_count: (json_data['output'] || []).length,
  error: json_data['error']
}
puts JSON.pretty_generate(result)
