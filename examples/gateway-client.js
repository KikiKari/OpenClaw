// OpenClaw Gateway API Client
const GATEWAY_URL = process.env.OPENCLAW_GATEWAY_URL || "http://localhost:8080";

async function checkGateway(endpoint = "/health") {
  const res = await fetch(`${GATEWAY_URL}${endpoint}`);
  if (!res.ok) throw new Error(`Gateway error: ${res.status}`);
  return res.json();
}

async function sendToGateway(payload, endpoint = "/api/agent") {
  const res = await fetch(`${GATEWAY_URL}${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return res.json();
}

module.exports = { checkGateway, sendToGateway };