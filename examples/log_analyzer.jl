# OpenClaw log analyzer (Julia) — parses gateway access logs from stdin
const PATTERN = r"^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$"
counts = Dict("INFO" => 0, "WARN" => 0, "ERROR" => 0)

for line in eachline(stdin)
    m = match(PATTERN, line)
    m === nothing && continue
    level = m.captures[2]
    counts[level] += 1
    if level == "ERROR"
        println("⚠ ", m.captures[1], " [", m.captures[3], "] ", m.captures[4])
    end
end

println("\n--- Summary ---")
for level in ["ERROR", "INFO", "WARN"]
    println(level, ": ", counts[level])
end
