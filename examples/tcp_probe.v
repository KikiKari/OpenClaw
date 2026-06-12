// OpenClaw TCP port probe (V) -- checks gateway nodes
module main

import net

fn probe(addr string) bool {
	mut conn := net.dial_tcp(addr) or { return false }
	conn.close() or {}
	return true
}

fn main() {
	nodes := ['localhost:8080', 'localhost:8081']
	for node in nodes {
		status := if probe(node) { 'OK  ' } else { 'FAIL' }
		println('${status} ${node}')
	}
}
