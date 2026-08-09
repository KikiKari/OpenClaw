import concurrent.futures
from .client import GatewayClient


class ClusterManager:
    """Manages a pool of OpenClaw gateway nodes."""

    def __init__(self, nodes: list[str]):
        self.nodes = [GatewayClient(n) for n in nodes]

    def health_check(self) -> list[dict]:
        def check(client: GatewayClient) -> dict:
            try:
                client.health()
                return {"url": client.url, "status": "ok"}
            except Exception as exc:
                return {"url": client.url, "status": "error", "error": str(exc)}

        with concurrent.futures.ThreadPoolExecutor() as ex:
            return list(ex.map(check, self.nodes))

    def broadcast(self, payload: dict) -> list[dict]:
        return [n.send(payload) for n in self.nodes]