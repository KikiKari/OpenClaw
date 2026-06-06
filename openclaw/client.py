import urllib.request
import json


class GatewayClient:
    """HTTP client for a single OpenClaw gateway node."""

    def __init__(self, url: str, timeout: int = 5):
        self.url = url.rstrip("/")
        self.timeout = timeout

    def health(self) -> dict:
        with urllib.request.urlopen(f"{self.url}/health", timeout=self.timeout) as r:
            return json.loads(r.read())

    def send(self, payload: dict, endpoint: str = "/api/agent") -> dict:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(
            f"{self.url}{endpoint}",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=self.timeout) as r:
            return json.loads(r.read())