// OpenClaw Gateway Client (Groovy)
def checkHealth(String baseUrl) {
    def conn = new URL("${baseUrl}/health").openConnection()
    conn.requestMethod = 'GET'
    conn.connectTimeout = 5000
    conn.readTimeout = 5000
    return conn.responseCode
}

def url = args.length > 0 ? args[0] : 'http://localhost:8080'
println "Gateway ${url} -> HTTP ${checkHealth(url)}"
