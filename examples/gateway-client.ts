// OpenClaw Gateway API Client (TypeScript)
declare const process: { env: Record<string, string | undefined> };

const GATEWAY_URL: string = process.env.OPENCLAW_GATEWAY_URL ?? "http://localhost:8080";

interface HealthResponse {
  status: string;
  uptime: number;
}

interface AgentPayload {
  task: string;
  [key: string]: unknown;
}

async function checkGateway(endpoint: string = "/health"): Promise<HealthResponse> {
  const res = await fetch(`${GATEWAY_URL}${endpoint}`);
  if (!res.ok) throw new Error(`Gateway error: ${res.status}`);
  return (await res.json()) as HealthResponse;
}

async function sendToGateway(
  payload: AgentPayload,
  endpoint: string = "/api/agent",
): Promise<unknown> {
  const res = await fetch(`${GATEWAY_URL}${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return res.json();
}

export { checkGateway, sendToGateway, type HealthResponse, type AgentPayload };
