// OpenClaw Gateway Client (Haxe)
class GatewayClient {
    static function checkHealth(baseUrl:String):Int {
        var status = 0;
        var http = new haxe.Http(baseUrl + "/health");
        http.onStatus = function(code) status = code;
        http.onError = function(_) status = 0;
        http.request(false);
        return status;
    }

    static function main() {
        var args = Sys.args();
        var url = args.length > 0 ? args[0] : "http://localhost:8080";
        Sys.println("Gateway " + url + " -> HTTP " + checkHealth(url));
    }
}
