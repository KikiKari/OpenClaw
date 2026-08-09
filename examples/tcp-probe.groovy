// OpenClaw TCP port probe (Groovy) — checks gateway nodes
def probe(String host, int port, int timeoutMs = 3000) {
    try {
        def socket = new Socket()
        socket.connect(new InetSocketAddress(host, port), timeoutMs)
        socket.close()
        return true
    } catch (Exception e) {
        return false
    }
}

def nodes = [['localhost', 8080], ['localhost', 8081]]
nodes.each { host, port ->
    println "${probe(host, port) ? 'OK  ' : 'FAIL'} ${host}:${port}"
}
