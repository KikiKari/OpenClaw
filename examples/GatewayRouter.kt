// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
val nodes = listOf("gateway1.openclaw.internal", "gateway2.openclaw.internal")

fun getNode(): String = nodes.random()

fun main() {
    println("OpenClaw routing to: ${getNode()}")
}
