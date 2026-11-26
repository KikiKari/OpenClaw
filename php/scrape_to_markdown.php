<?php
// abstraction-provenance: {"artifact_sha256": "da6dfef782fc100893be095cd8c8092fd7bd6d0bcdd5f675a290a02e3b37ba14", "source_sha256": "f76d25200d74ebc530580d7a7afb24c88ee8981f06c4d1734500f4cc830c4fe9", "target_language": "php"}
// scrape_to_markdown.py — portiert nach php
// Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: workspace@local:git/skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// auch in: workspace@local:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// SECURITY MANIFEST:
// Environment variables accessed: none
// External endpoints called: only URLs supplied by the user at runtime via --url / --url-file
// Local files read: --url-file path (if provided by user)
// Local files written: --output-dir/*.md, --output-dir/index.json (if --output-dir provided)
//                      Scrapling automatch SQLite DB (managed by Scrapling, local only)
// Credentials handled: --proxy value (never logged or transmitted beyond the proxy itself)
// Shell injection risk: none (pure PHP, no exec or shell interpolation)

function to_str($value) {
    if ($value === null) {
        return "";
    }
    if (is_string($value)) {
        return $value;
    }
    if (is_object($value) && method_exists($value, '__toString')) {
        return (string)$value;
    }
    return (string)$value;
}

function slugify($text, $max_len = 80) {
    $text = preg_replace('/[^\w\s-]/u', '', $text);
    $text = trim(strtolower($text));
    $text = preg_replace('/[-\s]+/', '-', $text);
    $text = substr($text, 0, $max_len);
    $text = trim($text, '-');
    return $text ?: "page";
}

function extract_html($obj) {
    if ($obj === null) {
        return "";
    }
    $attrs = ["html", "raw_html", "content", "markup", "body", "inner_html"];
    foreach ($attrs as $attr) {
        if (is_object($obj) && property_exists($obj, $attr)) {
            $value = $obj->$attr;
            if (is_callable($value)) {
                try {
                    $value = $value();
                } catch (Exception $e) {
                    $value = null;
                }
            }
            $text = to_str($value);
            if ($text && strpos($text, "<") !== false && strpos($text, ">") !== false) {
                return $text;
            }
        }
    }
    $text = to_str($obj);
    return (strpos($text, "<") !== false && strpos($text, ">") !== false) ? $text : "";
}

function extract_title($html) {
    if (preg_match('/<title[^>]*>(.*?)<\/title>/is', $html, $matches)) {
        $title = strip_tags($matches[1]);
        $title = preg_replace('/\s+/', ' ', $title);
        return trim($title);
    }
    return "";
}

function load_fetcher($js = false) {
    if ($js) {
        $candidates = [
            ["scrapling.fetchers", "DynamicFetcher"],
            ["scrapling.fetchers", "PlayWrightFetcher"],
            ["scrapling.default", "PlayWrightFetcher"],
            ["scrapling.defaults", "PlayWrightFetcher"],
        ];
    } else {
        $candidates = [
            ["scrapling.fetchers", "Fetcher"],
            ["scrapling.default", "Fetcher"],
            ["scrapling.defaults", "Fetcher"],
        ];
    }

    $errors = [];
    foreach ($candidates as [$module_name, $class_name]) {
        // In PHP we simulate this by checking if class exists or can be autoloaded
        // This is a simplified version - actual implementation would require autoloading
        try {
            if (class_exists($class_name)) {
                $reflection = new ReflectionClass($class_name);
                if ($reflection->hasMethod('get') || $reflection->hasMethod('fetch')) {
                    return [$class_name, $reflection->hasMethod('get') ? 'get' : 'fetch'];
                }
            }
        } catch (Exception $e) {
            $errors[] = "$module_name.$class_name: " . $e->getMessage();
        }
    }

    throw new RuntimeException("No compatible Scrapling fetcher found: " . implode(" | ", array_slice($errors, 0, 5)));
}

