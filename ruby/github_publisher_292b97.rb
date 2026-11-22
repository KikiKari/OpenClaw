#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "863d2f2d615b091fe6388686209b1867f9f7bb268d19a1aa39d622e06d92aeb0", "source_sha256": "292b977dd14f55e08a3852eccaf235d04d5f7e909ab6139a9ab2e379ae2305a1", "target_language": "ruby"}
# github_publisher.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'open3'
require 'pathname'
require 'securerandom'
require 'tempfile'
require 'uri'

LANGUAGES = %w[perl5 powershell perl6 tcl javascript ruby python lua shell go].freeze

def synchronize_checkout(root, remote: 'https://github.com/KikiKari/OpenClaw.git', branch: 'gateway1-abstractions')
  # Reconcile a remote snapshot into the checkout without changing its Git history.
  root = Pathname.new(root).expand_path
  raise "Root path does not exist" unless root.directory?

  Dir.mktmpdir('abstractions-snapshot-') do |tmp|
    snapshot = Pathname.new(tmp) / 'repo'
    
    # Clone repository
    cmd = ['git', 'clone', '--quiet', '--depth=1', '--single-branch',
           '--branch', branch, '--', remote, snapshot.to_s]
    
    stdin, stdout, stderr, wait_thr = Open3.popen3(*cmd)
    stdin.close
    stdout.read
    stderr.read
    
    unless wait_thr.value.success?
      raise "Failed to clone repository"
    end
    
    # Get revision
    revision = `git -C #{snapshot} rev-parse HEAD`.strip
    raise "Failed to get revision" unless $?.success?
    
    counts = {}
    
    LANGUAGES.sort.each do |language|
      source = snapshot / language
      target = root / language
      
      # Check for symlinks
      if source.symlink? || target.symlink?
        raise "language directory is a symlink"
      end
      
      if source.exist? && !source.directory?
        raise "invalid remote language directory"
      end
      
      target.mkpath unless target.exist?
      
      # Calculate known file hashes
      known = target.children.select(&:file?).reject(&:symlink?)
                          .map { |p| Digest::SHA256.hexdigest(p.read) }.to_set
      
      files = source.exist? ? source.children.sort : []
      
      # Validate files
      if files.any? { |p| p.symlink? || !p.file? }
        raise "invalid remote abstraction"
      end
      
      counts[language] = files.length
      
      files.each do |item|
        data = item.read
        digest = Digest::SHA256.hexdigest(data)
        
        next if known.include?(digest)
        
        destination = target / item.basename
        if destination.exist? || destination.symlink?
          destination = target / "#{item.stem}__pool_#{digest}#{item.extname}"
        end
        
        begin
          destination.open('xb') do |output|
            output.write(data)
          end
        rescue Errno::EEXIST
          if destination.symlink? || !destination.file? || destination.read != data
            raise "local abstraction conflict"
          end
        end
        
        known.add(digest)
      end
    end
    
    return revision, counts
  end
end

