// OpenClaw Gateway Client (V)
module main

import net.http
import os

fn check_health(base_url string) int {
	resp := http.get('${base_url}/health') or { return 0 }
	return resp.status_code
}

fn main() {
	url := if os.args.len > 1 { os.args[1] } else { 'http://localhost:8080' }
	println('Gateway ${url} -> HTTP ${check_health(url)}')
}
