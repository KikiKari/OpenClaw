<?php
// abstraction-provenance: {"artifact_sha256": "da4528715ab211ab0edc40ac9f5c0df6c365482d8b9dfc3402e9508b4be97ac7", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "php"}
// tm.go — portiert nach php
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
class TMEntry {
    public string $cacheKey;
    public string $segmentID;
    public string $sourcePath;
    public string $textHash;
    public string $text;
    public string $translated;
    public string $provider;
    public string $model;
    public string $srcLang;
    public string $tgtLang;
    public string $updatedAt;

    public function __construct(
        string $cacheKey = '',
        string $segmentID = '',
        string $sourcePath = '',
        string $textHash = '',
        string $text = '',
        string $translated = '',
        string $provider = '',
        string $model = '',
        string $srcLang = '',
        string $tgtLang = '',
        string $updatedAt = ''
    ) {
        $this->cacheKey = $cacheKey;
        $this->segmentID = $segmentID;
        $this->sourcePath = $sourcePath;
        $this->textHash = $textHash;
        $this->text = $text;
        $this->translated = $translated;
        $this->provider = $provider;
        $this->model = $model;
        $this->srcLang = $srcLang;
        $this->tgtLang = $tgtLang;
        $this->updatedAt = $updatedAt;
    }

    public static function fromArray(array $data): self {
        return new self(
            $data['cache_key'] ?? '',
            $data['segment_id'] ?? '',
            $data['source_path'] ?? '',
            $data['text_hash'] ?? '',
            $data['text'] ?? '',
            $data['translated'] ?? '',
            $data['provider'] ?? '',
            $data['model'] ?? '',
            $data['src_lang'] ?? '',
            $data['tgt_lang'] ?? '',
            $data['updated_at'] ?? ''
        );
    }

    public function toArray(): array {
        return [
            'cache_key' => $this->cacheKey,
            'segment_id' => $this->segmentID,
            'source_path' => $this->sourcePath,
            'text_hash' => $this->textHash,
            'text' => $this->text,
            'translated' => $this->translated,
            'provider' => $this->provider,
            'model' => $this->model,
            'src_lang' => $this->srcLang,
            'tgt_lang' => $this->tgtLang,
            'updated_at' => $this->updatedAt,
        ];
    }
}

class TranslationMemory {
    private string $path;
    private array $entries;

    public function __construct(string $path, array $entries = []) {
        $this->path = $path;
        $this->entries = $entries;
    }

    public static function loadTranslationMemory(string $path): TranslationMemory {
        $entries = [];
        
        if (!file_exists($path)) {
            return new TranslationMemory($path, $entries);
        }

        $content = file_get_contents($path);
        if ($content === false) {
            throw new Exception("Failed to open file: $path");
        }

        $lines = explode("\n", trim($content));
        foreach ($lines as $line) {
            $trimmed = trim($line);
            if ($trimmed !== '') {
                $data = json_decode($trimmed, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    throw new Exception("translation memory decode failed: " . json_last_error_msg());
                }
                
                $entry = TMEntry::fromArray($data);
                if ($entry->cacheKey !== '' && trim($entry->translated) !== '') {
                    $entries[$entry->cacheKey] = $entry;
                }
            }
        }

        return new TranslationMemory($path, $entries);
    }

    public function get(string $cacheKey): ?TMEntry {
        if (!isset($this->entries[$cacheKey])) {
            return null;
        }
        
        $entry = $this->entries[$cacheKey];
        if (trim($entry->translated) === '') {
            return null;
        }
        
        return $entry;
    }

    public function put(TMEntry $entry): void {
        if ($entry->cacheKey === '') {
            return;
        }
        $this->entries[$entry->cacheKey] = $entry;
    }

    public function save(): bool {
        if ($this->path === '') {
            return true;
        }
        
        $dir = dirname($this->path);
        if (!is_dir($dir)) {
            if (!mkdir($dir, 0755, true)) {
                return false;
            }
        }
        
        $tmpPath = $this->path . '.tmp';
        $file = fopen($tmpPath, 'w');
        if (!$file) {
            return false;
        }

        $keys = array_keys($this->entries);
        sort($keys);

        foreach ($keys as $key) {
            $entry = $this->entries[$key];
            $payload = json_encode($entry->toArray());
            if ($payload === false || fwrite($file, $payload . "\n") === false) {
                fclose($file);
                return false;
            }
        }

        fclose($file);
        return rename($tmpPath, $this->path);
    }
}
