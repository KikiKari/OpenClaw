<?php
// abstraction-provenance: {"artifact_sha256": "77235cccb5c2de8bd697eb0f832794ee7daf1962a22df0ea3769fe6de058d8b7", "source_sha256": "5ea1a8c9a13631404f27bfdb1410099cd81f89038616abac4b49bd62666db56a", "target_language": "php"}
// secret-scan.mjs — portiert nach php
// Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
$root = dirname(__DIR__);
$skipped = [
  "node_modules",
  ".next",
  ".git",
  ".pytest_cache",
  "__pycache__",
  "media-production/raw",
  "media-production/private",
];
$patterns = [
  '/sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}/',
  '/(?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}/',
  '/ELEVENLABS_API_KEY\s*=\s*["\']?[A-Za-z0-9]{20,}/',
  '/WAVESPEED_API_KEY\s*=\s*["\']?[A-Za-z0-9]{20,}/',
];
$findings = [];

function walk($dir, $relative = "") {
  global $skipped, $patterns, $findings;
  
  if (!is_dir($dir)) return;
  
  $entries = scandir($dir);
  foreach ($entries as $entry) {
    if ($entry === '.' || $entry === '..') continue;
    
    $rel = $relative === "" ? $entry : $relative . DIRECTORY_SEPARATOR . $entry;
    
    if (
      $entry === ".env" ||
      (strpos($entry, ".env.") === 0 && $entry !== ".env.example") ||
      array_reduce($skipped, function($carry, $item) use ($rel) {
        return $carry || 
          $rel === $item || 
          strpos($rel, $item . DIRECTORY_SEPARATOR) === 0 ||
          in_array($item, explode(DIRECTORY_SEPARATOR, $rel));
      }, false)
    ) continue;
    
    $target = $dir . DIRECTORY_SEPARATOR . $entry;
    
    if (is_dir($target)) {
      walk($target, $rel);
    } elseif (is_file($target) && filesize($target) < 2000000) {
      $content = file_get_contents($target);
      if ($content !== false) {
        foreach ($patterns as $pattern) {
          if (preg_match($pattern, $content)) {
            $findings[] = $rel;
            break;
          }
        }
      }
    }
  }
}

walk($root);

if (count($findings) > 0) {
  $unique_findings = array_unique($findings);
  fwrite(STDERR, "Secret-Scan fehlgeschlagen: " . implode(", ", $unique_findings) . "\n");
  exit(1);
}

echo "Secret-Scan bestanden.\n";
