using System;

// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
class GatewayRouter
{
    static readonly string[] Nodes =
    {
        "gateway1.openclaw.internal",
        "gateway2.openclaw.internal",
    };

    static string GetNode() => Nodes[Random.Shared.Next(Nodes.Length)];

    static void Main()
    {
        Console.WriteLine($"OpenClaw routing to: {GetNode()}");
    }
}
