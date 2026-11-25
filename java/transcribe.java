// abstraction-provenance: {"artifact_sha256": "55bb97014823523b1cd5932b3f10983331d24c2425adbe852707d3707d9a03f6", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "java"}
// transcribe.sh — portiert nach java
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;

public class Transcribe {
    private static void usage() {
        System.err.println("Usage:");
        System.err.println("  transcribe.sh <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt \"hint\"] [--json]");
        System.exit(2);
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 0 || args[0].equals("-h") || args[0].equals("--help")) {
            usage();
        }

        String in = args[0];
        String model = "whisper-1";
        String out = "";
        String language = "";
        String prompt = "";
        String responseFormat = "text";

        int i = 1;
        while (i < args.length) {
            switch (args[i]) {
                case "--model":
                    if (i + 1 >= args.length) {
                        System.err.println("Missing value for --model");
                        usage();
                    }
                    model = args[i + 1];
                    i += 2;
                    break;
                case "--out":
                    if (i + 1 >= args.length) {
                        System.err.println("Missing value for --out");
                        usage();
                    }
                    out = args[i + 1];
                    i += 2;
                    break;
                case "--language":
                    if (i + 1 >= args.length) {
                        System.err.println("Missing value for --language");
                        usage();
                    }
                    language = args[i + 1];
                    i += 2;
                    break;
                case "--prompt":
                    if (i + 1 >= args.length) {
                        System.err.println("Missing value for --prompt");
                        usage();
                    }
                    prompt = args[i + 1];
                    i += 2;
                    break;
                case "--json":
                    responseFormat = "json";
                    i += 1;
                    break;
                default:
                    System.err.println("Unknown arg: " + args[i]);
                    usage();
                    break;
            }
        }

        File inFile = new File(in);
        if (!inFile.exists()) {
            System.err.println("File not found: " + in);
            System.exit(1);
        }

        String apiKey = System.getenv("OPENAI_API_KEY");
        if (apiKey == null || apiKey.isEmpty()) {
            System.err.println("Missing OPENAI_API_KEY");
            System.exit(1);
        }

        if (out.isEmpty()) {
            String base = inFile.getName().contains(".") ? 
                inFile.getName().substring(0, inFile.getName().lastIndexOf('.')) : 
                inFile.getName();
            out = responseFormat.equals("json") ? base + ".json" : base + ".txt";
        }

        // Create output directory if needed
        File outFile = new File(out);
        outFile.getParentFile().mkdirs();

        // Build API URL
        String apiBase = System.getenv("OPENAI_BASE_URL");
        if (apiBase == null || apiBase.isEmpty()) {
            apiBase = "https://api.openai.com/v1";
        }
        apiBase = apiBase.replaceAll("/$", "");
        String apiUrl = apiBase + "/audio/transcriptions";

        // Perform HTTP POST request with multipart form data
        String boundary = "----TranscribeBoundary" + System.currentTimeMillis();
        URL url = new URL(apiUrl);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setRequestProperty("Authorization", "Bearer " + apiKey);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);

        try (OutputStream os = connection.getOutputStream()) {
            PrintWriter writer = new PrintWriter(new OutputStreamWriter(os, "UTF-8"), true);

            // Write file field
            writer.append("--" + boundary).append("\r\n");
            writer.append("Content-Disposition: form-data; name=\"file\"; filename=\"" + inFile.getName() + "\"").append("\r\n");
            writer.append("Content-Type: application/octet-stream").append("\r\n\r\n");
            
            // Copy file content
            try (FileInputStream fis = new FileInputStream(inFile)) {
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = fis.read(buffer)) != -1) {
                    os.write(buffer, 0, bytesRead);
                }
            }
            writer.append("\r\n");

            // Write model field
            writer.append("--" + boundary).append("\r\n");
            writer.append("Content-Disposition: form-data; name=\"model\"").append("\r\n\r\n");
            writer.append(model).append("\r\n");

            // Write response_format field
            writer.append("--" + boundary).append("\r\n");
            writer.append("Content-Disposition: form-data; name=\"response_format\"").append("\r\n\r\n");
            writer.append(responseFormat).append("\r\n");

            // Write language field if provided
            if (!language.isEmpty()) {
                writer.append("--" + boundary).append("\r\n");
                writer.append("Content-Disposition: form-data; name=\"language\"").append("\r\n\r\n");
                writer.append(language).append("\r\n");
            }

            // Write prompt field if provided
            if (!prompt.isEmpty()) {
                writer.append("--" + boundary).append("\r\n");
                writer.append("Content-Disposition: form-data; name=\"prompt\"").append("\r\n\r\n");
                writer.append(prompt).append("\r\n");
            }

            // End of multipart data
            writer.append("--" + boundary + "--").append("\r\n");
            writer.flush();
        }

        // Read response and write to output file
        try (InputStream is = connection.getInputStream();
             FileOutputStream fos = new FileOutputStream(outFile)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = is.read(buffer)) != -1) {
                fos.write(buffer, 0, bytesRead);
            }
        } catch (IOException e) {
            System.err.println("Error reading response: " + e.getMessage());
            System.exit(1);
        }

        System.out.println(out);
    }
}
