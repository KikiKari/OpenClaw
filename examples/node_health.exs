# OpenClaw Node Health Check (Elixir)
defmodule NodeHealth do
  def check(url) do
    :inets.start()
    :ssl.start()
    request = {String.to_charlist(url <> "/health"), []}

    case :httpc.request(:get, request, [timeout: 5000], []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        "OK   #{url}: #{status}"

      {:error, reason} ->
        "FAIL #{url}: #{inspect(reason)}"
    end
  end
end

nodes =
  case System.argv() do
    [] -> ["http://localhost:8080", "http://localhost:8081"]
    args -> args
  end

Enum.each(nodes, fn node -> IO.puts(NodeHealth.check(node)) end)
