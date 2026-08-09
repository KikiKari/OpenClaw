import Foundation

// OpenClaw log analyzer (Swift) — parses gateway access logs from stdin
let pattern = try! NSRegularExpression(
    pattern: "^(\\S+)\\s+(INFO|WARN|ERROR)\\s+(\\S+)\\s+(.+)$")
var counts = ["INFO": 0, "WARN": 0, "ERROR": 0]

while let line = readLine() {
    let range = NSRange(line.startIndex..., in: line)
    guard let m = pattern.firstMatch(in: line, range: range) else { continue }
    func group(_ i: Int) -> String {
        guard let r = Range(m.range(at: i), in: line) else { return "" }
        return String(line[r])
    }
    let level = group(2)
    counts[level, default: 0] += 1
    if level == "ERROR" {
        print("⚠ \(group(1)) [\(group(3))] \(group(4))")
    }
}

print("\n--- Summary ---")
for level in ["ERROR", "INFO", "WARN"] {
    print("\(level): \(counts[level] ?? 0)")
}
