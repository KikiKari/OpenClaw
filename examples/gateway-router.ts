// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
const nodes: string[] = [
  "gateway1.openclaw.internal",
  "gateway2.openclaw.internal",
];

function getNode(): string {
  return nodes[Math.floor(Math.random() * nodes.length)];
}

const target = getNode();
console.log(`OpenClaw routing to: ${target}`);
