#!/usr/bin/env python3
# gateway-dashboard.html — portiert nach python
# Quelle: html, OpenClaw@main:examples/gateway-dashboard.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import sys
import json
from html import escape
from urllib.request import urlopen, Request
from urllib.error import URLError

def generate_html(cluster_status="Checking...", gateways=None, metrics=None):
    if gateways is None:
        gateways = [
            {"id": "gw1", "name": "Gateway 1", "endpoint": "gateway1.openclaw.internal"},
            {"id": "gw2", "name": "Gateway 2", "endpoint": "gateway2.openclaw.internal"}
        ]
    
    if metrics is None:
        metrics = [{"node": "Loading...", "latency": "", "requests": "", "status": ""}]
    
    html_parts = [
        '<!DOCTYPE html>',
        '<html lang="en">',
        '<head>',
        '  <meta charset="UTF-8">',
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
        '  <title>OpenClaw — Gateway Dashboard</title>',
        '  <link rel="stylesheet" href="gateway-styles.css">',
        '</head>',
        '<body>',
        '  <header>',
        '    <h1>OpenClaw Cluster</h1>',
        f'    <span id="cluster-status" class="badge">{escape(cluster_status)}</span>',
        '  </header>',
        '',
        '  <main>',
        '    <section class="grid">'
    ]
    
    for gw in gateways:
        html_parts.extend([
            f'      <div class="card" id="{escape(gw["id"])}">',
            f'        <h2>{escape(gw["name"])}</h2>',
            f'        <p class="endpoint">{escape(gw["endpoint"])}</p>',
            '        <div class="status-dot"></div>',
            '      </div>'
        ])
    
    html_parts.extend([
        '    </section>',
        '',
        '    <section class="metrics">',
        '      <h2>Node Metrics</h2>',
        '      <table>',
        '        <thead>',
        '          <tr><th>Node</th><th>Latency</th><th>Requests</th><th>Status</th></tr>',
        '        </thead>',
        '        <tbody id="metrics-body">'
    ])
    
    for metric in metrics:
        html_parts.append(
            f'          <tr><td>{escape(str(metric["node"]))}</td><td>{escape(str(metric["latency"]))}</td>'
            f'<td>{escape(str(metric["requests"]))}</td><td>{escape(str(metric["status"]))}</td></tr>'
        )
    
    html_parts.extend([
        '        </tbody>',
        '      </table>',
        '    </section>',
        '  </main>',
        '',
        '  <script>',
        '    const GATEWAY_URL = window.OPENCLAW_URL || "http://localhost:8080";',
        '',
        '    async function pollStatus() {',
        '      try {',
        '        const res = await fetch(`${GATEWAY_URL}/health`);',
        '        const ok = res.ok;',
        '        document.getElementById("cluster-status").textContent = ok ? "Online" : "Degraded";',
        '        document.getElementById("cluster-status").className = `badge ${ok ? "ok" : "warn"}`;',
        '        document.querySelectorAll(".status-dot").forEach(d => d.className = `status-dot ${ok ? "green" : "red"}`);',
        '      } catch {',
        '        document.getElementById("cluster-status").textContent = "Offline";',
        '        document.getElementById("cluster-status").className = "badge error";',
        '      }',
        '    }',
        '',
        '    pollStatus();',
        '    setInterval(pollStatus, 5000);',
        '  </script>',
        '</body>',
        '</html>'
    ])
    
    return '\n'.join(html_parts)

def check_cluster_status(gateway_url):
    try:
        req = Request(f"{gateway_url}/health", method='GET')
        response = urlopen(req)
        return "Online" if response.status == 200 else "Degraded"
    except URLError:
        return "Offline"

def main():
    output_file = sys.argv[1] if len(sys.argv) > 1 else "gateway-dashboard.html"
    gateway_url = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8080"
    
    cluster_status = check_cluster_status(gateway_url)
    html_content = generate_html(cluster_status)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"Dashboard written to {output_file}")

if __name__ == "__main__":
    main()
