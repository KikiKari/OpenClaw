<?php
// abstraction-provenance: {"artifact_sha256": "6712124de9f4c87e3623778ba2fc41d02cbaeea003a60197b160996e8aee6e6d", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "php"}
// test-embeddings.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py
$PERPLEXITY_API_KEY = getenv('PERPLEXITY_API_KEY');
if ($PERPLEXITY_API_KEY === false) {
    fwrite(STDERR, "PERPLEXITY_API_KEY is required\n");
    exit(1);
}

$out = sys_get_temp_dir() . '/perplexity-embeddings-test.json';

$payload = json_encode([
    'input' => [
        'Scientists explore the universe driven by curiosity.',
        'Curiosity compels us to seek explanations, not just observations.',
        'Historical discoveries began with curious questions.',
        'The pursuit of knowledge distinguishes human curiosity from mere stimulus response.',
        'Philosophy examines the nature of curiosity.'
    ],
    'model' => 'pplx-embed-v1-4b'
]);

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://api.perplexity.ai/v1/embeddings');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $PERPLEXITY_API_KEY,
    'Content-Type: application/json'
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HEADER, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
curl_close($ch);

$body = substr($response, $headerSize);
file_put_contents($out, $body);

echo "embeddings_http={$httpCode}\n";

$data = json_decode($body, true);
$result = [
    'keys' => array_keys($data),
    'model' => $data['model'] ?? null,
    'item_count' => count($data['data'] ?? []),
    'first_dim' => count(($data['data'][0]['embedding'] ?? [])),
    'error' => $data['error'] ?? null
];

echo json_encode($result, JSON_PRETTY_PRINT) . "\n";
