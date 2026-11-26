<?php
// abstraction-provenance: {"artifact_sha256": "046601fe61e51da1a0af1812c9d09140f62268e3f9f04db465a26d5b80b874fc", "source_sha256": "eed3bdbc8fef27830c5850ddac7a0ed91929c33fde29bd0fc4729b45b78fada0", "target_language": "php"}
// npm-runner.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/npm-runner.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
require_once __DIR__ . '/windows-cmd-helpers.php';

function resolveToolchainNpmRunner($params) {
    $npmCliCandidates = [
        $params['pathImpl']->resolve($params['nodeDir'], "../lib/node_modules/npm/bin/npm-cli.js"),
        $params['pathImpl']->resolve($params['nodeDir'], "node_modules/npm/bin/npm-cli.js"),
    ];
    
    $npmCliPath = null;
    foreach ($npmCliCandidates as $candidate) {
        if ($params['existsSync']($candidate)) {
            $npmCliPath = $candidate;
            break;
        }
    }
    
    if ($npmCliPath) {
        return [
            'command' => $params['platform'] === "win32"
                ? $params['pathImpl']->join($params['nodeDir'], "node.exe")
                : $params['pathImpl']->join($params['nodeDir'], "node"),
            'args' => array_merge([$npmCliPath], $params['npmArgs']),
            'shell' => false,
        ];
    }
    
    if ($params['platform'] !== "win32") {
        return null;
    }
    
    $npmExePath = $params['pathImpl']->resolve($params['nodeDir'], "npm.exe");
    if ($params['existsSync']($npmExePath)) {
        return [
            'command' => $npmExePath,
            'args' => $params['npmArgs'],
            'shell' => false,
        ];
    }
    
    $npmCmdPath = $params['pathImpl']->resolve($params['nodeDir'], "npm.cmd");
    if ($params['existsSync']($npmCmdPath)) {
        return [
            'command' => $params['comSpec'],
            'args' => ["/d", "/s", "/c", buildCmdExeCommandLine($npmCmdPath, $params['npmArgs'])],
            'shell' => false,
            'windowsVerbatimArguments' => true,
        ];
    }
    
    return null;
}

function resolveNpmRunner($params = []) {
    $execPath = isset($params['execPath']) ? $params['execPath'] : PHP_BINARY;
    $npmArgs = isset($params['npmArgs']) ? $params['npmArgs'] : [];
    $existsSync = isset($params['existsSync']) ? $params['existsSync'] : 'file_exists';
    $env = isset($params['env']) ? $params['env'] : $_ENV;
    $platform = isset($params['platform']) ? $params['platform'] : php_uname('s') === 'Windows NT' ? 'win32' : 'linux';
    $comSpec = isset($params['comSpec']) ? $params['comSpec'] : (isset($env['ComSpec']) ? $env['ComSpec'] : "cmd.exe");
    
    $pathImplClass = $platform === "win32" ? 'PathWin32' : 'PathPosix';
    $pathImpl = new $pathImplClass();
    
    $nodeDir = $pathImpl->dirname($execPath);
    
    $npmToolchainParams = [
        'comSpec' => $comSpec,
        'existsSync' => $existsSync,
        'nodeDir' => $nodeDir,
        'npmArgs' => $npmArgs,
        'pathImpl' => $pathImpl,
        'platform' => $platform,
    ];
    
    $npmToolchain = resolveToolchainNpmRunner($npmToolchainParams);
    
    if ($npmToolchain) {
        return $npmToolchain;
    }
    
    if ($platform === "win32") {
        $expectedPaths = [
            $pathImpl->resolve($nodeDir, "../lib/node_modules/npm/bin/npm-cli.js"),
            $pathImpl->resolve($nodeDir, "node_modules/npm/bin/npm-cli.js"),
            $pathImpl->resolve($nodeDir, "npm.exe"),
            $pathImpl->resolve($nodeDir, "npm.cmd"),
        ];
        throw new Exception(
            "failed to resolve a toolchain-local npm next to {$execPath}. " .
            "Checked: " . implode(", ", $expectedPaths) . ". " .
            "OpenClaw refuses to shell out to bare npm on Windows; install a Node.js toolchain that bundles npm or run with a matching Node installation."
        );
    }
    
    $pathKey = resolvePathEnvKey($env);
    $currentPath = isset($env[$pathKey]) ? $env[$pathKey] : '';
    
    return [
        'command' => "npm",
        'args' => $npmArgs,
        'shell' => false,
        'env' => array_merge($env, [
            $pathKey => is_string($currentPath) && strlen($currentPath) > 0
                ? "{$nodeDir}" . PATH_SEPARATOR . "{$currentPath}"
                : $nodeDir,
        ]),
    ];
}

class PathWin32 {
    public function resolve(...$paths) {
        return realpath(implode(DIRECTORY_SEPARATOR, $paths)) ?: implode(DIRECTORY_SEPARATOR, $paths);
    }
    
    public function join(...$paths) {
        return implode(DIRECTORY_SEPARATOR, $paths);
    }
    
    public function dirname($path) {
        return dirname($path);
    }
}

class PathPosix {
    public function resolve(...$paths) {
        return realpath(implode('/', $paths)) ?: implode('/', $paths);
    }
    
    public function join(...$paths) {
        return implode('/', $paths);
    }
    
    public function dirname($path) {
        return dirname($path);
    }
}
