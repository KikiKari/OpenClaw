# OpenClaw gateway router — upstream node selection (port of nginx-gateway)
nodes = ["gateway1.openclaw.internal", "gateway2.openclaw.internal"]
target = Enum.random(nodes)
IO.puts("OpenClaw routing to: #{target}")
