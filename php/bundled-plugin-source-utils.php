<?php
// abstraction-provenance: {"artifact_sha256": "9352161e44561d69ba7ccd9f16ee0b3eec0f96250167f759c5559eb2e891ab06", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "php"}
// bundled-plugin-source-utils.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
function readIfExists($filePath) {
    try {
        if (file_exists($filePath)) {
            return file_get_contents($filePath);
        }
        return null;
    } catch (Exception $e) {
        return null;
    }
}

function collectBundledPluginSources($params = []) {
    $repoRoot = isset($params['repoRoot']) ? realpath($params['repoRoot']) : getcwd();
    $extensionsRoot = $repoRoot . DIRECTORY_SEPARATOR . 'extensions';
    
    if (!file_exists($extensionsRoot) || !is_dir($extensionsRoot)) {
        return [];
    }

    $requirePackageJson = isset($params['requirePackageJson']) && $params['requirePackageJson'] === true;
    $entries = [];
    
    $files = scandir($extensionsRoot);
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') {
            continue;
        }
        
        $pluginDir = $extensionsRoot . DIRECTORY_SEPARATOR . $file;
        if (!is_dir($pluginDir)) {
            continue;
        }

        $manifestPath = $pluginDir . DIRECTORY_SEPARATOR . 'openclaw.plugin.json';
        $packageJsonPath = $pluginDir . DIRECTORY_SEPARATOR . 'package.json';
        
        if (!file_exists($manifestPath)) {
            continue;
        }
        
        if ($requirePackageJson && !file_exists($packageJsonPath)) {
            continue;
        }

        $entry = [
            'dirName' => $file,
            'pluginDir' => $pluginDir,
            'manifestPath' => $manifestPath,
            'manifest' => json_decode(file_get_contents($manifestPath), true)
        ];
        
        if (file_exists($packageJsonPath)) {
            $entry['packageJsonPath'] = $packageJsonPath;
            $entry['packageJson'] = json_decode(file_get_contents($packageJsonPath), true);
        }
        
        $entries[] = $entry;
    }

    usort($entries, function($left, $right) {
        return strcmp($left['dirName'], $right['dirName']);
    });

    return $entries;
}

?>
