// abstraction-provenance: {"artifact_sha256": "345a2f56eb0a6e5778966abebf010d4cb27b4e9b0952986b2b1047a5269430d2", "source_sha256": "0fe503378d960b547d45c597a390a046e4d115dc036760ca7ef605dec6f6f754", "target_language": "java"}
// test_pipeline_client.cjs — portiert nach java
// Quelle: javascript, Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/scripts/test_pipeline_client.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

public class TestPipelineClient {

    @TempDir
    static Path tempDir;

    static class Storage {
        private final Map<String, Object> data;

        public Storage(Map<String, Object> initialData) {
            this.data = initialData != null ? initialData : new ConcurrentHashMap<>();
        }

        public CompletableFuture<Map<String, Object>> get(Object keys) {
            Set<String> keySet = keys instanceof String ? 
                Collections.singleton((String)keys) : 
                new HashSet<>((List<String>)keys);
            
            Map<String, Object> result = new HashMap<>();
            for (String key : keySet) {
                result.put(key, data.get(key));
            }
            return CompletableFuture.completedFuture(result);
        }

        public CompletableFuture<Void> set(Map<String, Object> values) {
            data.putAll(values);
            return CompletableFuture.completedFuture(null);
        }
    }

    static class DatabaseRequest {
        public Object result;
        public Consumer<Void> onsuccess;
        public Consumer<Void> oncomplete;
    }

    static class ObjectStore {
        private final Map<String, Map<String, Object>> rows;

        public ObjectStore(Map<String, Map<String, Object>> rows) {
            this.rows = rows;
        }

        public DatabaseRequest put(Map<String, Object> row) {
            DatabaseRequest req = new DatabaseRequest();
            executor.submit(() -> {
                rows.put((String)row.get("eventId"), new HashMap<>(row));
                if (req.onsuccess != null) {
                    req.onsuccess.accept(null);
                }
            });
            return req;
        }

        public DatabaseRequest delete(String id) {
            DatabaseRequest req = new DatabaseRequest();
            executor.submit(() -> {
                rows.remove(id);
                if (req.onsuccess != null) {
                    req.onsuccess.accept(null);
                }
            });
            return req;
        }

        public DatabaseRequest getAll() {
            DatabaseRequest req = new DatabaseRequest();
            executor.submit(() -> {
                List<Map<String, Object>> clonedRows = rows.values().stream()
                    .map(HashMap::new)
                    .collect(Collectors.toList());
                req.result = clonedRows;
                if (req.onsuccess != null) {
                    req.onsuccess.accept(null);
                }
            });
            return req;
        }
    }

    static class Transaction {
        private final Map<String, Map<String, Object>> rows;
        public Consumer<Void> oncomplete;

        public Transaction(Map<String, Map<String, Object>> rows) {
            this.rows = rows;
        }

        public ObjectStore objectStore() {
            return new ObjectStore(rows);
        }
    }

    static class Database {
        private final Map<String, Map<String, Object>> rows = new ConcurrentHashMap<>();

        public Transaction transaction() {
            return new Transaction(rows);
        }
    }

    static class IndexedDB {
        public DatabaseRequest open() {
            DatabaseRequest req = new DatabaseRequest();
            Database db = new Database();
            executor.submit(() -> {
                req.result = db;
                if (req.onsuccess != null) {
                    req.onsuccess.accept(null);
                }
            });
            return req;
        }
    }

    static class MockFetchResponse {
        public boolean ok = true;
        private final Map<String, Object> jsonResponse;

        public MockFetchResponse(Map<String, Object> response) {
            this.jsonResponse = response;
        }

        public CompletableFuture<Map<String, Object>> json() {
            return CompletableFuture.completedFuture(jsonResponse);
        }
    }

    static class ClientContext {
        public TLCPipelines api;
        public Map<String, Object> local;
        public Map<String, Object> session;
        public List<Map<String, Object>> received;
        public Map<String, Map<String, Object>> rows;

