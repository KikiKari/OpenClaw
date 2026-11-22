#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ab2aeef3ff82989f1aae568bc9f4e4ec08c899b50354b36593413d5fe391df2b", "source_sha256": "d00d873eeab51d166892e3bc7f2dd08b6f535b2c11988d1bb7bc0c123b76e82d", "target_language": "ruby"}
# process.go — portiert nach ruby
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/process.go
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

require 'yaml'
require 'fileutils'
require 'digest'
require 'time'

# Assuming these are defined elsewhere or will be implemented
# docs_translator, translation_memory, docs_pi_provider, docs_pi_model, workflow_version, cache_namespace, cache_key, hash_text, hash_bytes

def process_file(ctx, translator, tm, docs_root, file_path, src_lang, tgt_lang)
  abs_path, rel_path = resolve_docs_path(docs_root, file_path)
  
  content = File.read(abs_path)
  
  front_matter, body = split_front_matter(content)
  front_data = {}
  unless front_matter.empty?
    begin
      front_data = YAML.safe_load(front_matter)
    rescue => e
      raise "frontmatter parse failed for #{rel_path}: #{e.message}"
    end
  end
  
  translate_front_matter(ctx, translator, tm, front_data, rel_path, src_lang, tgt_lang)
  
  body = translate_html_blocks(ctx, translator, body, src_lang, tgt_lang)
  
  segments = extract_segments(body, rel_path)
  
  namespace = cache_namespace
  segments.each do |seg|
    seg.cache_key = cache_key(namespace, src_lang, tgt_lang, seg.segment_id, seg.text_hash)
    if tm.has_key?(seg.cache_key)
      seg.translated = tm.get(seg.cache_key).translated
      next
    end
    
    translated = translator.translate(ctx, seg.text, src_lang, tgt_lang)
    seg.translated = translated
    
    entry = TMEntry.new(
      cache_key: seg.cache_key,
      segment_id: seg.segment_id,
      source_path: rel_path,
      text_hash: seg.text_hash,
      text: seg.text,
      translated: translated,
      provider: docs_pi_provider,
      model: docs_pi_model,
      src_lang: src_lang,
      tgt_lang: tgt_lang,
      updated_at: Time.now.utc.iso8601
    )
    
    tm.put(entry)
  end
  
  translated_body = apply_translations(body, segments)
  updated_front = encode_front_matter(front_data, rel_path, content)
  
  output_path = File.join(docs_root, tgt_lang, rel_path)
  FileUtils.mkdir_p(File.dirname(output_path))
  
  output = updated_front + translated_body
  File.write(output_path, output)
  
  [false, output_path, nil]
rescue => e
  [false, "", e]
end

def split_front_matter(content)
  return ["", content] unless content.start_with?("---")
  
  lines = content.split("\n")
  return ["", content] if lines.length < 2
  
  end_index = -1
  (1...lines.length).each do |i|
    if lines[i].strip == "---"
      end_index = i
      break
    end
  end
  
  return ["", content] if end_index == -1
  
  front = lines[1...end_index].join("\n")
  body = lines[(end_index+1)..-1].join("\n")
  body = body[1..-1] if body.start_with?("\n")
  
  [front, body]
end

def encode_front_matter(front_data, rel_path, source)
  front_data ||= {}
  front_data["x-i18n"] = {
    "source_path" => rel_path,
    "source_hash" => hash_bytes(source),
    "provider" => docs_pi_provider,
    "model" => docs_pi_model,
    "workflow" => workflow_version,
    "generated_at" => Time.now.utc.iso8601
  }
  
  encoded = front_data.to_yaml
  "---\n#{encoded}---\n\n"
end

