// OpenClaw Node Health Check (Vala) — TCP connect probe via GIO
int main (string[] args) {
    string[] nodes = args.length > 1
        ? args[1:args.length]
        : { "localhost:8080", "localhost:8081" };

    var client = new SocketClient ();
    foreach (var node in nodes) {
        try {
            var conn = client.connect_to_host (node, 8080);
            conn.close ();
            print ("OK   %s: connected\n", node);
        } catch (Error e) {
            print ("FAIL %s: %s\n", node, e.message);
        }
    }
    return 0;
}
