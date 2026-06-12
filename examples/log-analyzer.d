import std.stdio;
import std.regex;

// OpenClaw log analyzer (D) — parses gateway access logs from stdin
void main()
{
    auto pattern = regex(`^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$`);
    int[string] counts = ["INFO": 0, "WARN": 0, "ERROR": 0];

    foreach (line; stdin.byLine)
    {
        auto m = matchFirst(line, pattern);
        if (m.empty)
            continue;
        string level = m[2].idup;
        counts[level]++;
        if (level == "ERROR")
            writeln("⚠ ", m[1], " [", m[3], "] ", m[4]);
    }

    writeln("\n--- Summary ---");
    foreach (level; ["ERROR", "INFO", "WARN"])
        writeln(level, ": ", counts[level]);
}
