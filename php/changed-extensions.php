<?php
// abstraction-provenance: {"artifact_sha256": "65caab85bc9b5fb5caa05367c746945853251b441895ed5e5d137f5a29f5096c", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "php"}
// changed-extensions.mjs — portiert nach php
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
require_once __DIR__ . "/bundled-plugin-paths.php";

const REPO_ROOT = __DIR__ . "/../..";

function run_git($args, $options = []) {
    $descriptorspec = [
        0 => ["pipe", "r"],  // stdin
        1 => ["pipe", "w"],  // stdout
        2 => ["pipe", "w"]   // stderr
    ];

    $cmd = "git " . implode(" ", array_map('escapeshellarg', $args));
    $process = proc_open($cmd, $descriptorspec, $pipes, REPO_ROOT);

    if (is_resource($process)) {
        fclose($pipes[0]); // Close stdin

        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);

        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        $return_value = proc_close($process);

        if ($return_value !== 0) {
            throw new Exception("Git command failed: " . $stderr);
        }

        return $stdout;
    } else {
        throw new Exception("Failed to execute git command");
    }
}

function normalize_relative($input_path) {
    return str_replace(DIRECTORY_SEPARATOR, "/", $input_path);
}

function has_git_commit($ref) {
    if (!$ref || preg_match('/^0+$/', $ref)) {
        return false;
    }

    try {
        run_git(["rev-parse", "--verify", "$ref^{commit}"]);
        return true;
    } catch (Exception $e) {
        return false;
    }
}

function resolve_changed_paths_base($params = []) {
    $base = $params['base'] ?? null;
    $head = $params['head'] ?? "HEAD";
    $fallback_base_ref = $params['fallbackBaseRef'] ?? null;

    if (has_git_commit($base)) {
        return $base;
    }

    if ($fallback_base_ref) {
        $remote_base_ref = strpos($fallback_base_ref, "origin/") === 0
            ? $fallback_base_ref
            : "origin/$fallback_base_ref";

        if (has_git_commit($remote_base_ref)) {
            $merge_base_output = run_git(["merge-base", $remote_base_ref, $head]);
            $merge_base = trim($merge_base_output);
            if (has_git_commit($merge_base)) {
                return $merge_base;
            }
        }
    }

    if (!$base) {
        throw new Exception("A git base revision is required to list changed extensions.");
    }

    throw new Exception("Git base revision is unavailable locally: $base");
}

function list_changed_paths($base, $head = "HEAD") {
    if (!$base) {
        throw new Exception("A git base revision is required to list changed extensions.");
    }

    $output = run_git(["diff", "--name-only", $base, $head]);
    $lines = explode("\n", $output);
    $result = [];

    foreach ($lines as $line) {
        $trimmed_line = trim($line);
        if (strlen($trimmed_line) > 0) {
            $result[] = $trimmed_line;
        }
    }

    return $result;
}

function has_extension_package($extension_id) {
    $package_json_path = REPO_ROOT . "/" . BUNDLED_PLUGIN_ROOT_DIR . "/$extension_id/package.json";
    return file_exists($package_json_path);
}

function list_available_extension_ids() {
    $extensions_dir = REPO_ROOT . "/" . BUNDLED_PLUGIN_ROOT_DIR;
    if (!file_exists($extensions_dir)) {
        return [];
    }

    $entries = scandir($extensions_dir);
    $directories = [];

    foreach ($entries as $entry) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        $full_path = $extensions_dir . '/' . $entry;
        if (is_dir($full_path) && has_extension_package($entry)) {
            $directories[] = $entry;
        }
    }

    sort($directories);
    return $directories;
}

function detect_changed_extension_ids($changed_paths) {
    $extension_ids = [];

    foreach ($changed_paths as $raw_path) {
        $relative_path = normalize_relative(trim(strval($raw_path)));
        if (!$relative_path) {
            continue;
        }

        $pattern = '/^' . str_replace("/", "\\/", BUNDLED_PLUGIN_PATH_PREFIX) . '([^\/]+)(?:\/|$)/';
        if (preg_match($pattern, $relative_path, $extension_match)) {
            $extension_id = $extension_match[1];
            if (has_extension_package($extension_id)) {
                $extension_ids[$extension_id] = true;
            }
            continue;
        }

        if (preg_match('/^src\/([^\/]+)(?:\/|$)/', $relative_path, $paired_core_match) &&
            has_extension_package($paired_core_match[1])) {
            $extension_ids[$paired_core_match[1]] = true;
        }
    }

    $keys = array_keys($extension_ids);
    sort($keys);
    return $keys;
}

function list_changed_extension_ids($params = []) {
    $head = $params['head'] ?? "HEAD";
    $unavailable_base_behavior = $params['unavailableBaseBehavior'] ?? "error";

    try {
        $base = resolve_changed_paths_base($params);
        return detect_changed_extension_ids(list_changed_paths($base, $head));
    } catch (Exception $error) {
        if ($unavailable_base_behavior === "all") {
            return list_available_extension_ids();
        }
        if ($unavailable_base_behavior === "empty") {
            return [];
        }
        throw $error;
    }
}
