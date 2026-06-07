// OpenClaw TCP port probe (TypeScript / Node) — checks gateway nodes
import * as net from "node:net";

function probe(host: string, port: number, timeout = 3000): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    const done = (ok: boolean) => {
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeout);
    socket.once("connect", () => done(true));
    socket.once("timeout", () => done(false));
    socket.once("error", () => done(false));
    socket.connect(port, host);
  });
}

const nodes: [string, number][] = [["localhost", 8080], ["localhost", 8081]];

(async () => {
  for (const [host, port] of nodes) {
    const ok = await probe(host, port);
    console.log(`${ok ? "OK  " : "FAIL"} ${host}:${port}`);
  }
})();
