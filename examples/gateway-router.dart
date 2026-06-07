import 'dart:math';

// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
const nodes = ['gateway1.openclaw.internal', 'gateway2.openclaw.internal'];

String getNode() => nodes[Random().nextInt(nodes.length)];

void main() {
  print('OpenClaw routing to: ${getNode()}');
}
