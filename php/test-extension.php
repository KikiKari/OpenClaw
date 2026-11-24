<?php
// abstraction-provenance: {"artifact_sha256": "3e0a58185f3f6db70088eed132f95768e53178cd0ae9c2b3e570055cab015bbd", "source_sha256": "0f2bb155d699e769ad3eb99a6500cc6dbb27948a57f7493a3b98c731200853d4", "target_language": "php"}
// test-extension.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/test-extension.mjs
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py
require_once __DIR__ . "/lib/error-format.php";
require_once __DIR__ . "/lib/extension-test-plan.php";
require_once __DIR__ . "/lib/vitest-batch-runner.php";

function printUsage() {
    fwrite(STDERR, "Usage: pnpm test:extension <extension-name|path> [vitest args...]\n");
    fwrite(STDERR, "       php scripts/test-extension.php [extension-name|path] [vitest args...]\n");
}

function printNoTestsMessage($plan) {
    echo "[test-extension] No tests found for " . $plan["extensionDir"] . ". Skipping.\n";
}

function run() {
    global $argv;
    
    $rawArgs = array_slice($argv, 1);
    
    if (in_array("--help", $rawArgs) || in_array("-h", $rawArgs)) {
        printUsage();
        return;
    }
    
    $passthroughArgs = array_filter($rawArgs, function($arg) {
        return $arg !== "--";
    });
    
    $targetArg = null;
    if (!empty($passthroughArgs) && !str_starts_with($passthroughArgs[0], "-")) {
        $targetArg = array_shift($passthroughArgs);
    }
    
    try {
        $plan = resolveExtensionTestPlan(["cwd" => getcwd(), "targetArg" => $targetArg]);
    } catch (Exception $error) {
        printUsage();
        fwrite(STDERR, formatErrorMessage($error) . "\n");
        exit(1);
    }
    
    if (!$plan["hasTests"]) {
        printNoTestsMessage($plan);
        return;
    }
    
    echo "[test-extension] Running " . $plan["testFileCount"] . " test files for " . $plan["extensionId"] . "\n";
    
    $exitCode = runVitestBatch([
        "args" => $passthroughArgs,
        "config" => $plan["config"],
        "env" => $_ENV,
        "targets" => $plan["roots"]
    ]);
    
    exit($exitCode);
}

if (basename(__FILE__) === basename($_SERVER["SCRIPT_NAME"])) {
    run();
}
?>
