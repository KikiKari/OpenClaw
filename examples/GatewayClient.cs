using System;
using System.Net.Http;
using System.Threading.Tasks;

// OpenClaw Gateway Client (C#)
public class GatewayClient
{
    private static readonly HttpClient Client = new HttpClient
    {
        Timeout = TimeSpan.FromSeconds(5),
    };

    private readonly string _baseUrl;

    public GatewayClient(string baseUrl) => _baseUrl = baseUrl;

    public async Task<int> CheckHealthAsync()
    {
        using HttpResponseMessage response = await Client.GetAsync($"{_baseUrl}/health");
        return (int)response.StatusCode;
    }

    public static async Task Main(string[] args)
    {
        string url = args.Length > 0 ? args[0] : "http://localhost:8080";
        int status = await new GatewayClient(url).CheckHealthAsync();
        Console.WriteLine($"Gateway {url} -> HTTP {status}");
    }
}
