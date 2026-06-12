// OpenClaw log analyzer (Kotlin) — parses gateway access logs from stdin
fun main() {
    val pattern = Regex("""^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$""")
    val counts = mutableMapOf("INFO" to 0, "WARN" to 0, "ERROR" to 0)

    generateSequence(::readLine).forEach { line ->
        val m = pattern.matchEntire(line) ?: return@forEach
        val (ts, level, node, msg) = m.destructured
        counts[level] = counts.getValue(level) + 1
        if (level == "ERROR") println("⚠ $ts [$node] $msg")
    }

    println("\n--- Summary ---")
    for (level in listOf("ERROR", "INFO", "WARN")) println("$level: ${counts[level]}")
}
