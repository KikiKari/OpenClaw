# OpenClaw TCP port probe (Elixir) — checks gateway nodes
defmodule TcpProbe do
  def probe(host, port, timeout \\ 3000) do
    opts = [:binary, active: false]

    case :gen_tcp.connect(String.to_charlist(host), port, opts, timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end
end

nodes = [{"localhost", 8080}, {"localhost", 8081}]

Enum.each(nodes, fn {host, port} ->
  status = if TcpProbe.probe(host, port), do: "OK  ", else: "FAIL"
  IO.puts("#{status} #{host}:#{port}")
end)
