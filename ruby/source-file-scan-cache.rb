#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "489c781ae5d7de796b9839cf842b1465462b3f83883481a658820d4950077628", "source_sha256": "44f04cb59342c4d1b0965cd87195e903f79fc80231b0f537dba10313bc29aa00", "target_language": "ruby"}
# source-file-scan-cache.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/source-file-scan-cache.mjs
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'pathname'

# Cache für gescannte Dateien
$scan_cache = {}

# Normalisiert einen Dateipfad relativ zum Repository-Root
def normalize_repo_path(repo_root, file_path)
  Pathname.new(file_path).relative_path_from(Pathname.new(repo_root)).to_s.gsub(File::SEPARATOR, '/')
end

# Rekursiv Dateien im Verzeichnisbaum durchsuchen
def walk_files(params, root_dir)
  out = []
  entries = []

  begin
    entries = Dir.entries(root_dir, encoding: Encoding::UTF_8).map do |name|
      full_path = File.join(root_dir, name)
      stat = File.stat(full_path)
      {
        name: name,
        path: full_path,
        directory?: stat.directory?,
        file?: stat.file?
      }
    end
  rescue Errno::ENOENT
    return out
  end

  entries.sort_by! { |entry| entry[:name] }

  entries.each do |entry|
    entry_path = entry[:path]
    
    if entry[:directory?]
      unless params[:ignored_dir_names].include?(entry[:name])
        out.concat(walk_files(params, entry_path))
      end
      next
    end
    
    if entry[:file?] && params[:scan_extensions].include?(File.extname(entry[:name]))
      out.push(entry_path)
    end
  end
  
  out
end

# Sammelt den Inhalt aller Quelldateien
def collect_source_file_contents(params)
  # Erstelle Cache-Key aus serialisierten Parametern
  cache_key = {
    repoRoot: params[:repo_root],
    scanRoots: params[:scan_roots],
    scanExtensions: params[:scan_extensions].sort,
    ignoredDirNames: params[:ignored_dir_names].sort
  }.to_json

  cached = $scan_cache[cache_key]
  return cached if cached

  promise = lambda do
    # Sammle alle Dateien aus allen Scan-Roots
    files = params[:scan_roots].flat_map do |root|
      walk_files(params, File.join(params[:repo_root], root))
    end.flatten.sort do |left, right|
      normalize_repo_path(params[:repo_root], left) <=> normalize_repo_path(params[:repo_root], right)
    end

    # Lese den Inhalt aller Dateien
    files.map do |file_path|
      {
        filePath: file_path,
        relativeFile: normalize_repo_path(params[:repo_root], file_path),
        content: File.read(file_path, encoding: 'UTF-8')
      }
    end
  end

  $scan_cache[cache_key] = promise.call
  $scan_cache[cache_key]
rescue => error
  $scan_cache.delete(cache_key)
  raise error
end
