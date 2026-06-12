import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

// OpenClaw Gateway Connector (Scala)
object GatewayConnector {
  private val client = HttpClient
    .newBuilder()
    .connectTimeout(Duration.ofSeconds(5))
    .build()

  def checkHealth(baseUrl: String): Int = {
    val request = HttpRequest
      .newBuilder()
      .uri(URI.create(s"$baseUrl/health"))
      .timeout(Duration.ofSeconds(5))
      .GET()
      .build()
    client.send(request, HttpResponse.BodyHandlers.ofString()).statusCode()
  }

  def main(args: Array[String]): Unit = {
    val url = if (args.nonEmpty) args(0) else "http://localhost:8080"
    println(s"Gateway $url -> HTTP ${checkHealth(url)}")
  }
}
