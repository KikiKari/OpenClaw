#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "99c26a8da29cc988bcf2339ba94c01e06dab8d990610661e2cf2263c59cefef8", "source_sha256": "3fed8b6be2b9b8639b55bcaf18c09c0395ac005ab02c27f2dff26ca20b5d5825", "target_language": "ruby"}
# generate-wavespeed.mjs — portiert nach ruby
# Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'fileutils'

# Prüfe ob API-Key gesetzt ist
key = ENV['WAVESPEED_API_KEY']
raise "WAVESPEED_API_KEY fehlt." unless key

# Lade Job-Datei
jobs_file = File.join(__dir__, '..', 'media-production', 'wavespeed-jobs.json')
jobs = JSON.parse(File.read(jobs_file))

# Pfade definieren
raw_dir = File.join(__dir__, '..', 'media-production', 'raw')
public_dir = File.join(__dir__, '..', 'public', 'media')
FileUtils.mkdir_p(raw_dir)
FileUtils.mkdir_p(public_dir)

# Log-Datei laden oder initialisieren
result_url = File.join(__dir__, '..', 'media-production', 'wavespeed-results.json')
log = File.exist?(result_url) ? JSON.parse(File.read(result_url)) : []

jobs.each do |job|
  raw_path = File.join(raw_dir, "#{job['id']}.png")
  target_path = File.join(public_dir, "#{job['output']}.png")

  # Prüfe ob Bild bereits generiert wurde
  if File.exist?(raw_path)
    unless log.any? { |entry| entry['id'] == job['id'] }
      log_entry = {
        'id' => job['id'],
        'requestId' => 'completed-before-resume',
        'model' => 'google/nano-banana-2/edit',
        'resolution' => '4k',
        'plannedCostUsd' => 0.14,
        'output' => File.basename(target_path)
      }
      log << log_entry
      File.write(result_url, JSON.pretty_generate(log))
    end
    puts "Übersprungen: #{job['id']} ist bereits vorhanden."
    next
  end

  # Lade Bilder und konvertiere lokale zu base64
  images = job['images'].map do |image|
    if image.start_with?('http://', 'https://', 'data:')
      image
    else
      file_path = File.join(__dir__, '..', image)
      encoded = Base64.strict_encode64(File.read(file_path, mode: 'rb'))
      "data:image/png;base64,#{encoded}"
    end
  end

  # Sende Request an WaveSpeed API
  uri = URI('https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit')
  request_data = {
    prompt: job['prompt'],
    images: images,
    aspect_ratio: job['aspectRatio'],
    resolution: '4k',
    output_format: 'png',
    enable_web_search: false,
    enable_image_search: false,
    enable_sync_mode: false,
    enable_base64_output: false
  }

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{key}"
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(request_data)

  response = http.request(request)
  unless response.code.to_i.between?(200, 299)
    raise "WaveSpeed submit fehlgeschlagen: #{response.code} #{response.body}"
  end

  submitted = JSON.parse(response.body)
  request_id = submitted.dig('data', 'id') || submitted['id']

  # Polling für Ergebnis
  result = nil
  90.times do
    sleep(4)
    poll_uri = URI("https://api.wavespeed.ai/api/v3/predictions/#{request_id}/result")
    poll_request = Net::HTTP::Get.new(poll_uri)
    poll_request['Authorization'] = "Bearer #{key}"
    
    poll_response = Net::HTTP.start(poll_uri.hostname, poll_uri.port, use_ssl: true) do |http|
      http.request(poll_request)
    end
    
    result = JSON.parse(poll_response.body)
    status = result.dig('data', 'status')
    break if status == 'completed'
    raise "WaveSpeed job fehlgeschlagen: #{job['id']}" if status == 'failed'
  end

  # Lade und speichere das Ergebnis-Bild
  output_url = result.dig('data', 'outputs', 0)
  raise "Kein Output für #{job['id']}" unless output_url

  image_uri = URI(output_url)
  image_http = Net::HTTP.new(image_uri.host, image_uri.port)
  image_http.use_ssl = true
  image_response = image_http.request(Net::HTTP::Get.new(image_uri))
  
  image_data = image_response.body

  File.binwrite(raw_path, image_data)
  File.binwrite(target_path, image_data)

  # Füge Eintrag zum Log hinzu
  log_entry = {
    'id' => job['id'],
    'requestId' => request_id,
    'model' => 'google/nano-banana-2/edit',
    'resolution' => '4k',
    'plannedCostUsd' => 0.14,
    'output' => File.basename(target_path)
  }
  log << log_entry
  File.write(result_url, JSON.pretty_generate(log))
  
  puts "Abgeschlossen: #{job['id']}"
end

# Schreibe finale Log-Datei
File.write(result_url, JSON.pretty_generate(log))
total_cost = log.length * 0.14
puts "WaveSpeed abgeschlossen: #{log.length} Assets, geplante Basiskosten $#{"%.2f" % total_cost}."
