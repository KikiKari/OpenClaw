require "http/client"
require "uri"

# OpenClaw Gateway Client (Crystal)
def check_health(base_url : String) : Int32
  uri = URI.parse("#{base_url}/health")
  client = HTTP::Client.new(uri.host.not_nil!, uri.port || 80)
  client.connect_timeout = 5.seconds
  response = client.get(uri.request_target)
  response.status_code
rescue
  0
end

url = ARGV.size > 0 ? ARGV[0] : "http://localhost:8080"
puts "Gateway #{url} -> HTTP #{check_health(url)}"
