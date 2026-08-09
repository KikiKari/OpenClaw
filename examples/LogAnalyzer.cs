using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

// OpenClaw log analyzer (C#) — parses gateway access logs from stdin
class LogAnalyzer
{
    static void Main()
    {
        var counts = new Dictionary<string, int> { ["INFO"] = 0, ["WARN"] = 0, ["ERROR"] = 0 };
        var rx = new Regex(@"^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$");
        string? line;
        while ((line = Console.ReadLine()) != null)
        {
            var m = rx.Match(line);
            if (!m.Success) continue;
            string level = m.Groups[2].Value;
            counts[level]++;
            if (level == "ERROR")
                Console.WriteLine($"⚠ {m.Groups[1].Value} [{m.Groups[3].Value}] {m.Groups[4].Value}");
        }
        Console.WriteLine("\n--- Summary ---");
        foreach (var level in new[] { "ERROR", "INFO", "WARN" })
            Console.WriteLine($"{level}: {counts[level]}");
    }
}
