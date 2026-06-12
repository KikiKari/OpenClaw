// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
def nodes = ['gateway1.openclaw.internal', 'gateway2.openclaw.internal']
def target = nodes[new Random().nextInt(nodes.size())]
println "OpenClaw routing to: ${target}"
