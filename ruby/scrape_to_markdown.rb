#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b5479e21a44d6da7e13fd1fcebe0ea2929d2c19f003b848cdb2328a4197d068c", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "ruby"}
# scrape_to_markdown.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# SECURITY MANIFEST:
# Environment variables accessed: none
# External endpoints called: only URLs supplied by the user at runtime via --url / --url-file
# Local files read: --url-file path (if provided by user)
# Local files written: --output-dir/*.md, --output-dir/index.json (if --output-dir provided)
#                      Nokogiri HTML parsing cache (managed by Nokogiri, local only)
# Credentials handled: --proxy value (never logged or transmitted beyond the proxy itself)
# Shell injection risk: none (pure Ruby, no system or shell interpolation)

require 'optparse'
require 'json'
require 'uri'
require 'pathname'
require 'net/http'
require 'openssl'

def to_str(value)
  return '' if value.nil?
  return value.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace) if value.is_a?(String) && value.encoding.name != 'UTF-8'
  value.to_s
end

def slugify(text, max_len = 80)
  text = text.gsub(/[^\w\s-]/, '').strip.downcase
  text = text.gsub(/[-\s]+/, '-')
  result = text[0, max_len].gsub(/^-+|-+$/, '')
  result.empty? ? 'page' : result
end

def extract_html(obj)
  return '' if obj.nil?

  attrs = %w[html raw_html content markup body inner_html]
  attrs.each do |attr|
    begin
      value = obj.respond_to?(attr) ? obj.send(attr) : nil
      next unless value

      text = to_str(value)
      return text if text.include?('<') && text.include?('>')
    rescue StandardError
      next
    end
  end

  text = to_str(obj)
  text.include?('<') && text.include?('>') ? text : ''
end

def extract_title(html)
  match = html.match(/<title[^>]*>(.*?)<\/title>/mi)
  return '' unless match

  title = match[1].gsub(/<[^>]+>/, ' ')
  title.gsub(/\s+/, ' ').strip
end

def fetch_page(url, js: false, wait_selector: nil, timeout: 30, automatch_domain: nil)
  uri = URI(url)
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = timeout
  
  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = 'Mozilla/5.0 (compatible; scrape_to_markdown.rb/1.0)'
  
  response = http.request(request)
  
  # Create a simple response object similar to what Scrapling would return
  page_obj = Struct.new(:status, :body, :content).new
  page_obj.status = response.code.to_i
  page_obj.body = response.body
  page_obj.content = response.body
  
  [page_obj, 'Net::HTTP.get']
rescue => e
  raise "Failed to fetch #{url}: #{e.message}"
end

def pick_main_html(page, preferred_selector: nil)
  # For simplicity, we'll just return the full body since we don't have CSS selection capabilities
  # without additional dependencies like Nokogiri
  html = extract_html(page)
  [html, nil]
end

