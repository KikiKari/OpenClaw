<?php
// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
$nodes = ['gateway1.openclaw.internal', 'gateway2.openclaw.internal'];

function getNode(array $nodes): string {
    return $nodes[array_rand($nodes)];
}

printf("OpenClaw routing to: %s\n", getNode($nodes));