function fetch_page($url, $js = false, $wait_selector = null, $timeout = 30, $automatch_domain = null) {
    [$class_name, $method_name] = load_fetcher($js);

    $kwargs = [];
    if ($js) {
        $kwargs['headless'] = true;
        if ($wait_selector) {
            $kwargs['wait_selector'] = $wait_selector;
        }
    } else {
        $kwargs['timeout'] = $timeout;
    }

    if ($automatch_domain && !$js) {
        try {
            $instance = new $class_name(['automatch_domain' => $automatch_domain]);
            $method = [$instance, $method_name];
        } catch (Exception $e) {
            // fallback to default instantiation
        }
    }

    try {
        if (!isset($instance)) {
            $instance = new $class_name();
        }
        $method = [$instance, $method_name];
        $page = call_user_func_array($method, [$url, $kwargs]);
        return [$page, "$class_name::$method_name"];
    } catch (TypeError $e) {
        $page = call_user_func($method, $url);
        return [$page, "$class_name::$method_name"];
    }
}

function pick_main_html($page, $preferred_selector = null) {
    $selectors = [];
    if ($preferred_selector) {
        $selectors[] = $preferred_selector;
    }
    $selectors = array_merge($selectors, [
        "article",
        "main",
        "[role='main']",
        ".post-content",
        ".entry-content",
        ".article-content",
        "body",
    ]);

    if (is_object($page) && method_exists($page, 'css_first')) {
        foreach ($selectors as $selector) {
            try {
                $node = $page->css_first($selector);
                $html = extract_html($node);
                if ($html && strlen($html) >= 120) {
                    return [$html, $selector];
                }
            } catch (Exception $e) {
                // continue to next selector
            }
        }
    }

    return [extract_html($page), null];
}

function html_to_markdown($html, $preserve_links = false, $body_width = 0) {
    // Simple HTML to Markdown conversion
    // Note: This is a basic implementation. For production use, consider using a proper library
    
    // Remove images
    $html = preg_replace('/<img[^>]*>/i', '', $html);
    
    // Convert headers
    $html = preg_replace('/<h1[^>]*>(.*?)<\/h1>/i', "# $1\n\n", $html);
    $html = preg_replace('/<h2[^>]*>(.*?)<\/h2>/i', "## $1\n\n", $html);
    $html = preg_replace('/<h3[^>]*>(.*?)<\/h3>/i', "### $1\n\n", $html);
    
    // Convert paragraphs
    $html = preg_replace('/<p[^>]*>(.*?)<\/p>/i', "$1\n\n", $html);
    
    // Convert links if preserving
    if ($preserve_links) {
        $html = preg_replace('/<a[^>]*href=["\']([^"\']*)["\'][^>]*>(.*?)<\/a>/i', "[$2]($1)", $html);
    } else {
        $html = preg_replace('/<a[^>]*>(.*?)<\/a>/i', "$1", $html);
    }
    
    // Convert bold/strong
    $html = preg_replace('/<(?:b|strong)[^>]*>(.*?)<\/(?:b|strong)>/i', "**$1**", $html);
    
    // Convert italic/em
    $html = preg_replace('/<(?:i|em)[^>]*>(.*?)<\/(?:i|em)>/i', "*$1*", $html);
    
    // Convert lists
    $html = preg_replace('/<ul[^>]*>(.*?)<\/ul>/is', "\n$1\n", $html);
    $html = preg_replace('/<ol[^>]*>(.*?)<\/ol>/is', "\n$1\n", $html);
    $html = preg_replace('/<li[^>]*>(.*?)<\/li>/i', "- $1", $html);
    
    // Remove remaining HTML tags
    $html = strip_tags($html);
    
    // Normalize whitespace
    $html = preg_replace('/\n{3,}/', "\n\n", $html);
    
    return trim($html);
}

function load_urls($url_args, $url_file) {
    $urls = $url_args ?: [];
    if ($url_file) {
        $lines = file($url_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line && !str_starts_with($line, '#')) {
                $urls[] = $line;
            }
        }
    }
    $clean = [];
    $seen = [];
    foreach ($urls as $u) {
        if (!in_array($u, $seen)) {
            $clean[] = $u;
            $seen[] = $u;
        }
    }
    return $clean;
}

function validate_url($url) {
    $parsed = parse_url($url);
    return isset($parsed['scheme']) && in_array($parsed['scheme'], ['http', 'https']) && isset($parsed['host']);
}

