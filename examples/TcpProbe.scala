import java.net.{InetSocketAddress, Socket}

// OpenClaw TCP port probe (Scala) — checks gateway nodes
object TcpProbe {
  def probe(host: String, port: Int, timeoutMs: Int = 3000): Boolean = {
    val socket = new Socket()
    try {
      socket.connect(new InetSocketAddress(host, port), timeoutMs)
      true
    } catch {
      case _: Exception => false
    } finally {
      socket.close()
    }
  }

  def main(args: Array[String]): Unit = {
    val nodes = List(("localhost", 8080), ("localhost", 8081))
    for ((host, port) <- nodes)
      println(s"${if (probe(host, port)) "OK  " else "FAIL"} $host:$port")
  }
}