def update_status_counts(path, revision, counts)
  text = File.read(path, encoding: 'utf-8')
  
  rows = [
    "## Bestand",
    "",
    "GitHub-Stand: `#{revision}`",
    "",
    "| Zielsprache | Dateien |",
    "|---|---:|"
  ]
  
  LANGUAGES.sort.each do |language|
    rows << "| #{language} | #{counts[language]} |"
  end
  
  rows.concat([
    "| **gesamt** | **#{counts.values.sum}** |",
    "",
    ""
  ])
  
  updated = text.gsub(/(?m)^## Bestand\n.*?(?=^## Quellen\n)/) do
    rows.join("\n")
  end
  
  if text == updated
    raise "status inventory section missing"
  end
  
  File.write(path, updated, encoding: 'utf-8')
end

def queue_artifact(state, root, path)
  root = Pathname.new(root).expand_path
  path = Pathname.new(path)
  
  if path.symlink?
    raise "artifact must not be a symlink"
  end
  
  relative = path.expand_path.relative_path_from(root).to_s
  
  valid_languages = %w[perl5 powershell perl6 tcl javascript ruby python lua shell go]
  
  if relative != 'STATUS.md' && 
     (!relative.split('/').first || !valid_languages.include?(relative.split('/').first))
    raise "artifact is outside a language directory"
  end
  
  state['ausstehende_veroeffentlichungen'] ||= {}
  state['ausstehende_veroeffentlichungen'][relative] = Digest::SHA256.hexdigest(path.read)
end

def publish_pending(root, state, save, token, opener: nil, sync: nil)
  pending = state['ausstehende_veroeffentlichungen'] || {}
  
  unless pending.is_a?(Hash)
    raise "invalid publication queue"
  end
  
  if pending.empty? && sync.nil?
    return true
  end
  
  if !token || token.strip.empty?
    return false
  end
  
  root = Pathname.new(root).expand_path
  headers = {
    'Authorization' => "Bearer #{token.strip}",
    'Accept' => 'application/vnd.github+json',
    'X-GitHub-Api-Version' => '2022-11-28',
    'User-Agent' => 'abstractions-manager'
  }
  
  success = true
  entries = pending.sort_by { |item| item[0] == 'STATUS.md' ? 0 : 1 }
  synced = false
  
  entries.each do |name, expected|
    begin
      path = root / name
      
      if path.symlink? || path.expand_path.relative_path_from(root).to_s != name
        raise "invalid queued path"
      end
      
      data = path.read
      if Digest::SHA256.hexdigest(data) != expected
        raise "queued artifact changed"
      end
      
      if name == 'STATUS.md' && sync
        if !success
          raise "artifact publication incomplete"
        end
        
        revision, counts = sync.call(root)
        synced = true
        update_status_counts(path, revision, counts)
        data = path.read
        expected = Digest::SHA256.hexdigest(data)
        pending[name] = expected
        save.call(state)
      end
      
      lookup = lambda do |remote_name|
        uri = URI("https://api.github.com/repos/KikiKari/OpenClaw/contents/#{URI.encode_www_form_component(remote_name)}")
        uri.query = "ref=gateway1-abstractions"
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri)
        headers.each { |k, v| request[k] = v }
        
        begin
          response = http.request(request)
          if response.code.to_i == 404
            [uri.to_s, nil]
          else
            [uri.to_s, JSON.parse(response.body)]
          end
        rescue Net::HTTPError => e
          if e.response.code.to_i == 404
            [uri.to_s, nil]
          else
            raise
          end
        end
      end
      
      same = lambda do |existing|
        existing.is_a?(Hash) &&
        existing['encoding'] == 'base64' &&
        Base64.decode64(existing['content']) == data
      end
      
      endpoint, existing = lookup.call(name)
      
      if name == 'STATUS.md' && existing && !same.call(existing)
        sha = existing['sha'] if existing.is_a?(Hash)
        if !sha.is_a?(String) || sha.empty?
          raise 'missing remote status version'
        end
        
        body = {
          'message' => 'Update abstraction status',
          'branch' => 'gateway1-abstractions',
          'content' => Base64.encode64(data).delete("\n"),
          'sha' => sha
        }.to_json
        
        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Put.new(uri)
        headers.each { |k, v| request[k] = v }
        request.body = body
        
        response = http.request(request)
        JSON.parse(response.body)
      elsif existing && !same.call(existing)
        # Independent managers can derive different results for one
        # source. Preserve both without overwriting the remote file.
        candidate = Pathname.new(name)
        alternate = (candidate.dirname / "#{candidate.basename('.*')}_#{expected[0..11]}#{candidate.extname}").to_s
        
        endpoint, existing = lookup.call(alternate)
        if existing && !same.call(existing)
          raise "remote artifact conflict"
        end
      end
      
      if existing.nil?
        body = {
          'message' => 'Publish script abstraction',
          'branch' => 'gateway1-abstractions',
          'content' => Base64.encode64(data).delete("\n")
        }.to_json
        
        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Put.new(uri)
        headers.each { |k, v| request[k] = v }
        request.body = body
        
        response = http.request(request)
        JSON.parse(response.body)
      end
      
      pending.delete(name)
      save.call(state)
    rescue StandardError => e
      success = false
    end
  end
  
  if sync && !synced
    begin
      sync.call(root)
    rescue StandardError
      success = false
    end
  end
  
  success
end
