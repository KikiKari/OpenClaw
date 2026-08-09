<?php
// OpenClaw Gateway Client (PHP)

function checkGateway(string $baseUrl, string $endpoint = '/health'): int
{
    $ch = curl_init($baseUrl . $endpoint);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_NOBODY => true,
        CURLOPT_TIMEOUT => 5,
    ]);
    curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    return $status;
}

$url = $argv[1] ?? 'http://localhost:8080';
printf("Gateway %s -> HTTP %d\n", $url, checkGateway($url));