function main() {
    global $argv;
    
    $args = [
        '--url' => [],
        '--url-file' => '',
        '--selector' => '',
        '--js' => false,
        '--wait-selector' => '',
        '--preserve-links' => false,
        '--body-width' => 0,
        '--timeout' => 30,
        '--output-dir' => 'outputs',
        '--automatch-domain' => ''
    ];
    
    // Parse command line arguments
    for ($i = 1; $i < count($argv); $i++) {
        $arg = $argv[$i];
        if ($arg === '--url') {
            $args['--url'][] = $argv[++$i];
        } elseif ($arg === '--url-file') {
            $args['--url-file'] = $argv[++$i];
        } elseif ($arg === '--selector') {
            $args['--selector'] = $argv[++$i];
        } elseif ($arg === '--js') {
            $args['--js'] = true;
        } elseif ($arg === '--wait-selector') {
            $args['--wait-selector'] = $argv[++$i];
        } elseif ($arg === '--preserve-links') {
            $args['--preserve-links'] = true;
        } elseif ($arg === '--body-width') {
            $args['--body-width'] = (int)$argv[++$i];
        } elseif ($arg === '--timeout') {
            $args['--timeout'] = (int)$argv[++$i];
        } elseif ($arg === '--output-dir') {
            $args['--output-dir'] = $argv[++$i];
        } elseif ($arg === '--automatch-domain') {
            $args['--automatch-domain'] = $argv[++$i];
        }
    }
    
    $urls = load_urls($args['--url'], $args['--url-file']);
    if (!$urls) {
        echo json_encode(["ok" => false, "error" => "No URLs provided"], JSON_UNESCAPED_UNICODE) . "\n";
        exit(1);
    }
    
    foreach ($urls as $u) {
        if (!validate_url($u)) {
            echo json_encode(["ok" => false, "error" => "Invalid URL: $u"], JSON_UNESCAPED_UNICODE) . "\n";
            exit(1);
        }
    }
    
    $out_dir = $args['--output-dir'];
    if (!is_dir($out_dir)) {
        mkdir($out_dir, 0755, true);
    }
    
    $results = [];
    
    foreach ($urls as $url) {
        $item = [
            "url" => $url,
            "ok" => false,
            "title" => "",
            "status" => null,
            "selector_used" => null,
            "backend" => null,
            "markdown" => "",
            "preview" => "",
            "output_markdown_file" => null,
            "error" => null,
        ];
        
        try {
            [$page, $backend] = fetch_page(
                $url,
                $args['--js'],
                $args['--wait-selector'] ?: null,
                $args['--timeout'],
                $args['--automatch-domain'] ?: null
            );
            
            [$html, $selector_used] = pick_main_html($page, $args['--selector'] ?: null);
            if (!$html) {
                throw new RuntimeException("No HTML content extracted from page");
            }
            
            $title = extract_title($html) ?: parse_url($url, PHP_URL_HOST);
            $markdown = html_to_markdown(
                $html,
                $args['--preserve-links'],
                $args['--body-width']
            );
            
            $filename = slugify(parse_url($url, PHP_URL_HOST) . "-" . $title) . ".md";
            $md_path = $out_dir . DIRECTORY_SEPARATOR . $filename;
            file_put_contents($md_path, $markdown);
            
            $status = null;
            if (is_object($page) && property_exists($page, 'status')) {
                $status = $page->status;
            } elseif (is_object($page) && property_exists($page, 'status_code')) {
                $status = $page->status_code;
            }
            
            $item = array_merge($item, [
                "ok" => true,
                "title" => $title,
                "status" => $status,
                "selector_used" => $selector_used,
                "backend" => $backend,
                "markdown" => $markdown,
                "preview" => substr($markdown, 0, 1200),
                "output_markdown_file" => $md_path,
            ]);
        } catch (Exception $e) {
            $item["error"] = $e->getMessage();
        }
        
        $results[] = $item;
    }
    
    $ok = array_reduce($results, function($carry, $item) {
        return $carry || $item["ok"];
    }, false);
    
    $index_path = $out_dir . DIRECTORY_SEPARATOR . "index.json";
    $payload = [
        "ok" => $ok,
        "count" => count($results),
        "success_count" => array_sum(array_map(function($x) { return $x["ok"] ? 1 : 0; }, $results)),
        "failure_count" => array_sum(array_map(function($x) { return $x["ok"] ? 0 : 1; }, $results)),
        "output_index_file" => $index_path,
        "results" => $results,
    ];
    
    file_put_contents($index_path, json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    echo json_encode($payload, JSON_UNESCAPED_UNICODE) . "\n";
}

main();
