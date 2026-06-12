import java.net.InetSocketAddress
import java.net.Socket

// OpenClaw TCP port probe (Kotlin) — checks gateway nodes
fun probe(host: String, port: Int, timeoutMs: Int = 3000): Boolean =
    try {
        Socket().use { it.connect(InetSocketAddress(host, port), timeoutMs); true }
    } catch (e: Exception) {
        false
    }

fun main() {
    val nodes = listOf("localhost" to 8080, "localhost" to 8081)
    for ((host, port) in nodes) {
        println("${if (probe(host, port)) "OK  " else "FAIL"} $host:$port")
    }
}
