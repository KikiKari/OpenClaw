<?php
// abstraction-provenance: {"artifact_sha256": "915b1b14c1c71fa6eb9befb743321c8baf72a0fcdc517072db6d5a22eee1ccdc", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "php"}
// bundled-plugin-root-runtime-mirrors.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
const JS_EXTENSIONS = [".cjs", ".js", ".mjs"];

function collectRuntimeDependencySpecs($packageJson = []) {
    $dependencies = $packageJson["dependencies"] ?? [];
    $optionalDependencies = $packageJson["optionalDependencies"] ?? [];
    
    $entries = array_merge(
        is_array($dependencies) ? $dependencies : [],
        is_array($optionalDependencies) ? $optionalDependencies : []
    );
    
    $result = [];
    foreach ($entries as $key => $value) {
        if (is_string($value) && strlen($value) > 0) {
            $result[$key] = $value;
        }
    }
    
    return $result;
}

function packageNameFromSpecifier($specifier) {
    if (!is_string($specifier) ||
        str_starts_with($specifier, ".") ||
        str_starts_with($specifier, "/") ||
        str_starts_with($specifier, "node:") ||
        str_starts_with($specifier, "#")) {
        return null;
    }
    
    $parts = explode("/", $specifier);
    $first = $parts[0] ?? "";
    $second = $parts[1] ?? "";
    
    if (!$first) {
        return null;
    }
    
    if (str_starts_with($first, "@") && $second) {
        return "$first/$second";
    }
    
    return $first;
}

function readJson($filePath) {
    $content = file_get_contents($filePath);
    return json_decode($content, true);
}

function collectPackageJsonPaths($rootDir) {
    if (!file_exists($rootDir)) {
        return [];
    }
    
    $entries = scandir($rootDir);
    $paths = [];
    
    foreach ($entries as $entry) {
        if ($entry === "." || $entry === "..") {
            continue;
        }
        
        $fullPath = "$rootDir/$entry";
        if (is_dir($fullPath)) {
            $packageJsonPath = "$fullPath/package.json";
            if (file_exists($packageJsonPath)) {
                $paths[] = $packageJsonPath;
            }
        }
    }
    
    usort($paths, function($a, $b) {
        return strcmp($a, $b);
    });
    
    return $paths;
}

function collectBundledPluginRuntimeDependencySpecs($bundledPluginsDir) {
    $specs = [];
    
    $packageJsonPaths = collectPackageJsonPaths($bundledPluginsDir);
    
    foreach ($packageJsonPaths as $packageJsonPath) {
        $packageJson = readJson($packageJsonPath);
        $pluginId = basename(dirname($packageJsonPath));
        $deps = collectRuntimeDependencySpecs($packageJson);
        
        foreach ($deps as $name => $spec) {
            if (isset($specs[$name])) {
                $existing = $specs[$name];
                if ($existing["spec"] !== $spec) {
                    $existing["conflicts"][] = ["pluginId" => $pluginId, "spec" => $spec];
                } elseif (!in_array($pluginId, $existing["pluginIds"])) {
                    $existing["pluginIds"][] = $pluginId;
                }
                $specs[$name] = $existing;
                continue;
            }
            
            $specs[$name] = [
                "conflicts" => [],
                "pluginIds" => [$pluginId],
                "spec" => $spec
            ];
        }
    }
    
    return $specs;
}

function walkJavaScriptFiles($rootDir) {
    $files = [];
    if (!file_exists($rootDir)) {
        return $files;
    }
    
    $queue = [$rootDir];
    
    while (count($queue) > 0) {
        $current = array_shift($queue);
        $entries = scandir($current);
        
        foreach ($entries as $entry) {
            if ($entry === "." || $entry === "..") {
                continue;
            }
            
            $fullPath = "$current/$entry";
            
            if (is_dir($fullPath)) {
                $pathParts = explode(DIRECTORY_SEPARATOR, $fullPath);
                if (in_array("extensions", $pathParts)) {
                    continue;
                }
                $queue[] = $fullPath;
                continue;
            }
            
            if (is_file($fullPath)) {
                $extension = strrchr($entry, ".");
                if ($extension && in_array($extension, JS_EXTENSIONS)) {
                    $files[] = $fullPath;
                }
            }
        }
    }
    
    usort($files, function($a, $b) {
        return strcmp($a, $b);
    });
    
    return $files;
}

