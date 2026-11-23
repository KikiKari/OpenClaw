<?php
// abstraction-provenance: {"artifact_sha256": "9f151b22fa342e3e953bc00c4b76b8eaf1a31907724c8d2af8401208065247ed", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "php"}
// test-contextualized-embeddings.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py
declare(strict_types=1);

// Set strict error reporting
error_reporting(E_ALL);
ini_set('display_errors', '1');

// Check for required environment variable
$apiKey = getenv('PERPLEXITY_API_KEY');
if ($apiKey === false) {
    fwrite(STDERR, "PERPLEXITY_API_KEY is required\n");
    exit(1);
}

// Determine temporary directory and output file path
$tmpDir = sys_get_temp_dir();
$outFile = $tmpDir . DIRECTORY_SEPARATOR . 'perplexity-contextualized-embeddings-test.json';

// Prepare the JSON payload
$payload = json_encode([
    'input' => [
        [
            'OpenClaw can route web search through Perplexity.',
            'The Perplexity MCP server exposes search and reasoning tools.',
            'Contextualized embeddings improve document chunk retrieval.'
        ]
    ],
    'model' => 'pplx-embed-context-v1-4b'
], JSON_THROW_ON_ERROR);

// Initialize cURL
$ch = curl_init();

// Configure cURL options
curl_setopt_array($ch, [
    CURLOPT_URL => 'https://api.perplexity.ai/v1/contextualizedembeddings',
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => $payload,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HEADER => false,
    CURLOPT_HTTPHEADER => [
        'Authorization: Bearer ' . $apiKey,
        'Content-Type: application/json'
    ],
    CURLOPT_TIMEOUT => 30
]);

// Execute request and get response
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

if (curl_errno($ch)) {
    fwrite(STDERR, 'cURL error: ' . curl_error($ch) . "\n");
    curl_close($ch);
    exit(1);
}

curl_close($ch);

// Save response to file
file_put_contents($outFile, $response);

// Output HTTP status code
echo "contextualized_embeddings_http={$httpCode}\n";

// Process and output structured data from JSON response
$data = json_decode($response, true, 512, JSON_THROW_ON_ERROR);

$output = [
    'keys' => array_keys($data),
    'model' => $data['model'] ?? null,
    'document_count' => isset($data['data']) ? count($data['data']) : 0,
    'first_chunk_count' => (isset($data['data'][0]['data']) && is_array($data['data'][0]['data'])) 
        ? count($data['data'][0]['data']) 
        : 0,
    'error' => $data['error'] ?? null
];

echo json_encode($output, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
