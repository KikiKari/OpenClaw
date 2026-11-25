<?php
// abstraction-provenance: {"artifact_sha256": "983ec6d688be7ed9bcdb0e6b7a957b83b76a487d27cae6269fa0580585749215", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "php"}
// translation-worker-node.sh — portiert nach php
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
// Run on the selected node after transferring its native worker. JSON stdin is
// forwarded unchanged to the worker in run mode.

if ($argc !== 3) {
    fwrite(STDERR, "Usage: translation-worker-node.php node2|node3|node4|node6 prepare|health|run\n");
    exit(2);
}

$node = $argv[1];
$action = $argv[2];

switch ($node) {
    case 'node2':
        $worker = '/home/node/.openclaw/workers/translation-worker';
        $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286';
        break;
    case 'node3':
        $worker = '/home/openclaw/.openclaw/workers/translation-worker';
        $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de';
        break;
    case 'node4':
        $worker = '/root/.openclaw/workers/translation-worker';
        $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286';
        break;
    case 'node6':
        $worker = '/home/node/.openclaw/workers/translation-worker';
        $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de';
        break;
    default:
        fwrite(STDERR, "Unknown or non-POSIX node\n");
        exit(2);
}

if (!in_array($action, ['prepare', 'health', 'run'])) {
    fwrite(STDERR, "Unknown action\n");
    exit(2);
}

if (!file_exists($worker) || is_link($worker)) {
    fwrite(STDERR, "Missing worker or symlink rejected: $worker\n");
    exit(1);
}

$actual = hash_file('sha256', $worker);
if ($actual !== $expected) {
    fwrite(STDERR, "Worker checksum mismatch: $worker\n");
    exit(1);
}

chmod($worker, 0755);

switch ($action) {
    case 'prepare':
        echo "Worker verified and executable: $worker\n";
        break;
    case 'health':
        passthru("$worker --health", $return_code);
        exit($return_code);
    case 'run':
        passthru($worker, $return_code);
        exit($return_code);
}
?>