function extractModuleSpecifiers($source) {
    $specifiers = [];
    $patterns = [
        '/\bfrom\s*["\']([^"\']+)["\']/',
        '/\bimport\s*["\']([^"\']+)["\']/',
        '/\bimport\s*\(\s*["\']([^"\']+)["\']\s*\)/',
        '/\brequire\s*\(\s*["\']([^"\']+)["\']\s*\)/'
    ];
    
    foreach ($patterns as $pattern) {
        preg_match_all($pattern, $source, $matches);
        foreach ($matches[1] as $match) {
            if ($match) {
                $specifiers[] = $match;
            }
        }
    }
    
    return array_unique($specifiers);
}

function collectRootDistBundledRuntimeMirrors($params) {
    $distDir = $params["distDir"];
    $bundledSpecs = $params["bundledRuntimeDependencySpecs"];
    $mirrors = [];
    
    $files = walkJavaScriptFiles($distDir);
    
    foreach ($files as $filePath) {
        $source = file_get_contents($filePath);
        $relativePath = str_replace("\\", "/", substr($filePath, strlen($distDir) + 1));
        
        $specifiers = extractModuleSpecifiers($source);
        
        foreach ($specifiers as $specifier) {
            $dependencyName = packageNameFromSpecifier($specifier);
            if (!$dependencyName || !isset($bundledSpecs[$dependencyName])) {
                continue;
            }
            
            $bundledSpec = $bundledSpecs[$dependencyName];
            
            if (isset($mirrors[$dependencyName])) {
                $mirrors[$dependencyName]["importers"][] = $relativePath;
                continue;
            }
            
            $mirrors[$dependencyName] = [
                "importers" => [$relativePath],
                "pluginIds" => $bundledSpec["pluginIds"],
                "spec" => $bundledSpec["spec"]
            ];
        }
    }
    
    return $mirrors;
}

function collectBundledPluginRootRuntimeMirrorErrors($params) {
    $rootRuntimeDeps = collectRuntimeDependencySpecs($params["rootPackageJson"]);
    $errors = [];
    
    foreach ($params["bundledRuntimeDependencySpecs"] as $dependencyName => $record) {
        foreach ($record["conflicts"] as $conflict) {
            $errors[] = "bundled runtime dependency '$dependencyName' has conflicting plugin specs: " . implode(", ", $record["pluginIds"]) . " use '{$record["spec"]}', {$conflict["pluginId"]} uses '{$conflict["spec"]}'.";
        }
    }
    
    foreach ($params["requiredRootMirrors"] as $dependencyName => $mirror) {
        $rootSpec = $rootRuntimeDeps[$dependencyName] ?? null;
        sort($mirror["importers"]);
        $importerLabel = implode(", ", $mirror["importers"]);
        sort($mirror["pluginIds"]);
        $pluginLabel = implode(", ", $mirror["pluginIds"]);
        
        if (!is_string($rootSpec) || strlen($rootSpec) === 0) {
            $errors[] = "root dist imports bundled plugin runtime dependency '$dependencyName' from $importerLabel; mirror '$dependencyName: {$mirror["spec"]}' in root package.json (declared by $pluginLabel).";
            continue;
        }
        
        if ($rootSpec !== $mirror["spec"]) {
            $errors[] = "root dist imports bundled plugin runtime dependency '$dependencyName' from $importerLabel; root package.json has '$rootSpec' but plugin manifest declares '{$mirror["spec"]}' ($pluginLabel).";
        }
    }
    
    return $errors;
}

?>
