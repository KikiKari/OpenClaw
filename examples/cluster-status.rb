require 'net/http'
require 'json'

NODES = (ENV['OPENCLAW_NODES'] || 'localhost:8080,localhost:8081').split(',')

def check_node(host, port)
  http = Net::HTTP.new(host, port.to_i)
  http.open_timeout = 3
  http.read_timeout = 3
  response = http.get('/health')
  { node: "#{host}:#{port}", status: response.code.to_i, ok: response.code == '200' }
rescue => e
  { node: "#{host}:#{port}", status: 0, ok: false, error: e.message }
end

results = NODES.map { |n| h, p = n.split(':'); check_node(h, p || '8080') }
results.each { |r| puts "#{r[:ok] ? '✓' : '✗'} #{r[:node]} — #{r[:status]}" }