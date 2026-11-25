// abstraction-provenance: {"artifact_sha256": "58b2be7c674e0a849a5ab198d185ddfde1d6220eddc13ab5fe0fddd2dfefed82", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "java"}
// tm.go — portiert nach java
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Collectors;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.JsonProcessingException;

class TMEntry {
    public String cache_key;
    public String segment_id;
    public String source_path;
    public String text_hash;
    public String text;
    public String translated;
    public String provider;
    public String model;
    public String src_lang;
    public String tgt_lang;
    public String updated_at;

    // Default constructor for Jackson
    public TMEntry() {}

    public TMEntry(String cacheKey, String segmentID, String sourcePath, String textHash, 
                   String text, String translated, String provider, String model, 
                   String srcLang, String tgtLang, String updatedAt) {
        this.cache_key = cacheKey;
        this.segment_id = segmentID;
        this.source_path = sourcePath;
        this.text_hash = textHash;
        this.text = text;
        this.translated = translated;
        this.provider = provider;
        this.model = model;
        this.src_lang = srcLang;
        this.tgt_lang = tgtLang;
        this.updated_at = updatedAt;
    }
}

public class TranslationMemory {
    private String path;
    private Map<String, TMEntry> entries;
    private static final ObjectMapper objectMapper = new ObjectMapper();

    public TranslationMemory(String path, Map<String, TMEntry> entries) {
        this.path = path;
        this.entries = entries != null ? entries : new HashMap<>();
    }

    public static TranslationMemory loadTranslationMemory(String path) throws IOException {
        Map<String, TMEntry> entries = new HashMap<>();
        
        File file = new File(path);
        if (!file.exists()) {
            return new TranslationMemory(path, entries);
        }

        try (BufferedReader reader = Files.newBufferedReader(Paths.get(path))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (!line.isEmpty()) {
                    try {
                        TMEntry entry = objectMapper.readValue(line, TMEntry.class);
                        if (entry.cache_key != null && entry.cache_key.length() > 0 && 
                            entry.translated != null && entry.translated.trim().length() > 0) {
                            entries.put(entry.cache_key, entry);
                        }
                    } catch (JsonProcessingException e) {
                        throw new IOException("translation memory decode failed: " + e.getMessage(), e);
                    }
                }
            }
        }
        
        return new TranslationMemory(path, entries);
    }

    public TMEntry get(String cacheKey) {
        TMEntry entry = entries.get(cacheKey);
        if (entry == null) {
            return null;
        }
        if (entry.translated == null || entry.translated.trim().isEmpty()) {
            return null;
        }
        return entry;
    }

    public void put(TMEntry entry) {
        if (entry.cache_key == null || entry.cache_key.isEmpty()) {
            return;
        }
        entries.put(entry.cache_key, entry);
    }

    public void save() throws IOException {
        if (path == null || path.isEmpty()) {
            return;
        }
        
        Path pathObj = Paths.get(path);
        Files.createDirectories(pathObj.getParent());
        
        String tmpPath = path + ".tmp";
        
        try (BufferedWriter writer = Files.newBufferedWriter(Paths.get(tmpPath))) {
            List<String> keys = new ArrayList<>(entries.keySet());
            Collections.sort(keys);
            
            for (String key : keys) {
                TMEntry entry = entries.get(key);
                try {
                    String payload = objectMapper.writeValueAsString(entry);
                    writer.write(payload);
                    writer.newLine();
                } catch (JsonProcessingException e) {
                    throw new IOException("Failed to serialize entry: " + e.getMessage(), e);
                }
            }
        }
        
        Files.move(Paths.get(tmpPath), pathObj, StandardCopyOption.REPLACE_EXISTING);
    }
}
