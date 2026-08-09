<?php
// OpenClaw TCP port probe (PHP) — checks gateway nodes
function probe(string $host, int $port, float $timeout = 3.0): bool {
    $fp = @fsockopen($host, $port, $errno, $errstr, $timeout);
    if ($fp) {
        fclose($fp);
        return true;
    }
    return false;
}

$nodes = [['localhost', 8080], ['localhost', 8081]];
foreach ($nodes as [$host, $port]) {
    printf("%s %s:%d\n", probe($host, $port) ? 'OK  ' : 'FAIL', $host, $port);
}
