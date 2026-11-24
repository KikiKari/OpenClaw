// abstraction-provenance: {"artifact_sha256": "f66641d35ee99c909bda5032431cb48d3a73d724cb4fc4ef169df414e43a330c", "source_sha256": "28ad3a35010164ac39fa0365d55c13b161321427a1a3be5a36fa3f7c01805c2b", "target_language": "java"}
// test-embeddings.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;
import java.util.List;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

public class TestEmbeddings {
    public static void main(String[] args) throws Exception {
        // Check for required environment variable
        String apiKey = System.getenv("PERPLEXITY_API_KEY");
        if (apiKey == null || apiKey.isEmpty()) {
            System.err.println("PERPLEXITY_API_KEY is required");
            System.exit(1);
        }

        // Create temporary file path
        String tmpDir = System.getenv("TMPDIR");
        if (tmpDir == null) {
            tmpDir = "/tmp";
        }
        Path outFile = Paths.get(tmpDir, "perplexity-embeddings-test.json");

        // Create payload
        ObjectMapper mapper = new ObjectMapper();
        ObjectNode payload = mapper.createObjectNode();
        
        ArrayNode inputArray = mapper.createArrayNode();
        inputArray.add("Scientists explore the universe driven by curiosity.");
        inputArray.add("Curiosity compels us to seek explanations, not just observations.");
        inputArray.add("Historical discoveries began with curious questions.");
        inputArray.add("The pursuit of knowledge distinguishes human curiosity from mere stimulus response.");
        inputArray.add("Philosophy examines the nature of curiosity.");
        
        payload.set("input", inputArray);
        payload.put("model", "pplx-embed-v1-4b");

        String payloadString = mapper.writeValueAsString(payload);

        // Make HTTP request
        String urlString = "https://api.perplexity.ai/v1/embeddings";
        URL url = new URL(urlString);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        
        connection.setRequestMethod("POST");
        connection.setRequestProperty("Authorization", "Bearer " + apiKey);
        connection.setRequestProperty("Content-Type", "application/json");
        connection.setDoOutput(true);
        
        try (OutputStream os = connection.getOutputStream()) {
            byte[] input = payloadString.getBytes("utf-8");
            os.write(input, 0, input.length);
        }

        // Read response
        int responseCode = connection.getResponseCode();
        StringBuilder response = new StringBuilder();
        
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(connection.getInputStream(), "utf-8"))) {
            String responseLine;
            while ((responseLine = br.readLine()) != null) {
                response.append(responseLine.trim());
            }
        }
        
        // Write response to file
        Files.write(outFile, response.toString().getBytes());

        // Output HTTP code
        System.out.println("embeddings_http=" + responseCode);

        // Process and output JSON result
        JsonNode rootNode = mapper.readTree(response.toString());
        
        ObjectNode result = mapper.createObjectNode();
        result.put("keys", mapper.createArrayNode());
        result.put("model", rootNode.has("model") ? rootNode.get("model").asText() : null);
        
        int dataLength = 0;
        if (rootNode.has("data")) {
            dataLength = rootNode.get("data").size();
        }
        result.put("item_count", dataLength);
        
        int firstDim = 0;
        if (rootNode.has("data") && rootNode.get("data").size() > 0 && 
            rootNode.get("data").get(0).has("embedding")) {
            firstDim = rootNode.get("data").get(0).get("embedding").size();
        }
        result.put("first_dim", firstDim);
        
        result.put("error", rootNode.has("error") ? rootNode.get("error").asText() : null);
        
        System.out.println(mapper.writerWithDefaultPrettyPrinter().writeValueAsString(result));
    }
}
