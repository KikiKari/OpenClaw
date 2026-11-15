#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "c2457a95b3d0752593dbdc631c67d988720160ecfb1e956c2f92b0b3d66636e8", "source_sha256": "b7508c3367d6d569a8c1beb0e8ada0a36433c0484d97610776744335d50c4f6f", "target_language": "ruby"}
# github_publisher.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'uri'
require 'pathname'

def queue_artifact(state, root, path)
  root = Pathname.new(root).realpath
  path = Pathname.new(path)
  
  if path.symlink?
    raise ArgumentError, "artifact must not be a symlink"
  end
  
  relative = path.realpath.relative_path_from(root)
  parts = relative.to_s.split('/')
  
  if parts.empty? || !["perl5", "powershell", "perl6", "tcl", "javascript", "ruby", "python", "lua", "shell", "go"].include?(parts[0])
    raise ArgumentError, "artifact is outside a language directory"
  end
  
  pending = state["ausstehende_veroeffentlichungen"] ||= {}
  pending[relative.to_s] = Digest::SHA256.hexdigest(File.read(path, mode: 'rb'))
end

def publish_pending(root, state, save, token, opener: nil)
  pending = state["ausstehende_veroeffentlichungen"] || {}
  
  unless pending.is_a?(Hash)
    raise ArgumentError, "invalid publication queue"
  end
  
  return true if pending.empty?
  
  return false if !token || token.strip.empty?
  
  root = Pathname.new(root).realpath
  headers = {
    "Authorization" => "Bearer #{token.strip}",
    "Accept" => "application/vnd.github+json",
    "X-GitHub-Api-Version" => "2022-11-28",
    "User-Agent" => "abstractions-manager"
  }
  
  success = true
  
  pending.dup.each do |name, expected|
    begin
      path = root.join(name)
      
      if path.symlink? || path.realpath.relative_path_from(root).to_s != name
        raise ArgumentError, "invalid queued path"
      end
      
      data = File.read(path, mode: 'rb')
      
      if Digest::SHA256.hexdigest(data) != expected
        raise ArgumentError, "queued artifact changed"
      end
      
      lookup = lambda do |remote_name|
        uri = URI("https://api.github.com/repos/KikiKari/OpenClaw/contents/#{URI.encode_www_form_component(remote_name)}")
        uri.query = "ref=gateway1-abstractions"
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri)
        headers.each { |key, value| request[key] = value }
        
        response = http.request(request)
        
        if response.code == '404'
          [uri.to_s, nil]
        else
          [uri.to_s, JSON.parse(response.body)]
        end
      rescue Net::HTTPError => e
        if e.response.code != '404'
          raise
        end
        [uri.to_s, nil]
      end
      
      same = lambda do |existing|
        existing.is_a?(Hash) && 
        existing['encoding'] == 'base64' && 
        Base64.decode64(existing['content'] || '') == data
      end
      
      endpoint, existing = lookup.call(name)
      
      if existing && !same.call(existing)
        # Independent managers can derive different results for one
        # source. Preserve both without overwriting the remote file.
        candidate = Pathname.new(name)
        stem = candidate.basename(candidate.extname).to_s
        ext = candidate.extname.to_s
        dir = candidate.dirname
        
        alternate = dir.join("#{stem}_#{expected[0, 12]}#{ext}").to_s
        endpoint, existing = lookup.call(alternate)
        
        if existing && !same.call(existing)
          raise ArgumentError, "remote artifact conflict"
        end
      end
      
      if existing.nil?
        body_data = {
          "message" => "Publish script abstraction",
          "branch" => "gateway1-abstractions",
          "content" => Base64.strict_encode64(data)
        }
        
        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Put.new(uri)
        headers.each { |key, value| request[key] = value }
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body_data)
        
        http.request(request)
      end
      
      pending.delete(name)
      save.call(state) if save.respond_to?(:call)
      
    rescue StandardError
      success = false
    end
  end
  
  success
end