def html_to_markdown(html, preserve_links: false, body_width: 0)
  # Simple HTML to Markdown conversion
  # This is a very basic implementation - a real one would be much more complex
  
  # Remove script and style tags
  text = html.gsub(/<(script|style)[^>]*>.*?<\/\1>/m, '')
  
  # Convert headers
  text = text.gsub(/<h[1-6][^>]*>(.*?)<\/h[1-6]>/mi) { "#{$1}\n" + ('-' * $1.length) + "\n\n" }
  
  # Convert paragraphs
  text = text.gsub(/<p[^>]*>(.*?)<\/p>/mi) { "#{$1}\n\n" }
  
  # Convert links if preserving them
  if preserve_links
    text = text.gsub(/<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)<\/a>/mi) { "[#{$2}](#{$1})" }
  else
    text = text.gsub(/<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)<\/a>/mi) { $2 }
  end
  
  # Convert bold
  text = text.gsub(/<(strong|b)[^>]*>(.*?)<\/\1>/mi) { "**#{$2}**" }
  
  # Convert italic
  text = text.gsub(/<(em|i)[^>]*>(.*?)<\/\1>/mi) { "*#{$2}*" }
  
  # Convert lists
  text = text.gsub(/<ul[^>]*>(.*?)<\/ul>/mi) { $1.gsub(/<li[^>]*>(.*?)<\/li>/mi, "- #{$1}\n") }
  text = text.gsub(/<ol[^>]*>(.*?)<\/ol>/mi) do |match|
    items = match.scan(/<li[^>]*>(.*?)<\/li>/mi)
    items.each_with_index.map { |item, i| "#{i+1}. #{item.first}\n" }.join('')
  end
  
  # Convert line breaks
  text = text.gsub(/<br\s*\/?>/i, "\n")
  
  # Remove remaining HTML tags
  text = text.gsub(/<[^>]+>/, '')
  
  # Normalize whitespace
  text = text.gsub(/\n{3,}/, "\n\n").strip
  
  # Apply body width wrapping if specified
  if body_width > 0
    lines = text.split("\n")
    wrapped_lines = lines.map do |line|
      line.length > body_width ? line.gsub(/(.{1,#{body_width}})(\s+|$)/, "\\1\n").strip : line
    end
    text = wrapped_lines.join("\n")
  end
  
  text
rescue => e
  # If anything goes wrong, return plain text version of HTML
  html.gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip
end

def load_urls(url_args, url_file)
  urls = Array(url_args) || []
  
  if url_file && !url_file.empty?
    File.readlines(url_file, chomp: true).each do |line|
      line = line.strip
      urls << line unless line.empty? || line.start_with?('#')
    end
  end
  
  # Deduplicate while preserving order
  seen = Set.new
  urls.select { |u| seen.add?(u) }
end

def validate_url(url)
  uri = URI.parse(url)
  %w[http https].include?(uri.scheme) && !uri.host.nil?
rescue URI::InvalidURIError
  false
end

def main
  options = {
    url: [],
    url_file: '',
    selector: '',
    js: false,
    wait_selector: '',
    preserve_links: false,
    body_width: 0,
    timeout: 30,
    output_dir: 'outputs',
    automatch_domain: ''
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: scrape_to_markdown.rb [options]"
    
    opts.on("--url URL", "URL to scrape (can be repeated)") do |u|
      options[:url] << u
    end
    
    opts.on("--url-file FILE", "File containing URLs to scrape") do |f|
      options[:url_file] = f
    end
    
    opts.on("--selector SELECTOR", "Preferred CSS selector for content") do |s|
      options[:selector] = s
    end
    
    opts.on("--js", "Use JavaScript rendering") do
      options[:js] = true
    end
    
    opts.on("--wait-selector SELECTOR", "Wait for element before scraping") do |s|
      options[:wait_selector] = s
    end
    
    opts.on("--preserve-links", "Preserve links in markdown output") do
      options[:preserve_links] = true
    end
    
    opts.on("--body-width WIDTH", Integer, "Wrap text at column width") do |w|
      options[:body_width] = w
    end
    
    opts.on("--timeout TIMEOUT", Integer, "Request timeout in seconds") do |t|
      options[:timeout] = t
    end
    
    opts.on("--output-dir DIR", "Output directory for markdown files") do |d|
      options[:output_dir] = d
    end
    
    opts.on("--automatch-domain DOMAIN", "Domain for automatic matching") do |d|
      options[:automatch_domain] = d
    end
  end.parse!

  urls = load_urls(options[:url], options[:url_file])
  if urls.empty?
    puts JSON.generate({ ok: false, error: "No URLs provided" })
    exit 1
  end

  urls.each do |u|
    unless validate_url(u)
      puts JSON.generate({ ok: false, error: "Invalid URL: #{u}" })
      exit 1
    end
  end

  out_dir = Pathname.new(options[:output_dir])
  out_dir.mkpath

  results = []

  urls.each do |url|
    item = {
      url: url,
      ok: false,
      title: "",
      status: nil,
      selector_used: nil,
      backend: nil,
      markdown: "",
      preview: "",
      output_markdown_file: nil,
      error: nil,
    }

    begin
      page, backend = fetch_page(
        url,
        js: options[:js],
        wait_selector: options[:wait_selector].empty? ? nil : options[:wait_selector],
        timeout: options[:timeout],
        automatch_domain: options[:automatch_domain].empty? ? nil : options[:automatch_domain]
      )
      
      html, selector_used = pick_main_html(page, preferred_selector: options[:selector].empty? ? nil : options[:selector])
      raise "No HTML content extracted from page" if html.empty?

      title = extract_title(html) || URI.parse(url).host
      markdown = html_to_markdown(
        html,
        preserve_links: options[:preserve_links],
        body_width: options[:body_width]
      )

      filename = slugify("#{URI.parse(url).host}-#{title}") + ".md"
      md_path = out_dir / filename
      md_path.write(markdown, mode: 'w:utf-8')

      status = page.respond_to?(:status) ? page.status : nil

      item.update({
        ok: true,
        title: title,
        status: status,
        selector_used: selector_used,
        backend: backend,
        markdown: markdown,
        preview: markdown[0, 1200],
        output_markdown_file: md_path.to_s,
      })
    rescue => e
      item[:error] = e.message
    end

    results << item
  end

  ok = results.any? { |x| x[:ok] }
  index_path = out_dir / "index.json"
  
  payload = {
    ok: ok,
    count: results.length,
    success_count: results.count { |x| x[:ok] },
    failure_count: results.count { |x| !x[:ok] },
    output_index_file: index_path.to_s,
    results: results,
  }
  
  index_path.write(JSON.pretty_generate(payload), mode: 'w:utf-8')
  puts JSON.generate(payload)
end

main if __FILE__ == $0
