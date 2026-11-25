<?php
// abstraction-provenance: {"artifact_sha256": "19d34a9b7c85f95659fcf332cf50c3207cf7e7fa88ef608ecd681dab55112c13", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "php"}
// test_node3.sh — portiert nach php
// Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
// auch in: OpenClaw@gateway2:scripts/test_node3.sh
// auch in: workspace@local:scripts/test_node3.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
// Test Node 3 Connection

// Set environment variable
putenv('OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1');

echo "Starting node connection test...\n";

// Execute the command with timeout
$command = '/usr/local/bin/openclaw node run --host 152.53.145.65 --port 18789';
$descriptorspec = array(
   0 => array("pipe", "r"),
   1 => array("pipe", "w"),
   2 => array("pipe", "w")
);

$process = proc_open("timeout 15 " . $command, $descriptorspec, $pipes);

if (is_resource($process)) {
    // Close stdin
    fclose($pipes[0]);
    
    // Read stdout and stderr
    $output = stream_get_contents($pipes[1]);
    $errors = stream_get_contents($pipes[2]);
    
    // Close pipes
    fclose($pipes[1]);
    fclose($pipes[2]);
    
    // Get exit code
    $exitCode = proc_close($process);
    
    // Output the results
    echo $output;
    echo $errors;
    echo "Exit code: " . $exitCode . "\n";
} else {
    echo "Failed to execute command\n";
    echo "Exit code: 1\n";
}
?>
