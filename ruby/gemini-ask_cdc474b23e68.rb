#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "bce0ac1ae103b14259d9b25dc127e1a68726cd346ce220364c44d9b2b1798446", "source_sha256": "9411ee01f75190a7b3bf9f276fc6bb624d2c943629885c1ddfc9f71a0039070e", "target_language": "ruby"}
# gemini-ask.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

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
require 'open3'

DEFAULT_MODEL = ENV['GEMINI_MODEL'] || 'gemini-pro'

def main
  # Check API key
  if ENV['GEMINI_API_KEY'].nil? || ENV['GEMINI_API_KEY'].empty?
    STDERR.puts 'Error: GEMINI_API_KEY environment variable is required'
    exit 1
  end

  # Parse arguments
  prompt = ''
  model_name = DEFAULT_MODEL
  args = ARGV.dup

  # Check for --model flag
  model_index = args.index { |a| a == '--model' || a == '-m' }
  if model_index && args[model_index + 1]
    model_name = args[model_index + 1]
    args.delete_at(model_index)
    args.delete_at(model_index)
  end

  # Check for --system flag (system prompt)
  system_prompt = ''
  system_index = args.index { |a| a == '--system' || a == '-s' }
  if system_index && args[system_index + 1]
    system_prompt = args[system_index + 1]
    args.delete_at(system_index)
    args.delete_at(system_index)
  end

  if args.include?('--file') || args.include?('-f')
    file_index = args.index { |a| a == '--file' || a == '-f' }
    file_path = args[file_index + 1]
    if file_path.nil? || file_path.empty?
      STDERR.puts 'Error: No file specified'
      exit 1
    end
    prompt = File.read(file_path, encoding: 'UTF-8')
    # Remove --file and path from args
    args.delete_at(file_index)
    args.delete_at(file_index)
  elsif args.length > 0
    prompt = args.join(' ')
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
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model_name}:generateContent?key=#{api_key}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    headers = {
      'Content-Type' => 'application/json'
    }

    # Prepare generation config
    generation_config = {
      maxOutputTokens: 8192,
      temperature: 0.7,
      topP: 0.95
    }

    body_data = {}

    if !system_prompt.empty?
      # Use chat with system prompt
      body_data[:contents] = [
        { role: 'user', parts: [{ text: system_prompt }] },
        { role: 'model', parts: [{ text: 'Understood. I will follow that instruction.' }] },
        { role: 'user', parts: [{ text: prompt }] }
      ]
    else
      # Direct generation
      body_data[:contents] = [{ role: 'user', parts: [{ text: prompt }] }]
    end

    body_data[:generationConfig] = generation_config

    request = Net::HTTP::Post.new(uri, headers)
    request.body = body_data.to_json

    response = http.request(request)

    case response.code.to_i
    when 200
      data = JSON.parse(response.body)
      text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
      puts text
    else
      error_data = JSON.parse(response.body)
      error_message = error_data.dig('error', 'message') || 'Unknown error'
      STDERR.puts "Error: #{error_message}"
      if error_message.include?('API key')
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
