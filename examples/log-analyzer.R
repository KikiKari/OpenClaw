# OpenClaw log analyzer (R) - parses gateway access logs from stdin
pattern <- "^(\\S+)\\s+(INFO|WARN|ERROR)\\s+(\\S+)\\s+(.+)$"
counts <- c(INFO = 0, WARN = 0, ERROR = 0)

con <- file("stdin", "r")
while (length(line <- readLines(con, n = 1)) > 0) {
  m <- regmatches(line, regexec(pattern, line))[[1]]
  if (length(m) == 5) {
    level <- m[3]
    counts[level] <- counts[level] + 1
    if (level == "ERROR") {
      cat(sprintf("⚠ %s [%s] %s\n", m[2], m[4], m[5]))
    }
  }
}
close(con)

cat("\n--- Summary ---\n")
for (level in c("ERROR", "INFO", "WARN")) {
  cat(sprintf("%s: %d\n", level, counts[level]))
}
