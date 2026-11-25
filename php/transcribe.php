<?php
// abstraction-provenance: {"artifact_sha256": "f33756b19dbf221635eb5cb7faa74b3be4d9a3d584e4324b7c3bba75927dc3d2", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "php"}
// transcribe.sh — portiert nach php
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
function usage() {
    fwrite(STDERR, <<<EOF
Usage:
  transcribe.php <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]

EOF
    );
    exit(2);
}

function main($argv) {
    global $argc;

    if (!isset($argv[1]) || $argv[1] === '-h' || $argv[1] === '--help') {
        usage();
    }

    $in = $argv[1];
    array_shift($argv);

    $model = 'whisper-1';
    $out = '';
    $language = '';
    $prompt = '';
    $response_format = 'text';

    while (count($argv) > 0) {
        $arg = array_shift($argv);
        switch ($arg) {
            case '--model':
                $model = array_shift($argv);
                break;
            case '--out':
                $out = array_shift($argv);
                break;
            case '--language':
                $language = array_shift($argv);
                break;
            case '--prompt':
                $prompt = array_shift($argv);
                break;
            case '--json':
                $response_format = 'json';
                break;
            default:
                fwrite(STDERR, "Unknown arg: $arg\n");
                usage();
        }
    }

    if (!file_exists($in)) {
        fwrite(STDERR, "File not found: $in\n");
        exit(1);
    }

    $openai_api_key = getenv('OPENAI_API_KEY');
    if ($openai_api_key === false) {
        fwrite(STDERR, "Missing OPENAI_API_KEY\n");
        exit(1);
    }

    if ($out === '') {
        $pathinfo = pathinfo($in);
        $base = $pathinfo['dirname'] . DIRECTORY_SEPARATOR . $pathinfo['filename'];
        if ($response_format === 'json') {
            $out = $base . '.json';
        } else {
            $out = $base . '.txt';
        }
    }

    $basedir = dirname($out);
    if (!is_dir($basedir)) {
        mkdir($basedir, 0777, true);
    }

    $api_base = getenv('OPENAI_BASE_URL') ?: 'https://api.openai.com/v1';
    $api_base = rtrim($api_base, '/');

    $url = "$api_base/audio/transcriptions";

    $post_fields = [
        'file' => new CURLFile($in),
        'model' => $model,
        'response_format' => $response_format,
    ];

    if ($language !== '') {
        $post_fields['language'] = $language;
    }

    if ($prompt !== '') {
        $post_fields['prompt'] = $prompt;
    }

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_fields);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer $openai_api_key",
        'Accept: application/json',
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $result = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($result === false) {
        fwrite(STDERR, "cURL error: $error\n");
        exit(1);
    }

    if ($http_code >= 400) {
        fwrite(STDERR, "HTTP error $http_code: $result\n");
        exit(1);
    }

    file_put_contents($out, $result);
    echo "$out\n";
}

main($argv);
