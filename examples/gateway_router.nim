import std/random

# OpenClaw gateway router — upstream node selection (port of nginx-gateway)
let nodes = ["gateway1.openclaw.internal", "gateway2.openclaw.internal"]

randomize()
let target = sample(nodes)
echo "OpenClaw routing to: ", target
