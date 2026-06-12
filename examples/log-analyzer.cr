# OpenClaw log analyzer (Crystal) — parses gateway access logs from stdin
pattern = /^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$/
counts = {"INFO" => 0, "WARN" => 0, "ERROR" => 0}

STDIN.each_line do |line|
  if m = pattern.match(line.chomp)
    level = m[2]
    counts[level] += 1
    puts "⚠ #{m[1]} [#{m[3]}] #{m[4]}" if level == "ERROR"
  end
end

puts "\n--- Summary ---"
["ERROR", "INFO", "WARN"].each { |level| puts "#{level}: #{counts[level]}" }