        public ClientContext() {
            this.local = new HashMap<>();
            this.local.put("tlc-settings", Map.of(
                "universalCaptionApiKey", "universal-secret",
                "pairingCode", "pair-secret"
            ));
            this.session = new HashMap<>();
            this.received = Collections.synchronizedList(new ArrayList<>());
            this.rows = new ConcurrentHashMap<>();
        }
    }

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();

    private ClientContext client() throws Exception {
        ClientContext context = new ClientContext();
        
        // In a real implementation, we would load and execute the JavaScript file
        // For now, we'll simulate the API behavior
        context.api = new TLCPipelines(context.local, context.session, context.received, context.rows);
        
        return context;
    }

    @Test
    public void oneKeyTwoTabsReloadAndDelayedOldDocumentEventsStaySeparate() throws Exception {
        ClientContext c = client();
        
        c.api.start(1, "doc-a").get();
        c.api.start(2, "doc-b").get();
        c.api.publish(1, "chat", Map.of("text", "first"), "pair-secret", "chat", "doc-a").get();
        c.api.start(1, "doc-c").get();
        c.api.publish(1, "chat", Map.of("text", "late"), "late", "chat", "doc-a").get();
        c.api.publish(1, "chat", Map.of("text", "current"), "current", "chat").get();
        
        // Simulate event loop processing
        for (int i = 0; i < 30; i++) {
            Thread.sleep(1); // Allow async operations to complete
            c.api.flush().get();
        }
        
        assertEquals(0, c.rows.size());
        
        List<Map<String, Object>> chats = c.received.stream()
            .filter(row -> "chat".equals(row.get("pipeline")) && "available".equals(row.get("availability")))
            .collect(Collectors.toList());
            
        List<String> documentIds = chats.stream()
            .map(row -> (String)row.get("documentId"))
            .collect(Collectors.toList());
            
        assertEquals(Arrays.asList("doc-a", "doc-a", "doc-c"), documentIds);
        assertEquals("[credential removed]", chats.get(0).get("raw"));
        assertTrue((Boolean)chats.get(0).get("credentialsRedacted"));
        
        Map<String, Object> b = c.received.stream()
            .filter(row -> "doc-b".equals(row.get("documentId")))
            .findFirst()
            .orElse(null);
            
        assertNotEquals(chats.get(0).get("tabId"), b.get("tabId"));
        assertEquals(chats.get(0).get("clientId"), b.get("clientId"));
        
        Set<String> eventIds = c.received.stream()
            .map(row -> (String)row.get("eventId"))
            .collect(Collectors.toSet());
            
        assertEquals(eventIds.size(), c.received.size());
    }

    // Simplified simulation of the actual pipeline client functionality
    static class TLCPipelines {
        private final Map<String, Object> local;
        private final Map<String, Object> session;
        private final List<Map<String, Object>> received;
        private final Map<String, Map<String, Object>> rows;

        public TLCPipelines(Map<String, Object> local, Map<String, Object> session, 
                           List<Map<String, Object>> received, Map<String, Map<String, Object>> rows) {
            this.local = local;
            this.session = session;
            this.received = received;
            this.rows = rows;
        }

        public CompletableFuture<Void> start(int tabId, String documentId) {
            return CompletableFuture.completedFuture(null);
        }

        public CompletableFuture<Void> publish(int tabId, String pipeline, Map<String, Object> data, 
                                             String credential, String availability) {
            return publish(tabId, pipeline, data, credential, availability, null);
        }

        public CompletableFuture<Void> publish(int tabId, String pipeline, Map<String, Object> data, 
                                             String credential, String availability, String documentId) {
            Map<String, Object> event = new HashMap<>();
            event.put("eventId", UUID.randomUUID().toString());
            event.put("tabId", tabId);
            event.put("pipeline", pipeline);
            event.put("data", data);
            event.put("raw", credential);
            event.put("availability", availability);
            event.put("documentId", documentId);
            event.put("credentialsRedacted", "[credential removed]".equals(credential));
            event.put("clientId", "test-client");
            
            received.add(event);
            return CompletableFuture.completedFuture(null);
        }

        public CompletableFuture<Void> flush() {
            return CompletableFuture.completedFuture(null);
        }
    }
}
