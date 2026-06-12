# OpenClaw Cluster Operations (Makefile)
GATEWAY_URL ?= http://localhost:8080
NODES ?= http://localhost:8080 http://localhost:8081

.PHONY: help health status deploy clean

help:
	@echo "OpenClaw cluster targets:"
	@echo "  make health  - check the gateway /health endpoint"
	@echo "  make status  - check every node in NODES"
	@echo "  make deploy  - trigger a cluster sync"

health:
	@curl -sf $(GATEWAY_URL)/health && echo " gateway OK" || echo "gateway DOWN"

status:
	@for node in $(NODES); do \
		code=$$(curl -s -o /dev/null -w "%{http_code}" $$node/health); \
		echo "$$node -> $$code"; \
	done

deploy:
	@curl -sf -X POST $(GATEWAY_URL)/api/sync && echo "sync triggered"

clean:
	@rm -f *.log
