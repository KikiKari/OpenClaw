<?php
// abstraction-provenance: {"artifact_sha256": "67786b00c288235f5cd6ba7582dcaff9686851b22f981162ae6ee650c64a28b2", "source_sha256": "8efc75d62670dadcb8e085c754c26b48d241d96c51ae4f1c6742a4e894282492", "target_language": "php"}
// notarize-mac-artifact.sh — portiert nach php
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/notarize-mac-artifact.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Notarize a macOS artifact (zip/dmg/pkg) and optionally staple the app bundle.
 *
 * Usage:
 *   STAPLE_APP_PATH=dist/OpenClaw.app php notarize-mac-artifact.php <artifact>
 *
 * Auth (pick one):
 *   NOTARYTOOL_PROFILE   keychain profile created via `xcrun notarytool store-credentials`
 *   NOTARYTOOL_KEY       path to App Store Connect API key (.p8)
 *   NOTARYTOOL_KEY_ID    API key ID
 *   NOTARYTOOL_ISSUER    API issuer ID
 */

function main() {
    global $argv;

    // Get artifact from command line argument
    $artifact = $argv[1] ?? '';
    $stapleAppPath = getenv('STAPLE_APP_PATH') ?: '';

    if (empty($artifact)) {
        fwrite(STDERR, "Usage: php " . basename($argv[0]) . " <artifact>\n");
        exit(1);
    }

    if (!file_exists($artifact)) {
        fwrite(STDERR, "Error: artifact not found: $artifact\n");
        exit(1);
    }

    // Check if xcrun is available
    if (!commandExists('xcrun')) {
        fwrite(STDERR, "Error: xcrun not found; install Xcode command line tools.\n");
        exit(1);
    }

    // Build authentication arguments
    $authArgs = [];
    $notaryToolProfile = getenv('NOTARYTOOL_PROFILE');
    $notaryToolKey = getenv('NOTARYTOOL_KEY');
    $notaryToolKeyId = getenv('NOTARYTOOL_KEY_ID');
    $notaryToolIssuer = getenv('NOTARYTOOL_ISSUER');

    if (!empty($notaryToolProfile)) {
        $authArgs = ['--keychain-profile', $notaryToolProfile];
    } elseif (!empty($notaryToolKey) && !empty($notaryToolKeyId) && !empty($notaryToolIssuer)) {
        $authArgs = [
            '--key', $notaryToolKey,
            '--key-id', $notaryToolKeyId,
            '--issuer', $notaryToolIssuer
        ];
    } else {
        fwrite(STDERR, "Error: Notary auth missing. Set NOTARYTOOL_PROFILE or NOTARYTOOL_KEY/NOTARYTOOL_KEY_ID/NOTARYTOOL_ISSUER.\n");
        exit(1);
    }

    // Submit for notarization
    echo "🧾 Notarizing: $artifact\n";
    $cmd = array_merge(
        ['xcrun', 'notarytool', 'submit', $artifact],
        $authArgs,
        ['--wait']
    );
    
    $result = runCommand($cmd);
    if ($result !== 0) {
        exit($result);
    }

    // Staple artifact if it's dmg or pkg
    if (preg_match('/\.(dmg|pkg)$/', $artifact)) {
        echo "📌 Stapling artifact: $artifact\n";
        
        $stapleCmd = ['xcrun', 'stapler', 'staple', $artifact];
        $validateCmd = ['xcrun', 'stapler', 'validate', $artifact];
        
        $result = runCommand($stapleCmd);
        if ($result !== 0) {
            exit($result);
        }
        
        $result = runCommand($validateCmd);
        if ($result !== 0) {
            exit($result);
        }
    }

    // Staple app bundle if specified
    if (!empty($stapleAppPath)) {
        if (is_dir($stapleAppPath)) {
            echo "📌 Stapling app: $stapleAppPath\n";
            
            $stapleCmd = ['xcrun', 'stapler', 'staple', $stapleAppPath];
            $validateCmd = ['xcrun', 'stapler', 'validate', $stapleAppPath];
            
            $result = runCommand($stapleCmd);
            if ($result !== 0) {
                exit($result);
            }
            
            $result = runCommand($validateCmd);
            if ($result !== 0) {
                exit($result);
            }
        } else {
            fwrite(STDERR, "Warn: STAPLE_APP_PATH not found: $stapleAppPath\n");
        }
    }

    echo "✅ Notarization complete\n";
}

/**
 * Check if a command exists
 */
function commandExists($command) {
    $which = strtoupper(substr(PHP_OS, 0, 3)) === 'WIN' ? 'where' : 'which';
    exec("$which $command", $output, $returnVar);
    return $returnVar === 0;
}

/**
 * Run a command and return its exit code
 */
function runCommand($commandArray) {
    $command = implode(' ', array_map('escapeshellarg', $commandArray));
    passthru($command, $returnCode);
    return $returnCode;
}

main();
