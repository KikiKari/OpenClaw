import std.stdio;
import std.socket;
import std.typecons : tuple;

// OpenClaw TCP port probe (D) — checks gateway nodes
bool probe(string host, ushort port)
{
    try
    {
        auto addr = new InternetAddress(host, port);
        auto socket = new TcpSocket();
        scope (exit) socket.close();
        socket.connect(addr);
        return true;
    }
    catch (Exception e)
    {
        return false;
    }
}

void main()
{
    auto nodes = [
        tuple("localhost", cast(ushort) 8080),
        tuple("localhost", cast(ushort) 8081),
    ];
    foreach (node; nodes)
        writeln(probe(node[0], node[1]) ? "OK  " : "FAIL", " ", node[0], ":", node[1]);
}
