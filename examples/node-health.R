# OpenClaw Node Health Check (R) - TCP connect probe via base socketConnection
check_node <- function(addr) {
  parts <- strsplit(addr, ":")[[1]]
  host <- parts[1]
  port <- if (length(parts) > 1) as.integer(parts[2]) else 8080L
  con <- tryCatch(
    socketConnection(host = host, port = port, blocking = TRUE,
                     timeout = 3, open = "r+"),
    error = function(e) NULL
  )
  if (is.null(con)) {
    sprintf("FAIL %s: no connection", addr)
  } else {
    close(con)
    sprintf("OK   %s: connected", addr)
  }
}

args <- commandArgs(trailingOnly = TRUE)
nodes <- if (length(args) > 0) args else c("localhost:8080", "localhost:8081")
for (node in nodes) cat(check_node(node), "\n")
