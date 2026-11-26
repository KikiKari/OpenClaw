<?php
// abstraction-provenance: {"artifact_sha256": "9a62bb54e62fd28a3dd07409ee8e6ac45bea44eba8b9afa083614bd937baa631", "source_sha256": "5e833080809c70bbbe1eee5fa14d9d07d639ca0b16c37253625f4dc46ca1e64f", "target_language": "php"}
// model_usage.py — portiert nach php
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
/**
 * Summarize CodexBar local cost usage by model.
 *
 * Defaults to current model (most recent daily entry), or list all models.
 */

function positive_int($value) {
    if (!is_numeric($value) || !ctype_digit($value)) {
        throw new InvalidArgumentException("must be an integer");
    }
    $parsed = intval($value);
    if ($parsed < 1) {
        throw new InvalidArgumentException("must be >= 1");
    }
    return $parsed;
}

function eprint($msg) {
    fwrite(STDERR, $msg . PHP_EOL);
}

function run_codexbar_cost($provider) {
    $cmd = "codexbar cost --format json --provider " . escapeshellarg($provider);
    $output = shell_exec($cmd);
    
    if ($output === null) {
        throw new RuntimeException("codexbar not found on PATH. Install CodexBar CLI first.");
    }
    
    $payload = json_decode($output, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new RuntimeException("Failed to parse codexbar JSON output: " . json_last_error_msg());
    }
    
    if (!is_array($payload)) {
        throw new RuntimeException("Expected codexbar cost JSON array.");
    }
    
    return $payload;
}

function load_payload($input_path, $provider) {
    if ($input_path) {
        if ($input_path === "-") {
            $raw = file_get_contents("php://stdin");
        } else {
            $raw = file_get_contents($input_path);
        }
        $data = json_decode($raw, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new RuntimeException("Failed to parse JSON input: " . json_last_error_msg());
        }
    } else {
        $data = run_codexbar_cost($provider);
    }

    if (is_array($data) && array_key_exists("provider", $data)) {
        return $data;
    }

    if (is_array($data)) {
        foreach ($data as $entry) {
            if (is_array($entry) && isset($entry["provider"]) && $entry["provider"] === $provider) {
                return $entry;
            }
        }
        throw new RuntimeException("Provider '{$provider}' not found in codexbar payload.");
    }

    throw new RuntimeException("Unsupported JSON input format.");
}

function parse_daily_entries($payload) {
    $daily = $payload["daily"] ?? [];
    if (!is_array($daily)) {
        return [];
    }
    return array_filter($daily, function($entry) {
        return is_array($entry);
    });
}

function parse_date($value) {
    $date = DateTime::createFromFormat("Y-m-d", $value);
    return $date ? $date->format("Y-m-d") : null;
}

function filter_by_days($entries, $days) {
    if (!$days) {
        return $entries;
    }
    
    $cutoff = new DateTime();
    $cutoff->modify("-" . ($days - 1) . " days");
    
    $filtered = [];
    foreach ($entries as $entry) {
        $day = $entry["date"] ?? null;
        if (!is_string($day)) {
            continue;
        }
        $parsed = parse_date($day);
        if ($parsed && $parsed >= $cutoff->format("Y-m-d")) {
            $filtered[] = $entry;
        }
    }
    return $filtered;
}

function aggregate_costs($entries) {
    $totals = [];
    foreach ($entries as $entry) {
        $breakdowns = $entry["modelBreakdowns"] ?? null;
        if (!$breakdowns) {
            continue;
        }
        if (!is_array($breakdowns)) {
            continue;
        }
        foreach ($breakdowns as $item) {
            if (!is_array($item)) {
                continue;
            }
            $model = $item["modelName"] ?? null;
            $cost = $item["cost"] ?? null;
            if (!is_string($model)) {
                continue;
            }
            if (!is_numeric($cost)) {
                continue;
            }
            if (!isset($totals[$model])) {
                $totals[$model] = 0.0;
            }
            $totals[$model] += floatval($cost);
        }
    }
    return $totals;
}

function pick_current_model($entries) {
    if (!$entries) {
        return [null, null];
    }
    
    usort($entries, function($a, $b) {
        return strcmp($a["date"] ?? "", $b["date"] ?? "");
    });
    
    foreach (array_reverse($entries) as $entry) {
        $breakdowns = $entry["modelBreakdowns"] ?? null;
        if (is_array($breakdowns) && !empty($breakdowns)) {
            $scored = [];
            foreach ($breakdowns as $item) {
                if (!is_array($item)) {
                    continue;
                }
                $model = $item["modelName"] ?? null;
                $cost = $item["cost"] ?? null;
                if (is_string($model) && is_numeric($cost)) {
                    $scored[] = ["model" => $model, "cost" => floatval($cost)];
                }
            }
            if (!empty($scored)) {
                usort($scored, function($a, $b) {
                    return $b["cost"] <=> $a["cost"];
                });
                return [$scored[0]["model"], $entry["date"] ?? null];
            }
        }
        
        $models_used = $entry["modelsUsed"] ?? null;
        if (is_array($models_used) && !empty($models_used)) {
            $last = end($models_used);
            if (is_string($last)) {
                return [$last, $entry["date"] ?? null];
            }
        }
    }
    return [null, null];
}

