#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5af470bf393a725361753f3cf28dd1f2dbd2e1a677289ceb20b8fb316f2353d9", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "ruby"}
# tm.go — portiert nach ruby
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'fileutils'

class TMEntry
  attr_accessor :cache_key, :segment_id, :source_path, :text_hash, :text,
                :translated, :provider, :model, :src_lang, :tgt_lang, :updated_at

  def initialize(data = {})
    @cache_key = data['cache_key'] || data[:cache_key]
    @segment_id = data['segment_id'] || data[:segment_id]
    @source_path = data['source_path'] || data[:source_path]
    @text_hash = data['text_hash'] || data[:text_hash]
    @text = data['text'] || data[:text]
    @translated = data['translated'] || data[:translated]
    @provider = data['provider'] || data[:provider]
    @model = data['model'] || data[:model]
    @src_lang = data['src_lang'] || data[:src_lang]
    @tgt_lang = data['tgt_lang'] || data[:tgt_lang]
    @updated_at = data['updated_at'] || data[:updated_at]
  end

  def to_json(*_args)
    JSON.generate({
      'cache_key' => @cache_key,
      'segment_id' => @segment_id,
      'source_path' => @source_path,
      'text_hash' => @text_hash,
      'text' => @text,
      'translated' => @translated,
      'provider' => @provider,
      'model' => @model,
      'src_lang' => @src_lang,
      'tgt_lang' => @tgt_lang,
      'updated_at' => @updated_at
    })
  end

  def self.from_json(json_str)
    data = JSON.parse(json_str)
    new(data)
  rescue JSON::ParserError => e
    raise "translation memory decode failed: #{e.message}"
  end
end

class TranslationMemory
  def initialize(path)
    @path = path
    @entries = {}
  end

  def self.load(path)
    tm = new(path)
    return tm unless File.exist?(path)

    File.foreach(path) do |line|
      trimmed = line.strip
      next if trimmed.empty?

      entry = TMEntry.from_json(trimmed)
      if !entry.cache_key.nil? && !entry.cache_key.empty? && !entry.translated.nil? && !entry.translated.strip.empty?
        tm.entries[entry.cache_key] = entry
      end
    end
    tm
  rescue Errno::ENOENT
    tm
  rescue => e
    raise e
  end

  def get(cache_key)
    entry = @entries[cache_key]
    return nil if entry.nil?
    return nil if entry.translated.nil? || entry.translated.strip.empty?
    entry
  end

  def put(entry)
    return if entry.cache_key.nil? || entry.cache_key.empty?
    @entries[entry.cache_key] = entry
  end

  def save
    return if @path.nil? || @path.empty?

    FileUtils.mkdir_p(File.dirname(@path))
    tmp_path = "#{@path}.tmp"

    File.open(tmp_path, 'w') do |file|
      keys = @entries.keys.sort
      keys.each do |key|
        entry = @entries[key]
        file.puts entry.to_json
      end
    end

    File.rename(tmp_path, @path)
  rescue => e
    File.delete(tmp_path) if File.exist?(tmp_path)
    raise e
  end

  private

  attr_reader :entries
end
