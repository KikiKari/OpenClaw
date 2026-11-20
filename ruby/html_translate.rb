#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "70798710e2926be27b9389c59a71f801311354612df3c32eb0f72038bd391f0e", "source_sha256": "04efde297083102c20b5caf33f76d4e5638a8f6b50c3d7c5e9b15e889a91b227", "target_language": "ruby"}
# html_translate.go — portiert nach ruby
# Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/html_translate.go
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'nokogiri'
require 'open-uri'

class HTMLReplacement
  attr_accessor :start, :stop, :value

  def initialize(start, stop, value)
    @start = start
    @stop = stop
    @value = value
  end
end

def translate_html_blocks(ctx, translator, body, src_lang, tgt_lang)
  doc = Nokogiri::HTML::DocumentFragment.parse(body)
  replacements = []

  doc.xpath('//comment()').each do |node|
    next unless node.content.match?(/<!DOCTYPE|<!--|-->/)
    
    start_pos = body.index(node.to_s)
    next unless start_pos
    
    stop_pos = start_pos + node.to_s.length
    html_text = body[start_pos...stop_pos]
    
    begin
      translated = translate_html_block(ctx, translator, html_text, src_lang, tgt_lang)
      replacements << HTMLReplacement.new(start_pos, stop_pos, translated)
    rescue => e
      raise e
    end
  end

  return body if replacements.empty?

  apply_html_replacements(body, replacements)
end

def apply_html_replacements(body, replacements)
  sorted_replacements = replacements.sort_by(&:start)
  result = []
  last = 0

  sorted_replacements.each do |rep|
    next if rep.start < last

    result << body[last...rep.start]
    result << rep.value
    last = rep.stop
  end

  result << body[last..-1]
  result.join('')
end

def translate_html_block(ctx, translator, html_text, src_lang, tgt_lang)
  doc = Nokogiri::HTML::DocumentFragment.parse(html_text)
  skip_depth = 0

  doc.traverse do |node|
    case node.type
    when Nokogiri::XML::Node::ELEMENT_NODE
      tag_name = node.name.downcase
      if %w[code pre script style].include?(tag_name)
        skip_depth += 1 if node.element_children.any?
      end
    when Nokogiri::XML::Node::TEXT_NODE
      if skip_depth == 0 && node.content.strip != ''
        translated = translator.translate(ctx, node.content, src_lang, tgt_lang)
        node.content = translated
      end
    end
  end

  doc.to_html
rescue => e
  raise e
end

def should_translate_html_text(skip_depth, text)
  text.strip != '' && skip_depth == 0
end

def is_skip_tag(tag)
  %w[code pre script style].include?(tag.downcase)
end