function usd($value) {
    if ($value === null) {
        return "—";
    }
    return "$" . number_format($value, 2, ".", ",");
}

function latest_day_cost($entries, $model) {
    if (!$entries) {
        return [null, null];
    }
    
    usort($entries, function($a, $b) {
        return strcmp($a["date"] ?? "", $b["date"] ?? "");
    });
    
    foreach (array_reverse($entries) as $entry) {
        $breakdowns = $entry["modelBreakdowns"] ?? null;
        if (!is_array($breakdowns)) {
            continue;
        }
        foreach ($breakdowns as $item) {
            if (!is_array($item)) {
                continue;
            }
            if (($item["modelName"] ?? null) === $model) {
                $cost = is_numeric($item["cost"] ?? null) ? floatval($item["cost"]) : null;
                $day = is_string($entry["date"] ?? null) ? $entry["date"] : null;
                return [$day, $cost];
            }
        }
    }
    return [null, null];
}

function render_text_current($provider, $model, $latest_date, $total_cost, $latest_cost, $latest_cost_date, $entry_count) {
    $lines = [
        "Provider: {$provider}",
        "Current model: {$model}"
    ];
    
    if ($latest_date) {
        $lines[] = "Latest model date: {$latest_date}";
    }
    
    $lines[] = "Total cost (rows): " . usd($total_cost);
    
    if ($latest_cost_date) {
        $lines[] = "Latest day cost: " . usd($latest_cost) . " ({$latest_cost_date})";
    }
    
    $lines[] = "Daily rows: {$entry_count}";
    
    return implode("\n", $lines);
}

function render_text_all($provider, $totals) {
    $lines = [
        "Provider: {$provider}",
        "Models:"
    ];
    
    arsort($totals);
    
    foreach ($totals as $model => $cost) {
        $lines[] = "- {$model}: " . usd($cost);
    }
    
    return implode("\n", $lines);
}

function build_json_current($provider, $model, $latest_date, $total_cost, $latest_cost, $latest_cost_date, $entry_count) {
    return [
        "provider" => $provider,
        "mode" => "current",
        "model" => $model,
        "latestModelDate" => $latest_date,
        "totalCostUSD" => $total_cost,
        "latestDayCostUSD" => $latest_cost,
        "latestDayCostDate" => $latest_cost_date,
        "dailyRowCount" => $entry_count
    ];
}

function build_json_all($provider, $totals) {
    arsort($totals);
    
    $models = [];
    foreach ($totals as $model => $cost) {
        $models[] = [
            "model" => $model,
            "totalCostUSD" => $cost
        ];
    }
    
    return [
        "provider" => $provider,
        "mode" => "all",
        "models" => $models
    ];
}

function main() {
    global $argv;
    
    $shortopts = "";
    $longopts = [
        "provider:",
        "mode:",
        "model:",
        "input:",
        "days:",
        "format:",
        "pretty"
    ];
    
    $args = getopt($shortopts, $longopts);
    
    $provider = $args["provider"] ?? "codex";
    $mode = $args["mode"] ?? "current";
    $model = $args["model"] ?? null;
    $input = $args["input"] ?? null;
    $days = $args["days"] ?? null;
    $format = $args["format"] ?? "text";
    $pretty = isset($args["pretty"]);
    
    if ($days !== null) {
        try {
            $days = positive_int($days);
        } catch (Exception $e) {
            eprint($e->getMessage());
            return 1;
        }
    }
    
    try {
        $payload = load_payload($input, $provider);
    } catch (Exception $e) {
        eprint($e->getMessage());
        return 1;
    }
    
    $entries = parse_daily_entries($payload);
    $entries = filter_by_days($entries, $days);
    
    if ($mode === "current") {
        $latest_date = null;
        if (!$model) {
            list($model, $latest_date) = pick_current_model($entries);
        }
        if (!$model) {
            eprint("No model data found in codexbar cost payload.");
            return 2;
        }
        $totals = aggregate_costs($entries);
        $total_cost = $totals[$model] ?? null;
        list($latest_cost_date, $latest_cost) = latest_day_cost($entries, $model);
        
        if ($format === "json") {
            $payload_out = build_json_current(
                $provider,
                $model,
                $latest_date,
                $total_cost,
                $latest_cost,
                $latest_cost_date,
                count($entries)
            );
            echo json_encode($payload_out, $pretty ? JSON_PRETTY_PRINT : 0) . "\n";
        } else {
            echo render_text_current(
                $provider,
                $model,
                $latest_date,
                $total_cost,
                $latest_cost,
                $latest_cost_date,
                count($entries)
            ) . "\n";
        }
        return 0;
    }
    
    $totals = aggregate_costs($entries);
    if (empty($totals)) {
        eprint("No model breakdowns found in codexbar cost payload.");
        return 2;
    }
    
    if ($format === "json") {
        $payload_out = build_json_all($provider, $totals);
        echo json_encode($payload_out, $pretty ? JSON_PRETTY_PRINT : 0) . "\n";
    } else {
        echo render_text_all($provider, $totals) . "\n";
    }
    return 0;
}

exit(main());

?>
