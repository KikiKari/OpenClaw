import scala.io.Source

// OpenClaw log analyzer (Scala) — parses gateway access logs from stdin
object LogAnalyzer {
  private val pattern = """^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$""".r

  def main(args: Array[String]): Unit = {
    val counts = scala.collection.mutable.Map("INFO" -> 0, "WARN" -> 0, "ERROR" -> 0)
    for (line <- Source.stdin.getLines()) {
      line match {
        case pattern(ts, level, node, msg) =>
          counts(level) += 1
          if (level == "ERROR") println(s"⚠ $ts [$node] $msg")
        case _ =>
      }
    }
    println("\n--- Summary ---")
    for (level <- List("ERROR", "INFO", "WARN")) println(s"$level: ${counts(level)}")
  }
}
