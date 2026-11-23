#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f137d3fcfee9021a6291cbb67e44564dfac86d6a652297f445b89bf3a65c7456", "source_sha256": "5b19bba778485b72894d3e7b04adf4782d842ad89c9cb89bd33639183c7b6075", "target_language": "ruby"}
# tavily_search.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
# auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
# auch in: workspace@local:git/skills/tavily/scripts/tavily_search.py
# auch in: workspace@local:skills/tavily/scripts/tavily_search.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Tavily AI Search - Optimized search for LLMs and AI applications
# Requires: gem install tavily

require 'optparse'
require 'json'
require 'tavily'

class TavilySearch
  def self.search(query:, api_key:, search_depth: "basic", topic: "general", max_results: 5,
                   include_answer: true, include_raw_content: false, include_images: false,
                   include_domains: nil, exclude_domains: nil)
    # Execute a Tavily search query.
    #
    # Args:
    #     query: Search query string
    #     api_key: Tavily API key (tvly-...)
    #     search_depth: "basic" (fast) or "advanced" (comprehensive)
    #     topic: "general" (default) or "news" (current events)
    #     max_results: Number of results to return (1-10)
    #     include_answer: Include AI-generated answer summary
    #     include_raw_content: Include raw HTML content of sources
    #     include_images: Include relevant images in results
    #     include_domains: List of domains to specifically include
    #     exclude_domains: List of domains to exclude
    #
    # Returns:
    #     Hash: Tavily API response

    begin
      client = Tavily::Client.new(api_key: api_key)

      # Build search parameters
      search_params = {
        query: query,
        search_depth: search_depth,
        topic: topic,
        max_results: max_results,
        include_answer: include_answer,
        include_raw_content: include_raw_content,
        include_images: include_images
      }

      search_params[:include_domains] = include_domains if include_domains
      search_params[:exclude_domains] = exclude_domains if exclude_domains

      response = client.search(**search_params)

      {
        success: true,
        query: query,
        answer: response.answer,
        results: response.results || [],
        images: response.images || [],
        response_time: response.response_time,
        usage: response.usage || {}
      }
    rescue => e
      {
        error: e.message,
        query: query
      }
    end
  end

  def self.main
    options = {
      depth: "basic",
      topic: "general",
      max_results: 5,
      include_answer: true,
      raw_content: false,
      images: false,
      include_domains: nil,
      exclude_domains: nil,
      json_output: false
    }

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($0)} [options] QUERY"
      opts.separator ""
      opts.separator "Tavily AI Search - Optimized search for LLMs"
      opts.separator ""
      opts.separator "Options:"

      opts.on("-a", "--api-key KEY", "Tavily API key (or set TAVILY_API_KEY env var)") do |key|
        options[:api_key] = key
      end

      opts.on("-d", "--depth DEPTH", %w[basic advanced], "Search depth: 'basic' (fast) or 'advanced' (comprehensive)") do |depth|
        options[:depth] = depth
      end

      opts.on("-t", "--topic TOPIC", %w[general news], "Search topic: 'general' or 'news' (current events)") do |topic|
        options[:topic] = topic
      end

      opts.on("-m", "--max-results NUM", Integer, "Maximum number of results (1-10)") do |num|
        options[:max_results] = num
      end

      opts.on("--no-answer", "Exclude AI-generated answer summary") do
        options[:include_answer] = false
      end

      opts.on("--raw-content", "Include raw HTML content of sources") do
        options[:raw_content] = true
      end

      opts.on("--images", "Include relevant images in results") do
        options[:images] = true
      end

      opts.on("--include-domains DOMAIN1,DOMAIN2", Array, "List of domains to specifically include") do |domains|
        options[:include_domains] = domains
      end

      opts.on("--exclude-domains DOMAIN1,DOMAIN2", Array, "List of domains to exclude") do |domains|
        options[:exclude_domains] = domains
      end

      opts.on("--json", "Output raw JSON response") do
        options[:json_output] = true
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        puts <<~EXAMPLES

          Examples:
            # Basic search
            #{File.basename($0)} "What is quantum computing?"

            # Advanced search with more results
            #{File.basename($0)} "Climate change solutions" --depth advanced --max-results 10

            # News-focused search
            #{File.basename($0)} "AI developments" --topic news

            # Domain filtering
            #{File.basename($0)} "Python tutorials" --include-domains python.org --exclude-domains w3schools.com

            # Include images in results
            #{File.basename($0)} "Eiffel Tower" --images

          Environment Variables:
            TAVILY_API_KEY    Your Tavily API key (get one at https://tavily.com)
        EXAMPLES
        exit
      end
    end

    begin
      parser.parse!
      query = ARGV.join(' ')
      
      if query.empty?
        puts parser.help
        exit 1
      end
      
      # Get API key from args or environment
      api_key = options[:api_key] || ENV['TAVILY_API_KEY']
      
      result = search(
        query: query,
        api_key: api_key,
        search_depth: options[:depth],
        topic: options[:topic],
        max_results: options[:max_results],
        include_answer: options[:include_answer],
        include_raw_content: options[:raw_content],
        include_images: options[:images],
        include_domains: options[:include_domains],
        exclude_domains: options[:exclude_domains]
      )
      
      if options[:json_output]
        puts JSON.pretty_generate(result)
      else
        if result.key?(:error)
          $stderr.puts "Error: #{result[:error]}"
          exit 1
        end

        # Format human-readable output
        puts "Query: #{result[:query]}"
        puts "Response time: #{result[:response_time] || 'N/A'}s"
        puts "Credits used: #{result.dig(:usage, :credits) || 'N/A'}"
        puts

        if result[:answer]
          puts "=== AI ANSWER ==="
          puts result[:answer]
          puts
        end

        if result[:results] && !result[:results].empty?
          puts "=== RESULTS ==="
          result[:results].each_with_index do |item, i|
            puts
            puts "#{i+1}. #{item[:title] || 'No title'}"
            puts "   URL: #{item[:url] || 'N/A'}"
            puts "   Score: #{'%.3f' % item[:score]}" if item[:score]
            if item[:content]
              content = item[:content]
              content = content.length > 200 ? content[0..199] + "..." : content
              puts "   #{content}"
            end
          end
        end

        if result[:images] && !result[:images].empty?
          puts "\n=== IMAGES (#{[result[:images].length, 5].min}) ==="
          result[:images][0..4].each do |img_url|
            puts "   #{img_url}"
          end
        end
      end
    rescue OptionParser::InvalidOption => e
      $stderr.puts e.message
      exit 1
    end
  end
end

if __FILE__ == $0
  TavilySearch.main
end
