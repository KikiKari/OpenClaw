#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b9df820e662bc38ece2b4061ce6dcafb2979ef1b99efe7c3bc12f19b47fb0724", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "ruby"}
# model_usage.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

# Summarize CodexBar local cost usage by model.
#
# Defaults to current model (most recent daily entry), or list all models.

require 'json'
require 'date'
require 'optparse'

def eprint(msg)
  $stderr.puts(msg)
end

def run_codexbar_cost(provider)
  cmd = ['codexbar', 'cost', '--format', 'json', '--provider', provider]
  begin
    output = `#{cmd.join(' ')}`
    unless $?.success?
      raise "codexbar cost failed (exit #{$?.exitstatus})."
    end
  rescue Errno::ENOENT
    raise 'codexbar not found on PATH. Install CodexBar CLI first.'
  end
  
  begin
    payload = JSON.parse(output)
  rescue JSON::ParserError => e
    raise "Failed to parse codexbar JSON output: #{e}"
  end
  
  unless payload.is_a?(Array)
    raise 'Expected codexbar cost JSON array.'
  end
  
  payload
end

def load_payload(input_path, provider)
  if input_path
    if input_path == '-'
      raw = $stdin.read
    else
      raw = File.read(input_path, encoding: 'utf-8')
    end
    data = JSON.parse(raw)
  else
    data = run_codexbar_cost(provider)
  end

  if data.is_a?(Hash)
    return data
  end

  if data.is_a?(Array)
    data.each do |entry|
      if entry.is_a?(Hash) && entry['provider'] == provider
        return entry
      end
    end
    raise "Provider '#{provider}' not found in codexbar payload."
  end

  raise 'Unsupported JSON input format.'
end

def parse_daily_entries(payload)
  daily = payload['daily']
  return [] unless daily.is_a?(Array)
  daily.select { |entry| entry.is_a?(Hash) }
end

def parse_date(value)
  Date.parse(value) rescue nil
end

def filter_by_days(entries, days)
  return entries unless days
  
  cutoff = Date.today - (days - 1)
  entries.select do |entry|
    day = entry['date']
    next unless day.is_a?(String)
    
    parsed = parse_date(day)
    parsed && parsed >= cutoff
  end
end

def aggregate_costs(entries)
  totals = {}
  
  entries.each do |entry|
    breakdowns = entry['modelBreakdowns']
    next unless breakdowns.is_a?(Array)
    
    breakdowns.each do |item|
      next unless item.is_a?(Hash)
      
      model = item['modelName']
      cost = item['cost']
      next unless model.is_a?(String)
      next unless cost.is_a?(Numeric)
      
      totals[model] = (totals[model] || 0.0) + cost.to_f
    end
  end
  
  totals
end

def pick_current_model(entries)
  return [nil, nil] if entries.empty?
  
  sorted_entries = entries.sort_by { |entry| entry['date'] || '' }
  
  sorted_entries.reverse_each do |entry|
    breakdowns = entry['modelBreakdowns']
    if breakdowns.is_a?(Array) && !breakdowns.empty?
      scored = []
      
      breakdowns.each do |item|
        next unless item.is_a?(Hash)
        
        model = item['modelName']
        cost = item['cost']
        if model.is_a?(String) && cost.is_a?(Numeric)
          scored << { model: model, cost: cost.to_f }
        end
      end
      
      unless scored.empty?
        scored.sort_by! { |item| -item[:cost] }
        return [scored.first[:model], entry['date']]
      end
    end
    
    models_used = entry['modelsUsed']
    if models_used.is_a?(Array) && !models_used.empty?
      last = models_used.last
      return [last, entry['date']] if last.is_a?(String)
    end
  end
  
  [nil, nil]
end

def usd(value)
  return '—' if value.nil?
  "$#{value.to_f.round(2)}"
end

def latest_day_cost(entries, model)
  return [nil, nil] if entries.empty?
  
  sorted_entries = entries.sort_by { |entry| entry['date'] || '' }
  
  sorted_entries.reverse_each do |entry|
    breakdowns = entry['modelBreakdowns']
    next unless breakdowns.is_a?(Array)
    
    breakdowns.each do |item|
      next unless item.is_a?(Hash)
      next unless item['modelName'] == model
      
      cost = item['cost']
      day = entry['date']
      return [day, cost.to_f] if cost.is_a?(Numeric) && day.is_a?(String)
      return [day, nil] if day.is_a?(String)
    end
  end
  
  [nil, nil]
