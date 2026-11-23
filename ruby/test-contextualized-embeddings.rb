#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "643e1a87608dd37b9cd02d84893fbb98befff0f09309336d36e4d7b2dcfa2fe6", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "ruby"}
# test-contextualized-embeddings.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: 4 weiteren Fundstellen
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'net/http'
require 'uri'
require 'tempfile'

raise "PERPLEXITY_API_KEY is required" unless ENV['PERPLEXITY_API_KEY']

out = "#{ENV['TMPDIR'] || '/tmp'}/perplexity-contextualized-embeddings-test.json"

payload = {
  input: [[
    "OpenClaw can route web search through Perplexity.",
    "The Perplexity MCP server exposes search and reasoning tools.",
    "Contextualized embeddings improve document chunk retrieval."
  ]],
  model: "pplx-embed-context-v1-4b"
}.to_json

uri = URI('https://api.perplexity.ai/v1/contextualizedembeddings')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{ENV['PERPLEXITY_API_KEY']}"
request['Content-Type'] = 'application/json'
request.body = payload

response = http.request(request)

File.write(out, response.body)

puts "contextualized_embeddings_http=#{response.code}"

result = JSON.parse(response.body)
output = {
  keys: result.keys,
  model: result['model'] || nil,
  document_count: (result['data'] || []).length,
  first_chunk_count: ((result['data'] || [])[0]['data'] || []).length,
  error: result['error'] || nil
}

puts JSON.pretty_generate(output)
