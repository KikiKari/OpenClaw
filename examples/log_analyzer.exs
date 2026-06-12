# OpenClaw log analyzer (Elixir) — parses gateway access logs from stdin
defmodule LogAnalyzer do
  @pattern ~r/^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$/

  def run do
    counts =
      IO.stream(:stdio, :line)
      |> Enum.reduce(%{"INFO" => 0, "WARN" => 0, "ERROR" => 0}, fn line, acc ->
        case Regex.run(@pattern, String.trim(line)) do
          [_, ts, level, node, msg] ->
            if level == "ERROR", do: IO.puts("⚠ #{ts} [#{node}] #{msg}")
            Map.update!(acc, level, &(&1 + 1))

          _ ->
            acc
        end
      end)

    IO.puts("\n--- Summary ---")
    for level <- ["ERROR", "INFO", "WARN"], do: IO.puts("#{level}: #{counts[level]}")
  end
end

LogAnalyzer.run()
