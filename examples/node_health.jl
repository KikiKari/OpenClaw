# OpenClaw Node Health Check (Julia) — raw TCP connect probe via Sockets
using Sockets

function check_node(addr::AbstractString)
    parts = split(addr, ':')
    host = parts[1]
    port = length(parts) > 1 ? parse(Int, parts[2]) : 8080
    try
        sock = connect(host, port)
        close(sock)
        return "OK   $addr: connected"
    catch e
        return "FAIL $addr: $(e)"
    end
end

nodes = isempty(ARGS) ? ["localhost:8080", "localhost:8081"] : ARGS
for node in nodes
    println(check_node(node))
end
