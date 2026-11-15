#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "99114687ecc039750f0a80e8a2a63761d47de45e2a6e610be8c7e04f48327adb", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "ruby"}
# gemini-ask.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# gemini-ask.rb - CLI tool for Google Gemini API
# 
# Usage:
#   ruby gemini-ask.rb "Your question here"
#   echo "Your question" | ruby gemini-ask.rb
#   ruby gemini-ask.rb --file prompt.txt
#   ruby gemini-ask.rb --model gemini-pro "Your question"
# 
# Environment:
#   GEMINI_API_KEY - Required API key
#   GEMINI_MODEL   - Optional default model (default: gemini-pro)

require 'net/http'
require 'uri'
require 'json'
require 'optparse'

DEFAULT_MODEL = ENV['GEMINI_MODEL'] || 'gemini-pro'

def main
  # Check API key
  if !ENV['GEMINI_API_KEY']
    STDERR.puts 'Error: GEMINI_API_KEY environment variable is required'
    exit 1
  end

  # Parse arguments
  options = {}
  prompt = ''
  modelName = DEFAULT_MODEL

  OptionParser.new do |opts|
    opts.banner = "Usage: gemini-ask [options] [prompt]"

    opts.on('--model MODEL', 'Specify model name') do |model|
      modelName = model
    end

    opts.on('--system SYSTEM_PROMPT', 'Specify system prompt') do |sys_prompt|
      options[:system_prompt] = sys_prompt
    end

    opts.on('-f', '--file FILE_PATH', 'Read prompt from file') do |file_path|
      options[:file_path] = file_path
    end
  end.parse!

  remaining_args = ARGV.dup

  if options[:file_path]
    if !File.exist?(options[:file_path])
      STDERR.puts 'Error: File does not exist'
      exit 1
    end
    prompt = File.read(options[:file_path], encoding: 'UTF-8')
  elsif remaining_args.length > 0
    prompt = remaining_args.join(' ')
  elsif !$stdin.tty?
    # Read from stdin
    prompt = $stdin.read
  end

  if prompt.strip.empty?
    STDERR.puts 'Error: No prompt provided'
    STDERR.puts 'Usage: gemini-ask "your question"'
    STDERR.puts '       gemini-ask --model gemini-pro "your question"'
    STDERR.puts '       echo "your question" | gemini-ask'
    exit 1
  end

  begin
    api_key = ENV['GEMINI_API_KEY']
    
    # Prepare generation config
    generation_config = {
      maxOutputTokens: 8192,
      temperature: 0.7,
      topP: 0.95
    }

    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{modelName}:generateContent?key=#{api_key}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    headers = { 'Content-Type' => 'application/json' }
    
    contents = [{ role: 'user', parts: [{ text: prompt }] }]
    
    if options[:system_prompt]
      # Prepend system prompt as initial conversation
      contents.unshift(
        { role: 'user', parts: [{ text: options[:system_prompt] }] },
        { role: 'model', parts: [{ text: 'Understood. I will follow that instruction.' }] }
      )
    end

    body = {
      contents: contents,
      generationConfig: generation_config
    }.to_json

    request = Net::HTTP::Post.new(uri, headers)
    request.body = body

    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
      puts text if text
    else
      error_data = JSON.parse(response.body)
      error_msg = error_data.dig('error', 'message') || 'Unknown error'
      STDERR.puts "Error: #{error_msg}"
      if error_msg.include?('API key')
        STDERR.puts 'Make sure GEMINI_API_KEY is set correctly'
      end
      exit 1
    end
  rescue StandardError => e
    STDERR.puts "Error: #{e.message}"
    exit 1
  end
end

main if __FILE__ == $0
