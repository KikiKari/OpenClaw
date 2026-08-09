#!/usr/bin/env tclsh
# gateway-dashboard.html — portiert nach tcl
# Quelle: html, OpenClaw@main:examples/gateway-dashboard.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Tcl 8.6 Script to generate gateway-dashboard.html
# Usage: tclsh gateway-dashboard.tcl [output_file]

# Default output filename
set output_file "gateway-dashboard.html"
if {$argc > 0} {
    set output_file [lindex $argv 0]
}

# Open output file for writing
set fd [open $output_file w]

# Write DOCTYPE and html tag
puts $fd {<!DOCTYPE html>}
puts $fd {<html lang="en">}

# Head section
puts $fd {<head>}
puts $fd {  <meta charset="UTF-8">}
puts $fd {  <meta name="viewport" content="width=device-width, initial-scale=1.0">}
puts $fd {  <title>OpenClaw — Gateway Dashboard</title>}
puts $fd {  <link rel="stylesheet" href="gateway-styles.css">}
puts $fd {</head>}

# Body start
puts $fd {<body>}

# Header
puts $fd {  <header>}
puts $fd {    <h1>OpenClaw Cluster</h1>}
puts $fd {    <span id="cluster-status" class="badge">Checking...</span>}
puts $fd {  </header>}

# Main content
puts $fd {  <main>}

# Gateway grid section
puts $fd {    <section class="grid">}
puts $fd {      <div class="card" id="gw1">}
puts $fd {        <h2>Gateway 1</h2>}
puts $fd {        <p class="endpoint">gateway1.openclaw.internal</p>}
puts $fd {        <div class="status-dot"></div>}
puts $fd {      </div>}
puts $fd {      <div class="card" id="gw2">}
puts $fd {        <h2>Gateway 2</h2>}
puts $fd {        <p class="endpoint">gateway2.openclaw.internal</p>}
puts $fd {        <div class="status-dot"></div>}
puts $fd {      </div>}
puts $fd {    </section>}

# Metrics section
puts $fd {    <section class="metrics">}
puts $fd {      <h2>Node Metrics</h2>}
puts $fd {      <table>}
puts $fd {        <thead>}
puts $fd {          <tr><th>Node</th><th>Latency</th><th>Requests</th><th>Status</th></tr>}
puts $fd {        </thead>}
puts $fd {        <tbody id="metrics-body">}
puts $fd {          <tr><td colspan="4">Loading...</td></tr>}
puts $fd {        </tbody>}
puts $fd {      </table>}
puts $fd {    </section>}

puts $fd {  </main>}

# Script section
puts $fd {  <script>}
puts $fd {    const GATEWAY_URL = window.OPENCLAW_URL || "http://localhost:8080";}
puts $fd {}
puts $fd {    async function pollStatus() \{}
puts $fd {      try \{}
puts $fd {        const res = await fetch(\`\${GATEWAY_URL}/health\`);}
puts $fd {        const ok = res.ok;}
puts $fd {        document.getElementById("cluster-status").textContent = ok ? "Online" : "Degraded";}
puts $fd {        document.getElementById("cluster-status").className = \`badge \${ok ? "ok" : "warn"\}\`;}
puts $fd {        document.querySelectorAll(".status-dot").forEach(d => d.className = \`status-dot \${ok ? "green" : "red"\}\`);}
puts $fd {      \} catch \{}
puts $fd {        document.getElementById("cluster-status").textContent = "Offline";}
puts $fd {        document.getElementById("cluster-status").className = "badge error";}
puts $fd {      \}}
puts $fd {    \}}
puts $fd {}
puts $fd {    pollStatus();}
puts $fd {    setInterval(pollStatus, 5000);}
puts $fd {  </script>}

# Close body and html
puts $fd {</body>}
puts $fd {</html>}

# Close file
close $fd

# Output success message
puts "HTML dashboard written to $output_file"