end

def render_text_current(provider, model, latest_date, total_cost, latest_cost, latest_cost_date, entry_count)
  lines = [
    "Provider: #{provider}",
    "Current model: #{model}"
  ]
  
  lines << "Latest model date: #{latest_date}" if latest_date
  lines << "Total cost (rows): #{usd(total_cost)}"
  
  if latest_cost_date
    lines << "Latest day cost: #{usd(latest_cost)} (#{latest_cost_date})"
  end
  
  lines << "Daily rows: #{entry_count}"
  lines.join("\n")
end

def render_text_all(provider, totals)
  lines = [
    "Provider: #{provider}",
    "Models:"
  ]
  
  totals.sort_by { |_, cost| -cost }.each do |model, cost|
    lines << "- #{model}: #{usd(cost)}"
  end
  
  lines.join("\n")
end

def build_json_current(provider, model, latest_date, total_cost, latest_cost, latest_cost_date, entry_count)
  {
    'provider' => provider,
    'mode' => 'current',
    'model' => model,
    'latestModelDate' => latest_date,
    'totalCostUSD' => total_cost,
    'latestDayCostUSD' => latest_cost,
    'latestDayCostDate' => latest_cost_date,
    'dailyRowCount' => entry_count
  }
end

def build_json_all(provider, totals)
  {
    'provider' => provider,
    'mode' => 'all',
    'models' => totals.sort_by { |_, cost| -cost }.map do |model, cost|
      { 'model' => model, 'totalCostUSD' => cost }
    end
  }
end

def main
  options = {
    provider: 'codex',
    mode: 'current',
    format: 'text',
    pretty: false
  }
  
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: model_usage.rb [options]'
    opts.on('--provider PROVIDER', %w[codex claude], 'Provider (codex or claude)') do |p|
      options[:provider] = p
    end
    opts.on('--mode MODE', %w[current all], 'Mode (current or all)') do |m|
      options[:mode] = m
    end
    opts.on('--model MODEL', 'Explicit model name to report instead of auto-current.') do |m|
      options[:model] = m
    end
    opts.on('--input INPUT', 'Path to codexbar cost JSON (or \'-\' for stdin).') do |i|
      options[:input] = i
    end
    opts.on('--days DAYS', Integer, 'Limit to last N days (based on daily rows).') do |d|
      options[:days] = d
    end
    opts.on('--format FORMAT', %w[text json], 'Output format (text or json)') do |f|
      options[:format] = f
    end
    opts.on('--pretty', 'Pretty-print JSON output.') do
      options[:pretty] = true
    end
  end
  
  parser.parse!
  
  begin
    payload = load_payload(options[:input], options[:provider])
  rescue => e
    eprint(e.message)
    return 1
  end
  
  entries = parse_daily_entries(payload)
  entries = filter_by_days(entries, options[:days])
  
  if options[:mode] == 'current'
    model = options[:model]
    latest_date = nil
    
    unless model
      model, latest_date = pick_current_model(entries)
    end
    
    unless model
      eprint('No model data found in codexbar cost payload.')
      return 2
    end
    
    totals = aggregate_costs(entries)
    total_cost = totals[model]
    latest_cost_date, latest_cost = latest_day_cost(entries, model)
    
    if options[:format] == 'json'
      payload_out = build_json_current(
        options[:provider],
        model,
        latest_date,
        total_cost,
        latest_cost,
        latest_cost_date,
        entries.size
      )
      
      indent = options[:pretty] ? 2 : nil
      puts JSON.generate(payload_out, indent: indent)
    else
      puts render_text_current(
        options[:provider],
        model,
        latest_date,
        total_cost,
        latest_cost,
        latest_cost_date,
        entries.size
      )
    end
    
    return 0
  end
  
  totals = aggregate_costs(entries)
  if totals.empty?
    eprint('No model breakdowns found in codexbar cost payload.')
    return 2
  end
  
  if options[:format] == 'json'
    payload_out = build_json_all(options[:provider], totals)
    indent = options[:pretty] ? 2 : nil
    puts JSON.generate(payload_out, indent: indent)
  else
    puts render_text_all(options[:provider], totals)
  end
  
  0
end

exit(main) if __FILE__ == $0
