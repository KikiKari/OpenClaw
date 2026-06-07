// OpenClaw log analyzer (TypeScript) — parses gateway access logs from stdin
import * as readline from "node:readline";

const counts: Record<string, number> = { INFO: 0, WARN: 0, ERROR: 0 };
const rl = readline.createInterface({ input: process.stdin });

rl.on("line", (line: string) => {
  const m = line.match(/^(\S+)\s+(INFO|WARN|ERROR)\s+(\S+)\s+(.+)$/);
  if (!m) return;
  const [, ts, level, node, msg] = m;
  counts[level]++;
  if (level === "ERROR") console.log(`⚠ ${ts} [${node}] ${msg}`);
});

rl.on("close", () => {
  console.log("\n--- Summary ---");
  for (const level of Object.keys(counts).sort()) {
    console.log(`${level}: ${counts[level]}`);
  }
});
