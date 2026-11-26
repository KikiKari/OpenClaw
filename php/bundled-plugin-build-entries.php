<?php
// abstraction-provenance: {"artifact_sha256": "06a98a1a52259dc7b0c1fd3b37ed6fe0b2f1a68d66bd58645729034298ea9ba7", "source_sha256": "ddf85df3b9350046010bc7449b7c05ad91c9c7d97ce98d75578f16ec7e33cef1", "target_language": "php"}
// bundled-plugin-build-entries.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-build-entries.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
require_once __DIR__ . '/bundled-plugin-paths.php';
require_once __DIR__ . '/optional-bundled-clusters.php';

const TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS = [".ts", ".js", ".mts", ".cts", ".mjs", ".cjs"];
const NON_PACKAGED_BUNDLED_PLUGIN_DIRS = ["qa-channel", "qa-lab"];

function toPosixPath($value) {
    return str_replace("\\", "/", $value);
}

function readBundledPluginPackageJson($packageJsonPath) {
    if (!file_exists($packageJsonPath)) {
        return null;
    }
    try {
        $content = file_get_contents($packageJsonPath);
        return json_decode($content, true);
    } catch (Exception $e) {
        return null;
    }
}

function isManifestlessBundledRuntimeSupportPackage($params) {
    $packageName = is_array($params['packageJson']) && isset($params['packageJson']['name']) && is_string($params['packageJson']['name']) 
        ? $params['packageJson']['name'] 
        : "";
    
    if ($packageName !== "@openclaw/{$params['dirName']}") {
        return false;
    }
    
    return count($params['topLevelPublicSurfaceEntries']) > 0;
}

function collectPluginSourceEntries($packageJson) {
    $packageEntries = [];
    if (isset($packageJson['openclaw']['extensions']) && is_array($packageJson['openclaw']['extensions'])) {
        foreach ($packageJson['openclaw']['extensions'] as $entry) {
            if (is_string($entry) && trim($entry) !== "") {
                $packageEntries[] = $entry;
            }
        }
    }
    
    $setupEntry = null;
    if (isset($packageJson['openclaw']['setupEntry']) && is_string($packageJson['openclaw']['setupEntry']) && trim($packageJson['openclaw']['setupEntry']) !== "") {
        $setupEntry = $packageJson['openclaw']['setupEntry'];
    }
    
    if ($setupEntry !== null) {
        $packageEntries = array_unique(array_merge($packageEntries, [$setupEntry]));
    }
    
    return count($packageEntries) > 0 ? $packageEntries : ["./index.ts"];
}

function shouldStageBundledPluginRuntimeDependencies($packageJson) {
    return isset($packageJson['openclaw']['bundle']['stageRuntimeDependencies']) && 
           $packageJson['openclaw']['bundle']['stageRuntimeDependencies'] === true;
}

function collectTopLevelPublicSurfaceEntries($pluginDir) {
    if (!file_exists($pluginDir)) {
        return [];
    }

    $entries = [];
    $files = scandir($pluginDir);
    
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') {
            continue;
        }
        
        $filePath = $pluginDir . '/' . $file;
        if (!is_file($filePath)) {
            continue;
        }
        
        $ext = pathinfo($file, PATHINFO_EXTENSION);
        $ext = $ext !== '' ? '.' . $ext : '';
        
        if (!in_array($ext, TOP_LEVEL_PUBLIC_SURFACE_EXTENSIONS)) {
            continue;
        }
        
        $normalizedName = strtolower($file);
        if (str_ends_with($normalizedName, ".d.ts") ||
            preg_match('/^config-api\.(?:[cm]?[jt]s)$/u', $normalizedName) ||
            str_contains($normalizedName, ".test.") ||
            str_contains($normalizedName, ".spec.") ||
            str_contains($normalizedName, ".fixture.") ||
            str_contains($normalizedName, ".snap")) {
            continue;
        }
        
        $entries[] = "./{$file}";
    }
    
    usort($entries, function($a, $b) {
        return strcmp($a, $b);
    });
    
    return $entries;
}

