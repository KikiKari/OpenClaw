// abstraction-provenance: {"artifact_sha256": "425b0a65fb6f1d74b0fcf0fbc0ab421d1242f02b7ed4240e328d3396db85b916", "source_sha256": "9b72cb69e140323c5b1a7fb2297d54571e6dc00329fc26e09bf42f52e6dae2ba", "target_language": "java"}
// test-contextualized-embeddings.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

public class TestContextualizedEmbeddings {
    public static void main(String[] args) throws Exception {
        String apiKey = System.getenv("PERPLEXITY_API_KEY");
        if (apiKey == null) {
            throw new IllegalStateException("PERPLEXITY_API_KEY is required");
        }

        String tmpDir = System.getenv("TMPDIR");
        if (tmpDir == null) {
            tmpDir = "/tmp";
        }
        Path outFile = Paths.get(tmpDir, "perplexity-contextualized-embeddings-test.json");

        ObjectMapper mapper = new ObjectMapper();
        
        ObjectNode payload = mapper.createObjectNode();
        ObjectNode inputArray = mapper.createArrayNode()
            .add(mapper.createArrayNode()
                .add("OpenClaw can route web search through Perplexity.")
                .add("The Perplexity MCP server exposes search and reasoning tools.")
                .add("Contextualized embeddings improve document chunk retrieval."));
        
        payload.set("input", inputArray);
        payload.put("model", "pplx-embed-context-v1-4b");

        String response = sendRequest(payload.toString(), apiKey, outFile);

        System.out.println("contextualized_embeddings_http=" + response);

        JsonNode result = mapper.readTree(Files.readAllBytes(outFile));
        ObjectNode output = mapper.createObjectNode();
        output.putArray("keys").addAll(result.fieldNames());
        
        if (result.has("model")) {
            output.set("model", result.get("model"));
        } else {
            output.putNull("model");
        }
        
        int documentCount = 0;
        if (result.has("data") && result.get("data").isArray()) {
            documentCount = result.get("data").size();
        }
        output.put("document_count", documentCount);
        
        int firstChunkCount = 0;
        if (result.has("data") && result.get("data").isArray() && result.get("data").size() > 0) {
            JsonNode firstData = result.get("data").get(0);
            if (firstData.has("data") && firstData.get("data").isArray()) {
                firstChunkCount = firstData.get("data").size();
            }
        }
        output.put("first_chunk_count", firstChunkCount);
        
        if (result.has("error")) {
            output.set("error", result.get("error"));
        } else {
            output.putNull("error");
        }
        
        System.out.println(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(output));
    }

    private static String sendRequest(String payload, String apiKey, Path outFile) throws Exception {
        URL url = new URL("https://api.perplexity.ai/v1/contextualizedembeddings");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Authorization", "Bearer " + apiKey);
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            byte[] input = payload.getBytes("utf-8");
            os.write(input, 0, input.length);
        }

        int responseCode = conn.getResponseCode();
        
        InputStream inputStream = conn.getInputStream();
        Files.copy(inputStream, outFile);
        inputStream.close();

        return String.valueOf(responseCode);
    }
}
