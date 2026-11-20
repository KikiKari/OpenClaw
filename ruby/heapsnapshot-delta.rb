#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "a56a179915f38fea9db3518dee05478a8bdc366abd45d28d9c6e5c5793b7be13", "source_sha256": "d38a1b483644fdcb8d1b3d4826eb7c89f54ac769bf87debab3ab554e0544844f", "target_language": "ruby"}
# heapsnapshot-delta.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/.agents/skills/openclaw-test-heap-leaks/scripts/heapsnapshot-delta.mjs
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'
require 'pathname'

def print_usage
  $stderr.puts "Usage: ruby heapsnapshot-delta.rb <before.heapsnapshot> <after.heapsnapshot> [--top N] [--min-kb N]"
  $stderr.puts "   or: ruby heapsnapshot-delta.rb --lane-dir <dir> [--pid PID] [--top N] [--min-kb N]"
end

def fail(message)
  $stderr.puts message
  exit 1
end

def parse_args(argv)
  options = {
    top: 30,
    min_kb: 64,
    lane_dir: nil,
    pid: nil,
    files: []
  }

  index = 0
  while index < argv.length
    arg = argv[index]
    case arg
    when "--top"
      options[:top] = argv[index + 1]&.to_i
      index += 1
    when "--min-kb"
      options[:min_kb] = argv[index + 1]&.to_i
      index += 1
    when "--lane-dir"
      options[:lane_dir] = argv[index + 1]
      index += 1
    when "--pid"
      options[:pid] = argv[index + 1]&.to_i
      index += 1
    else
      options[:files] << arg
    end
    index += 1
  end

  if !options[:top].is_a?(Numeric) || options[:top] <= 0
    fail("--top must be a positive integer")
  end
  if !options[:min_kb].is_a?(Numeric) || options[:min_kb] < 0
    fail("--min-kb must be a non-negative integer")
  end
  if options[:pid] != nil && (!options[:pid].is_a?(Integer) || options[:pid] <= 0)
    fail("--pid must be a positive integer")
  end

  options
end

class JsonStreamScanner
  def initialize(file_path)
    @file = File.open(file_path, "r")
    @buffer = ""
    @offset = 0
    @done = false
  end

  def close
    @file&.close
  end

  def compact_buffer
    if @offset > 65536
      @buffer = @buffer[@offset..-1]
      @offset = 0
    end
  end

  def ensure_available(count = 1)
    while !@done && @buffer.length - @offset < count
      chunk = @file.read(1024 * 1024)
      if chunk.nil?
        @done = true
        break
      end
      @buffer += chunk
    end
  end

  def peek
    ensure_available(1)
    @buffer[@offset] || nil
  end

  def next_char
    ensure_available(1)
    if @offset >= @buffer.length
      return nil
    end
    char = @buffer[@offset]
    @offset += 1
    compact_buffer
    char
  end

  def skip_whitespace
    loop do
      char = peek
      if char.nil? || !(/\s/ =~ char)
        return
      end
      next_char
    end
  end

  def expect_char(expected)
    char = next_char
    if char != expected
      fail("Expected #{expected} but found #{char || '<eof>'}")
    end
  end

  def find(sequence)
    matched = 0
    loop do
      char = next_char
      if char.nil?
        fail("Could not find #{sequence}")
      end
      if char == sequence[matched]
        matched += 1
        if matched == sequence.length
          return
        end
        next
      end
      matched = char == sequence[0] ? 1 : 0
      if matched == sequence.length
        return
      end
    end
  end

  def read_balanced_object
    start_char = next_char
    if start_char != "{"
      fail("Expected { but found #{start_char || '<eof>'}")
    end
    text = "{"
    depth = 1
    in_string = false
    escaped = false
    while depth > 0
      char = next_char
      if char.nil?
        fail("Unexpected EOF while reading JSON object")
      end
      text += char
      if in_string
        if escaped
          escaped = false
        elsif char == "\\"
          escaped = true
        elsif char == '"'
          in_string = false
        end
        next
      end
      if char == '"'
        in_string = true
      elsif char == "{"
        depth += 1
      elsif char == "}"
        depth -= 1
      end
    end
    text
  end

  def parse_number_array(&on_value)
    skip_whitespace
    expect_char("[")
    skip_whitespace
    if peek == "]"
      next_char
      return
    end

    token = ""
    index = 0
    flush = lambda do
      if token.length == 0
        fail("Unexpected empty number token")
      end
      value = token.to_i
      if !value.finite?
        fail("Invalid numeric token: #{token}")
      end
      on_value.call(value, index)
      index += 1
      token = ""
    end

    loop do
      char = next_char
      if char.nil?
        fail("Unexpected EOF while reading number array")
      end
      if char == "]"
        flush.call
        return
      end
      if char == ","
        flush.call
        next
      end
      if /\s/ =~ char
        next
      end
      token += char
    end
  end

  def read_json_string
    expect_char('"')
    value = ""
    loop do
      char = next_char
      if char.nil?
        fail("Unexpected EOF while reading JSON string")
      end
      if char == '"'
        return value
      end
      if char != "\\"
        value += char
        next
      end
      escaped = next_char
      if escaped.nil?
        fail("Unexpected EOF while reading JSON string escape")
      end
      if escaped == "u"
        hex = ""
        4.times do
          hex_char = next_char
          if hex_char.nil?
            fail("Unexpected EOF while reading JSON unicode escape")
          end
          hex += hex_char
        end
        value += [hex.to_i(16)].pack('U')
        next
      end
      value += case escaped
               when "b" then "\b"
               when "f" then "\f"
               when "n" then "\n"
               when "r" then "\r"
               when "t" then "\t"
               else escaped
               end
    end
  end

  def parse_string_array(&on_value)
    skip_whitespace
    expect_char("[")
    skip_whitespace
    if peek == "]"
      next_char
      return
    end

    index = 0
    loop do
      value = read_json_string
      on_value.call(value, index)
      index += 1
      skip_whitespace
      separator = next_char
      if separator == "]"
        return
      end
      if separator != ","
        fail("Expected , or ] but found #{separator || '<eof>'}")
      end
      skip_whitespace
    end
  end
