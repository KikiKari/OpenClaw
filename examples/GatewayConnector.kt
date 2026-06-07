import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

// OpenClaw Gateway Connector (Kotlin)
class GatewayConnector(private val baseUrl: String) {
    private val client: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build()

    fun checkHealth(): Int {
        val request = HttpRequest.newBuilder()
            .uri(URI.create("$baseUrl/health"))
            .timeout(Duration.ofSeconds(5))
            .GET()
            .build()
        return client.send(request, HttpResponse.BodyHandlers.ofString()).statusCode()
    }
}

fun main(args: Array<String>) {
    val url = args.firstOrNull() ?: "http://localhost:8080"
    val status = GatewayConnector(url).checkHealth()
    println("Gateway $url -> HTTP $status")
}
