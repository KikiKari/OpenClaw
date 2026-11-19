#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "133f5ab3cd82eeed37cae34fd444f62c7282bf05ca87b2c0d04329dda61f8d88", "source_sha256": "ed59efd19fa280b88488d50ce98f4213a84c5f833eacd98c7cb448f570c805fe", "target_language": "ruby"}
# node-monitor.html — portiert nach ruby
# Quelle: html, OpenClaw@main:examples/node-monitor.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Generates an HTML file for the OpenClaw Live Node Monitor
class NodeMonitorGenerator
  def initialize(output_file)
    @output_file = output_file
  end

  def generate
    File.open(@output_file, 'w') do |file|
      file.puts '<!DOCTYPE html>'
      file.puts '<html lang="en">'
      generate_head(file)
      generate_body(file)
      file.puts '</html>'
    end
  end

  private

  def generate_head(file)
    file.puts '<head>'
    file.puts '  <meta charset="UTF-8">'
    file.puts '  <meta name="viewport" content="width=device-width, initial-scale=1.0">'
    file.puts '  <title>OpenClaw — Live Node Monitor</title>'
    generate_styles(file)
    file.puts '</head>'
  end

  def generate_styles(file)
    file.puts '  <style>'
    file.puts '    :root { --bg: #0d1117; --surface: #161b22; --border: #30363d;'
    file.puts '            --text: #e6edf3; --green: #3fb950; --red: #f85149; --accent: #58a6ff; }'
    file.puts '    * { box-sizing: border-box; margin: 0; padding: 0; }'
    file.puts '    body { background: var(--bg); color: var(--text);'
    file.puts '           font-family: -apple-system, sans-serif; padding: 1.5rem; }'
    file.puts '    h1   { color: var(--accent); margin-bottom: 1rem; font-size: 1.2rem; }'
    file.puts '    canvas { display: block; border: 1px solid var(--border);'
    file.puts '             border-radius: 8px; background: var(--surface); }'
    file.puts '    #log { margin-top: 1rem; height: 140px; overflow-y: auto;'
    file.puts '           background: var(--surface); border: 1px solid var(--border);'
    file.puts '           border-radius: 8px; padding: .75rem; font-size: .78rem;'
    file.puts '           font-family: monospace; color: #8b949e; }'
    file.puts '    #log .err { color: var(--red); }'
    file.puts '    #log .ok  { color: var(--green); }'
    file.puts '  </style>'
  end

  def generate_body(file)
    file.puts '<body>'
    file.puts '  <h1>OpenClaw — Live Node Monitor</h1>'
    file.puts '  <canvas id="canvas" width="640" height="220"></canvas>'
    file.puts '  <div id="log"></div>'
    generate_script(file)
    file.puts '</body>'
  end

  def generate_script(file)
    file.puts '  <script>'
    file.puts '    /* HTML5 Canvas — animated node topology */'
    file.puts '    const canvas = document.getElementById("canvas");'
    file.puts '    const ctx    = canvas.getContext("2d");'
    file.puts '    const log    = document.getElementById("log");'
    file.puts '    const GATEWAY_URL = window.OPENCLAW_WS || "ws://localhost:8080/ws";'
    file.puts ''
    file.puts '    const nodes = ['
    file.puts '      { id: "GW1", x: 160, y: 110, status: "unknown" },'
    file.puts '      { id: "GW2", x: 480, y: 110, status: "unknown" },'
    file.puts '      { id: "HUB", x: 320, y:  55, status: "ok"      },'
    file.puts '    ];'
    file.puts '    const edges = [[0,2],[1,2]];' 
    file.puts ''
    file.puts '    let pulse = 0;'
    file.puts ''
    file.puts '    function drawNode(n) {'
    file.puts '      const color = n.status === "ok" ? "#3fb950" : n.status === "error" ? "#f85149" : "#8b949e";'
    file.puts '      ctx.beginPath();'
    file.puts '      ctx.arc(n.x, n.y, 22 + (n.status === "ok" ? Math.sin(pulse) * 3 : 0), 0, Math.PI * 2);'
    file.puts '      ctx.strokeStyle = color;'
    file.puts '      ctx.lineWidth = 2;'
    file.puts '      ctx.stroke();'
    file.puts '      ctx.fillStyle = "#161b22";'
    file.puts '      ctx.fill();'
    file.puts '      ctx.fillStyle = color;'
    file.puts '      ctx.font = "bold 11px monospace";'
    file.puts '      ctx.textAlign = "center";'
    file.puts '      ctx.textBaseline = "middle";'
    file.puts '      ctx.fillText(n.id, n.x, n.y);'
    file.puts '    }'
    file.puts ''
    file.puts '    function drawEdge(a, b, active) {'
    file.puts '      ctx.beginPath();'
    file.puts '      ctx.moveTo(nodes[a].x, nodes[a].y);'
    file.puts '      ctx.lineTo(nodes[b].x, nodes[b].y);'
    file.puts '      ctx.strokeStyle = active ? "#3fb95066" : "#30363d";'
    file.puts '      ctx.lineWidth = active ? 2 : 1;'
    file.puts '      ctx.setLineDash(active ? [] : [4, 4]);'
    file.puts '      ctx.stroke();'
    file.puts '      ctx.setLineDash([]);'
    file.puts '    }'
    file.puts ''
    file.puts '    function render() {'
    file.puts '      ctx.clearRect(0, 0, canvas.width, canvas.height);'
    file.puts '      edges.forEach(([a, b]) => drawEdge(a, b, nodes[a].status === "ok" && nodes[b].status === "ok"));'
    file.puts '      nodes.forEach(drawNode);'
    file.puts '      pulse += 0.07;'
    file.puts '      requestAnimationFrame(render);'
    file.puts '    }'
    file.puts '    render();'
    file.puts ''
    file.puts '    function addLog(msg, type = "") {'
    file.puts '      const el = document.createElement("div");'
    file.puts '      el.className = type;'
    file.puts '      el.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;'
    file.puts '      log.prepend(el);'
    file.puts '      if (log.children.length > 60) log.lastChild.remove();'
    file.puts '    }'
    file.puts ''
    file.puts '    /* HTML5 WebSocket — real-time gateway events */'
    file.puts '    function connectWS() {'
    file.puts '      const ws = new WebSocket(GATEWAY_URL);'
    file.puts '      ws.onopen  = () => { addLog("WebSocket connected", "ok"); nodes[2].status = "ok"; };'
    file.puts '      ws.onclose = () => { addLog("WebSocket closed — retrying in 3s", "err");'
    file.puts '                           nodes.forEach(n => n.status = "error");'
    file.puts '                           setTimeout(connectWS, 3000); };'
    file.puts '      ws.onerror = () => addLog("WebSocket error", "err");'
    file.puts '      ws.onmessage = ({ data }) => {'
    file.puts '        try {'
    file.puts '          const { node, status, latency } = JSON.parse(data);'
    file.puts '          const n = nodes.find(n => n.id === node);'
    file.puts '          if (n) n.status = status;'
    file.puts '          addLog(`${node} — ${status} (${latency}ms)`, status === "ok" ? "ok" : "err");'
    file.puts '        } catch { addLog(data); }'
    file.puts '      };'
    file.puts '    }'
    file.puts ''
    file.puts '    /* HTML5 Server-Sent Events — fallback */'
    file.puts '    function connectSSE() {'
    file.puts '      const es = new EventSource(GATEWAY_URL.replace("ws","http").replace("/ws","/events"));'
    file.puts '      es.onmessage = ({ data }) => addLog(`SSE: ${data}`, "ok");'
    file.puts '      es.onerror   = () => addLog("SSE stream error", "err");'
    file.puts '    }'
    file.puts ''
    file.puts '    /* HTML5 localStorage — persist last known state */'
    file.puts '    window.addEventListener("beforeunload", () =>'
    file.puts '      localStorage.setItem("openclaw-nodes", JSON.stringify(nodes)));'
    file.puts '    const saved = localStorage.getItem("openclaw-nodes");'
    file.puts '    if (saved) JSON.parse(saved).forEach((s, i) => nodes[i].status = s.status);'
    file.puts ''
    file.puts '    "WebSocket" in window ? connectWS() : connectSSE();'
    file.puts '  </script>'
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output-file>"
    exit 1
  end

  generator = NodeMonitorGenerator.new(ARGV[0])
  generator.generate
  puts "Generated node monitor HTML to #{ARGV[0]}"
end
