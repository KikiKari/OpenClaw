import std/net

# OpenClaw TCP port probe (Nim) — checks gateway nodes
proc probe(host: string, port: int): bool =
  var socket = newSocket()
  try:
    socket.connect(host, Port(port), timeout = 3000)
    result = true
  except OSError, TimeoutError:
    result = false
  finally:
    socket.close()

let nodes = [("localhost", 8080), ("localhost", 8081)]
for (host, port) in nodes:
  echo (if probe(host, port): "OK  " else: "FAIL"), " ", host, ":", port