def translate_front_matter(ctx, translator, tm, data, rel_path, src_lang, tgt_lang)
  return if data.empty?
  
  if data["summary"].is_a?(String)
    summary = data["summary"]
    if docs_i18n_verbose_logs
      puts "docs-i18n: frontmatter start #{rel_path} field=summary bytes=#{summary.length}"
    end
    
    translated = translate_snippet(ctx, translator, tm, "#{rel_path}:frontmatter:summary", summary, src_lang, tgt_lang)
    if docs_i18n_verbose_logs
      puts "docs-i18n: frontmatter done #{rel_path} field=summary out_bytes=#{translated.length}"
    end
    
    data["summary"] = translated
  end
  
  if data["title"].is_a?(String)
    title = data["title"]
    if docs_i18n_verbose_logs
      puts "docs-i18n: frontmatter start #{rel_path} field=title bytes=#{title.length}"
    end
    
    translated = translate_snippet(ctx, translator, tm, "#{rel_path}:frontmatter:title", title, src_lang, tgt_lang)
    if docs_i18n_verbose_logs
      puts "docs-i18n: frontmatter done #{rel_path} field=title out_bytes=#{translated.length}"
    end
    
    data["title"] = translated
  end
  
  if data["read_when"].is_a?(Array)
    translated = []
    data["read_when"].each_with_index do |item, idx|
      unless item.is_a?(String)
        translated << item
        next
      end
      
      text_value = item
      if docs_i18n_verbose_logs
        puts "docs-i18n: frontmatter start #{rel_path} field=read_when[#{idx}] bytes=#{text_value.length}"
      end
      
      value = translate_snippet(ctx, translator, tm, "#{rel_path}:frontmatter:read_when:#{idx}", text_value, src_lang, tgt_lang)
      if docs_i18n_verbose_logs
        puts "docs-i18n: frontmatter done #{rel_path} field=read_when[#{idx}] out_bytes=#{value.length}"
      end
      
      translated << value
    end
    
    data["read_when"] = translated
  end
end

def docs_i18n_verbose_logs
  value = ENV["OPENCLAW_DOCS_I18N_VERBOSE_LOGS"]&.strip || ""
  return false if value.empty?
  
  case value.downcase
  when "1", "true", "yes", "on", "debug", "verbose"
    true
  else
    false
  end
end

def translate_snippet(ctx, translator, tm, segment_id, text_value, src_lang, tgt_lang)
  return text_value if text_value.strip.empty?
  
  namespace = cache_namespace
  text_hash = hash_text(text_value)
  ck = cache_key(namespace, src_lang, tgt_lang, segment_id, text_hash)
  
  if tm.has_key?(ck)
    return tm.get(ck).translated
  end
  
  translated = translator.translate(ctx, text_value, src_lang, tgt_lang)
  
  should_cache = true
  if validation_err = validate_frontmatter_scalar_translation(text_value, translated)
    puts "docs-i18n: frontmatter fallback #{segment_id} reason=#{validation_err}"
    translated = text_value
    should_cache = false
  end
  
  entry = TMEntry.new(
    cache_key: ck,
    segment_id: segment_id,
    source_path: segment_id,
    text_hash: text_hash,
    text: text_value,
    translated: translated,
    provider: docs_pi_provider,
    model: docs_pi_model,
    src_lang: src_lang,
    tgt_lang: tgt_lang,
    updated_at: Time.now.utc.iso8601
  )
  
  tm.put(entry) if should_cache
  
  translated
end

def validate_frontmatter_scalar_translation(source, translated)
  trimmed = translated.strip
  return "empty translation" if trimmed.empty?
  
  lower = trimmed.downcase
  return "tagged document wrapper detected" if 
    lower.include?("<frontmatter>") || 
    lower.include?("</frontmatter>") || 
    lower.include?("<body>") || 
    lower.include?("</body>")
  
  return "frontmatter marker leaked into scalar translation" if trimmed.include?("[[[FM_")
  
  return "yaml document boundary detected" if 
    trimmed.include?("\n---\n") || 
    trimmed.start_with?("---\n")
  
  return "unexpected multiline expansion" if 
    !source.include?("\n") && trimmed.count("\n") >= 3
  
  source_len = source.strip.length
  translated_len = trimmed.length
  
  if source_len > 0
    limit = [source_len * 8 + 256, 512].max
    return "unexpected size expansion source=#{source_len} translated=#{translated_len}" if translated_len > limit
  end
  
  %w[title: summary: read_when:].each do |key|
    return "frontmatter key leaked into scalar translation" if 
      lower.include?("\n#{key}") || 
      lower.start_with?(key)
  end
  
  nil
end