end

def parse_heap_filename(file_path)
  base = Pathname.new(file_path).basename.to_s
  match = base.match(/^Heap\.(?<stamp>\d{8}\.\d{6})\.(?<pid>\d+)\.0\.(?<seq>\d+)\.heapsnapshot$/)
  if match.nil?
    return nil
  end
  {
    file_path: file_path,
    pid: match[:pid].to_i,
    stamp: match[:stamp],
    sequence: match[:seq].to_i
  }
end

def resolve_pair(options)
  if options[:lane_dir]
    entries = Dir.entries(options[:lane_dir])
                 .map { |name| parse_heap_filename(File.join(options[:lane_dir], name)) }
                 .compact
                 .select { |entry| options[:pid].nil? || entry[:pid] == options[:pid] }
                 .sort { |left, right|
                   cmp = left[:pid] <=> right[:pid]
                   if cmp != 0
                     cmp
                   else
                     cmp = left[:stamp] <=> right[:stamp]
                     if cmp != 0
                       cmp
                     else
                       left[:sequence] <=> right[:sequence]
                     end
                   end
                 }

    if entries.empty?
      fail("No matching heap snapshots found in #{options[:lane_dir]}")
    end

    groups = {}
    entries.each do |entry|
      group = groups[entry[:pid]] || []
      group << entry
      groups[entry[:pid]] = group
    end

    candidates = groups.values.map do |group|
      {
        pid: group[0][:pid],
        before: group[0],
        after: group[-1],
        count: group.length
      }
    end.select { |entry| entry[:count] >= 2 }

    if candidates.empty?
      fail("Need at least two snapshots for one PID in #{options[:lane_dir]}")
    end

    chosen = if options[:pid] != nil
               candidates.find { |entry| entry[:pid] == options[:pid] }
             else
               candidates.sort { |left, right|
                 cmp = right[:count] <=> left[:count]
                 if cmp != 0
                   cmp
                 else
                   left[:pid] <=> right[:pid]
                 end
               }.first
             end

    if chosen.nil?
      fail("No PID with at least two snapshots matched in #{options[:lane_dir]}")
    end

    return {
      before: chosen[:before][:file_path],
      after: chosen[:after][:file_path],
      pid: chosen[:pid],
      snapshot_count: chosen[:count]
    }
  end

  if options[:files].length != 2
    print_usage
    exit 1
  end

  {
    before: options[:files][0],
    after: options[:files][1],
    pid: nil,
    snapshot_count: 2
  }
end

def parse_snapshot_meta(scanner)
  scanner.find('"snapshot":')
  scanner.skip_whitespace
  meta_object_text = scanner.read_balanced_object
  parsed = JSON.parse(meta_object_text)
  parsed["meta"] || nil
end

