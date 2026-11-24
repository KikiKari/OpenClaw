#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ff1df6dd6f0faa3775d4901f6c871f8cb10235fa76c144ab5076ba3c528a4d0e", "source_sha256": "dfe62418dcbef9ea8aa7f18ada4f57d0ef73593432b7c7cefd85ee87eee622b4", "target_language": "ruby"}
# github_publisher.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/github_publisher.py
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

# Publish queued, provenance-checked artifacts without staging unrelated files.

require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'pathname'
require 'tempfile'
require 'timeout'
require 'uri'

LANGUAGES = %w[perl5 powershell perl6 tcl javascript ruby python lua shell go java c cpp php fsharp css].freeze

def synchronize_checkout(root, remote: 'https://github.com/KikiKari/OpenClaw.git', branch: 'gateway1-abstractions')
  # Reconcile a remote snapshot into the checkout without changing its Git history.
  root = Pathname.new(root).expand_path
  raise ArgumentError, 'Root path does not exist' unless root.exist?

  Dir.mktmpdir('abstractions-snapshot-') do |tmp|
    snapshot = Pathname.new(tmp) / 'repo'
    
    # Clone repository
    clone_cmd = [
      'git', 'clone', '--quiet', '--depth=1', '--single-branch',
      '--branch', branch, '--', remote, snapshot.to_s
    ]
    
    result = Timeout.timeout(300) do
      Open3.capture3(*clone_cmd)
    end
    
    unless result[2].success?
      raise RuntimeError, "Git clone failed: #{result[2].inspect}"
    end
    
    # Get revision
    revision = nil
    Timeout.timeout(30) do
      revision = `git -C "#{snapshot}" rev-parse HEAD`.strip
    end
    
    counts = {}
    
    LANGUAGES.sort.each do |language|
      source = snapshot / language
      target = root / language
      
      if source.symlink? || target.symlink?
        raise ArgumentError, 'Language directory is a symlink'
      end
      
      if source.exist? && !source.directory?
        raise ArgumentError, 'Invalid remote language directory'
      end
      
      target.mkpath unless target.exist?
      
      known = target.children.select(&:file?).map do |p|
        Digest::SHA256.hexdigest(File.binread(p))
      end.to_set
      
      files = source.exist? ? source.children.sort : []
      
      if files.any? { |p| p.symlink? || !p.file? }
        raise ArgumentError, 'Invalid remote abstraction'
      end
      
      counts[language] = files.length
      
      files.each do |item|
        data = File.binread(item)
        digest = Digest::SHA256.hexdigest(data)
        
        next if known.include?(digest)
        
        destination = target / item.basename
        if destination.exist? || destination.symlink?
          destination = target / "#{item.stem}__pool_#{digest}#{item.extname}"
        end
        
        begin
          File.open(destination, 'wb') { |f| f.write(data) }
        rescue Errno::EEXIST
          if destination.symlink? || !destination.file? || File.binread(destination) != data
            raise ArgumentError, 'Local abstraction conflict'
          end
        end
        
        known.add(digest)
      end
    end
    
    [revision, counts]
  end
end

def update_status_counts(path, revision, counts)
  text = File.read(path, encoding: 'UTF-8')
  
  rows = [
    '## Bestand',
    '',
    "GitHub-Stand: `#{revision}`",
    '',
    '| Zielsprache | Dateien |',
    '|---|---:|'
  ]
  
  LANGUAGES.sort.each do |language|
    rows << "| #{language} | #{counts[language]} |"
  end
  
  rows.concat([
    "| **gesamt** | **#{counts.values.sum}** |",
    '',
    ''
  ])
  
  updated = text.gsub(/(?m)^## Bestand\n.*?(?=^## Quellen\n)/) do
    rows.join("\n")
  end
  
  if updated == text
    raise ArgumentError, 'Status inventory section missing'
  end
  
  File.write(path, updated, encoding: 'UTF-8')
end

def queue_artifact(state, root, path)
  root = Pathname.new(root).expand_path
  path = Pathname.new(path)
  
  if path.symlink?
    raise ArgumentError, 'Artifact must not be a symlink'
  end
  
  resolved_path = path.expand_path
  relative = resolved_path.relative_path_from(root)
  
  if relative.to_s != 'STATUS.md' && (!relative.parts.any? || !LANGUAGES.include?(relative.parts.first))
    raise ArgumentError, 'Artifact is outside a language directory'
  end
  
  state['ausstehende_veroeffentlichungen'] ||= {}
  state['ausstehende_veroeffentlichungen'][relative.to_s] = Digest::SHA256.hexdigest(File.binread(path))
end

def publish_pending(root, state, save_proc, token, opener: nil, sync: nil)
  pending = state['ausstehende_veroeffentlichungen'] || {}
  
  unless pending.is_a?(Hash)
    raise ArgumentError, 'Invalid publication queue'
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
  entries = pending.sort_by { |name, _| name == 'STATUS.md' ? 0 : 1 }
  synced = false
  
  entries.each do |name, expected|
    begin
      path = root / name
      
      if path.symlink? || path.expand_path.relative_path_from(root).to_s != name
        raise ArgumentError, 'Invalid queued path'
      end
      
      data = File.binread(path)
      
      if Digest::SHA256.hexdigest(data) != expected
        raise ArgumentError, 'Queued artifact changed'
      end
      
      if name == 'STATUS.md' && sync
        unless success
          raise ArgumentError, 'Artifact publication incomplete'
        end
        
        revision, counts = sync.call(root)
        synced = true
        update_status_counts(path, revision, counts)
        data = File.binread(path)
        expected = Digest::SHA256.hexdigest(data)
        pending[name] = expected
        save_proc.call(state)
      end
      
      lookup = lambda do |remote_name|
        endpoint = "https://api.github.com/repos/KikiKari/OpenClaw/contents/#{URI.encode_www_form_component(remote_name)}"
        uri = URI("#{endpoint}?ref=gateway1-abstractions")
        
        begin
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          request = Net::HTTP::Get.new(uri)
          headers.each { |k, v| request[k] = v }
          
          response = http.request(request)
          
          if response.code == '200'
            [endpoint, JSON.parse(response.body)]
          else
            [endpoint, nil]
          end
        rescue Net::HTTPError => e
          if e.response&.code != '404'
            raise
          end
          [endpoint, nil]
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
        
        unless sha.is_a?(String) && !sha.empty?
          raise ArgumentError, 'Missing remote status version'
        end
        
        body = {
          'message' => 'Update abstraction status',
          'branch' => 'gateway1-abstractions',
          'content' => Base64.strict_encode64(data),
          'sha' => sha
        }.to_json
        
        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Put.new(uri, headers)
        request.body = body
        
        response = http.request(request)
        JSON.parse(response.body)
      elsif existing && !same.call(existing)
        # Independent managers can derive different results for one
        # source. Preserve both without overwriting the remote file.
        candidate = Pathname.new(name)
        alternate = (candidate.dirname / "#{candidate.basename(candidate.extname)}_#{expected[0..11]}#{candidate.extname}").to_s
        endpoint, existing = lookup.call(alternate)
        
        if existing && !same.call(existing)
          raise ArgumentError, 'Remote artifact conflict'
        end
      end
      
      if existing.nil?
        body = {
          'message' => 'Publish script abstraction',
          'branch' => 'gateway1-abstractions',
          'content' => Base64.strict_encode64(data)
        }.to_json
        
        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Put.new(uri, headers)
        request.body = body
        
        response = http.request(request)
        JSON.parse(response.body)
      end
      
      pending.delete(name)
      save_proc.call(state)
    rescue StandardError
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
