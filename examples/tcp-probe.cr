require "socket"

# OpenClaw TCP port probe (Crystal) — checks gateway nodes
def probe(host : String, port : Int32) : Bool
  socket = TCPSocket.new(host, port, connect_timeout: 3.seconds)
  socket.close
  true
rescue
  false
end

nodes = [{"localhost", 8080}, {"localhost", 8081}]
nodes.each do |(host, port)|
  puts "#{probe(host, port) ? "OK  " : "FAIL"} #{host}:#{port}"
end