def build_summary(file_path)
  scanner = JsonStreamScanner.new(file_path)
  begin
    meta = parse_snapshot_meta(scanner)
    if meta.nil?
      fail("Invalid heap snapshot: #{file_path}")
    end

    node_field_count = meta["node_fields"].length
    type_names = meta["node_types"][0]
    type_index = meta["node_fields"].index("type")
    name_index = meta["node_fields"].index("name")
    self_size_index = meta["node_fields"].index("self_size")
    if type_index.nil? || name_index.nil? || self_size_index.nil?
      fail("Unsupported heap snapshot schema: #{file_path}")
    end

    summary_by_index = {}
    node_count = 0
    current_type_id = 0
    current_name_id = 0
    current_self_size = 0
    scanner.find('"nodes":')
    scanner.parse_number_array do |value, index|
      field_index = index % node_field_count
      if field_index == type_index
        current_type_id = value
        next
      end
      if field_index == name_index
        current_name_id = value
        next
      end
      if field_index == self_size_index
        current_self_size = value
      end
      if field_index != node_field_count - 1
        next
      end
      key = "#{current_type_id}\t#{current_name_id}"
      current = summary_by_index[key] || {
        type_id: current_type_id,
        name_id: current_name_id,
        self_size: 0,
        count: 0
      }
      current[:self_size] += current_self_size
      current[:count] += 1
      summary_by_index[key] = current
      node_count += 1
    end

    required_name_ids = summary_by_index.values.map { |entry| entry[:name_id] }.select { |value| value >= 0 }.to_set
    name_strings = {}
    scanner.find('"strings":')
    scanner.parse_string_array do |value, index|
      if required_name_ids.include?(index)
        name_strings[index] = value
      end
    end

    summary = {}
    summary_by_index.each do |key, entry|
      type_name = type_names[entry[:type_id]] || "unknown"
      name_string = name_strings[entry[:name_id]] || ""
      summary_key = "#{type_name}\t#{name_string}"
      summary[summary_key] = {
        type: type_name,
        name: name_string,
        self_size: entry[:self_size],
        count: entry[:count]
      }
    end

    {
      node_count: node_count,
      summary: summary
    }
  ensure
    scanner.close
  end
end

def format_bytes(bytes)
  abs_bytes = bytes.abs
  if abs_bytes >= 1024 ** 2
    return "#{'%.2f' % (bytes.to_f / (1024 ** 2))} MiB"
  end
  if abs_bytes >= 1024
    return "#{'%.1f' % (bytes.to_f / 1024)} KiB"
  end
  "#{bytes} B"
end

def format_delta(bytes)
  "#{bytes >= 0 ? '+' : '-'}#{format_bytes(bytes.abs)}"
end

def truncate(text, max_length)
  return text if text.length <= max_length
  "#{text[0, max_length - 1]}…"
end

def main
  options = parse_args(ARGV)
  pair = resolve_pair(options)
  before = build_summary(pair[:before])
  after = build_summary(pair[:after])
  min_bytes = options[:min_kb] * 1024

  rows = []
  after[:summary].each do |key, next_entry|
    previous = before[:summary][key] || { self_size: 0, count: 0 }
    size_delta = next_entry[:self_size] - previous[:self_size]
    count_delta = next_entry[:count] - previous[:count]
    if size_delta < min_bytes
      next
    end
    rows << {
      type: next_entry[:type],
      name: next_entry[:name],
      size_delta: size_delta,
      count_delta: count_delta,
      after_size: next_entry[:self_size],
      after_count: next_entry[:count]
    }
  end

  rows.sort! { |left, right|
    cmp = right[:size_delta] <=> left[:size_delta]
    if cmp != 0
      cmp
    else
      right[:count_delta] <=> left[:count_delta]
    end
  }

  puts "before: #{pair[:before]}"
  puts "after:  #{pair[:after]}"
  if pair[:pid] != nil
    puts "pid:    #{pair[:pid]} (#{pair[:snapshot_count]} snapshots found)"
  end
  puts "nodes:   #{before[:node_count]} -> #{after[:node_count]} (#{"+" if after[:node_count] - before[:node_count] >= 0}#{after[:node_count] - before[:node_count]})"
  puts "filter:  top=#{options[:top]} min=#{options[:min_kb]} KiB"
  puts ""

  if rows.empty?
    puts "No entries exceeded the minimum delta."
    return
  end

  rows.first(options[:top]).each do |row|
    puts [
      format_delta(row[:size_delta]).rjust(11),
      "count #{"+" if row[:count_delta] >= 0}#{row[:count_delta]}".rjust(10),
      row[:type].ljust(16),
      truncate(row[:name].empty? ? "(empty)" : row[:name], 96)
    ].join("  ")
  end
end

main
