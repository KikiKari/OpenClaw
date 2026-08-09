using System;
using System.Net.Sockets;

// OpenClaw TCP port probe (C#) — checks gateway nodes
class TcpProbe
{
    static bool Probe(string host, int port, int timeoutMs = 3000)
    {
        using var client = new TcpClient();
        try
        {
            var task = client.ConnectAsync(host, port);
            return task.Wait(timeoutMs) && client.Connected;
        }
        catch
        {
            return false;
        }
    }

    static void Main()
    {
        var nodes = new[] { ("localhost", 8080), ("localhost", 8081) };
        foreach (var (host, port) in nodes)
            Console.WriteLine($"{(Probe(host, port) ? "OK  " : "FAIL")} {host}:{port}");
    }
}
