import scala.util.Random

// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
object GatewayRouter {
  private val nodes = Vector("gateway1.openclaw.internal", "gateway2.openclaw.internal")

  def getNode(): String = nodes(Random.nextInt(nodes.length))

  def main(args: Array[String]): Unit =
    println(s"OpenClaw routing to: ${getNode()}")
}
