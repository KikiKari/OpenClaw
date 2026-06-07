import std/[httpclient, os, strformat]

# OpenClaw Gateway Client (Nim)
proc checkHealth(baseUrl: string): int =
  var client = newHttpClient(timeout = 5000)
  try:
    let response = client.request(baseUrl & "/health", httpMethod = HttpGet)
    result = response.code.int
  except CatchableError:
    result = 0
  finally:
    client.close()

let url = if paramCount() > 0: paramStr(1) else: "http://localhost:8080"
echo &"Gateway {url} -> HTTP {checkHealth(url)}"
