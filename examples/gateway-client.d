import std.stdio;
import std.net.curl;

// OpenClaw Gateway Client (D) -- via std.net.curl
void main(string[] args)
{
    string url = args.length > 1 ? args[1] : "http://localhost:8080";
    try
    {
        auto content = get(url ~ "/health");
        writeln("Gateway ", url, " -> OK (", content.length, " bytes)");
    }
    catch (Exception e)
    {
        writeln("Gateway ", url, " -> FAIL: ", e.msg);
    }
}