function collectBundledPluginBuildEntries($params = []) {
    $cwd = isset($params['cwd']) ? $params['cwd'] : getcwd();
    $env = isset($params['env']) ? $params['env'] : $_ENV;
    $extensionsRoot = $cwd . '/' . BUNDLED_PLUGIN_ROOT_DIR;
    $entries = [];
    
    $items = scandir($extensionsRoot);
    foreach ($items as $item) {
        if ($item === '.' || $item === '..') {
            continue;
        }
        
        $pluginDir = $extensionsRoot . '/' . $item;
        if (!is_dir($pluginDir)) {
            continue;
        }
        
        $manifestPath = $pluginDir . '/openclaw.plugin.json';
        $hasManifest = file_exists($manifestPath);
        $packageJsonPath = $pluginDir . '/package.json';
        $packageJson = readBundledPluginPackageJson($packageJsonPath);
        $topLevelPublicSurfaceEntries = collectTopLevelPublicSurfaceEntries($pluginDir);
        
        if (!$hasManifest && !isManifestlessBundledRuntimeSupportPackage([
            'dirName' => $item,
            'packageJson' => $packageJson,
            'topLevelPublicSurfaceEntries' => $topLevelPublicSurfaceEntries
        ])) {
            continue;
        }
        
        if (!shouldBuildBundledCluster($item, $env, ['packageJson' => $packageJson])) {
            continue;
        }
        
        $sourceEntries = [];
        if ($hasManifest) {
            $sourceEntries = collectPluginSourceEntries($packageJson);
        }
        $sourceEntries = array_merge($sourceEntries, $topLevelPublicSurfaceEntries);
        $sourceEntries = array_unique($sourceEntries);
        
        $entries[] = [
            'id' => $item,
            'hasManifest' => $hasManifest,
            'hasPackageJson' => $packageJson !== null,
            'packageJson' => $packageJson,
            'sourceEntries' => $sourceEntries
        ];
    }
    
    return $entries;
}

function listBundledPluginBuildEntries($params = []) {
    $entries = collectBundledPluginBuildEntries($params);
    $result = [];
    
    foreach ($entries as $entry) {
        foreach ($entry['sourceEntries'] as $sourceEntry) {
            $normalizedEntry = preg_replace('/^\.\//', '', $sourceEntry);
            $baseName = preg_replace('/\.[^.]+$/', '', $normalizedEntry);
            $entryKey = bundledPluginFile($entry['id'], $baseName);
            $result[$entryKey] = toPosixPath(BUNDLED_PLUGIN_ROOT_DIR . '/' . $entry['id'] . '/' . $normalizedEntry);
        }
    }
    
    return $result;
}

function listBundledPluginPackArtifacts($params = []) {
    $entries = collectBundledPluginBuildEntries($params);
    $filteredEntries = array_filter($entries, function($entry) {
        return !in_array($entry['id'], NON_PACKAGED_BUNDLED_PLUGIN_DIRS);
    });
    
    $artifacts = [];
    
    foreach ($filteredEntries as $entry) {
        if ($entry['hasManifest']) {
            $artifacts[] = bundledDistPluginFile($entry['id'], "openclaw.plugin.json");
        }
        if ($entry['hasPackageJson']) {
            $artifacts[] = bundledDistPluginFile($entry['id'], "package.json");
        }
        foreach ($entry['sourceEntries'] as $sourceEntry) {
            $normalizedEntry = preg_replace('/^\.\//', '', $sourceEntry);
            $baseName = preg_replace('/\.[^.]+$/', '', $normalizedEntry);
            $artifacts[] = bundledDistPluginFile($entry['id'], "{$baseName}.js");
        }
    }
    
    $artifacts = array_unique($artifacts);
    usort($artifacts, function($a, $b) {
        return strcmp($a, $b);
    });
    
    return $artifacts;
}

function listBundledPluginRuntimeDependencies($params = []) {
    $runtimeDependencies = [];
    $entries = collectBundledPluginBuildEntries($params);
    
    foreach ($entries as $entry) {
        if (!shouldStageBundledPluginRuntimeDependencies($entry['packageJson'])) {
            continue;
        }
        
        if (isset($entry['packageJson']['dependencies']) && is_array($entry['packageJson']['dependencies'])) {
            foreach ($entry['packageJson']['dependencies'] as $dependencyName => $version) {
                $runtimeDependencies[] = $dependencyName;
            }
        }
        
        if (isset($entry['packageJson']['optionalDependencies']) && is_array($entry['packageJson']['optionalDependencies'])) {
            foreach ($entry['packageJson']['optionalDependencies'] as $dependencyName => $version) {
                $runtimeDependencies[] = $dependencyName;
            }
        }
    }
    
    $runtimeDependencies = array_unique($runtimeDependencies);
    usort($runtimeDependencies, function($a, $b) {
        return strcmp($a, $b);
    });
    
    return $runtimeDependencies;
}
