// abstraction-provenance: {"artifact_sha256": "f3dd6a858346c31b576100a4e27f7e22e9b18024bd9f7839600711c56a277d6c", "source_sha256": "5e833080809c70bbbe1eee5fa14d9d07d639ca0b16c37253625f4dc46ca1e64f", "target_language": "java"}
// model_usage.py — portiert nach java
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.*;
import java.time.format.*;
import java.util.*;
import java.util.stream.*;
import com.google.gson.*;

public class ModelUsage {
    private static final Gson gson = new Gson();
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    public static class ModelCost {
        String model;
        double cost;

        ModelCost(String model, double cost) {
            this.model = model;
            this.cost = cost;
        }
    }

    public static class Arguments {
        String provider = "codex";
        String mode = "current";
        String model = null;
        String input = null;
        Integer days = null;
        String format = "text";
        boolean pretty = false;

        static Arguments parse(String[] args) {
            Arguments arguments = new Arguments();
            
            for (int i = 0; i < args.length; i++) {
                switch (args[i]) {
                    case "--provider":
                        if (i + 1 < args.length) {
                            String provider = args[++i];
                            if (!List.of("codex", "claude").contains(provider)) {
                                throw new IllegalArgumentException("Invalid provider: " + provider);
                            }
                            arguments.provider = provider;
                        }
                        break;
                    case "--mode":
                        if (i + 1 < args.length) {
                            String mode = args[++i];
                            if (!List.of("current", "all").contains(mode)) {
                                throw new IllegalArgumentException("Invalid mode: " + mode);
                            }
                            arguments.mode = mode;
                        }
                        break;
                    case "--model":
                        if (i + 1 < args.length) {
                            arguments.model = args[++i];
                        }
                        break;
                    case "--input":
                        if (i + 1 < args.length) {
                            arguments.input = args[++i];
                        }
                        break;
                    case "--days":
                        if (i + 1 < args.length) {
                            try {
                                int days = Integer.parseInt(args[++i]);
                                if (days < 1) {
                                    throw new IllegalArgumentException("Days must be >= 1");
                                }
                                arguments.days = days;
                            } catch (NumberFormatException e) {
                                throw new IllegalArgumentException("Days must be an integer");
                            }
                        }
                        break;
                    case "--format":
                        if (i + 1 < args.length) {
                            String format = args[++i];
                            if (!List.of("text", "json").contains(format)) {
                                throw new IllegalArgumentException("Invalid format: " + format);
                            }
                            arguments.format = format;
                        }
                        break;
                    case "--pretty":
                        arguments.pretty = true;
                        break;
                }
            }
            
            return arguments;
        }
    }

    private static void eprint(String msg) {
        System.err.println(msg);
    }

    private static String runCodexbarCost(String provider) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder("codexbar", "cost", "--format", "json", "--provider", provider);
        Process process = pb.start();
        
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }
        
        int exitCode = process.waitFor();
        if (exitCode != 0) {
            throw new RuntimeException("codexbar cost failed (exit " + exitCode + ").");
        }
        
        return output.toString();
    }

    private static JsonObject loadPayload(String inputPath, String provider) throws IOException, InterruptedException {
        String raw;
        if (inputPath != null) {
            if ("-".equals(inputPath)) {
                Scanner scanner = new Scanner(System.in);
                raw = scanner.useDelimiter("\\A").next();
                scanner.close();
            } else {
                raw = Files.readString(Paths.get(inputPath));
            }
        } else {
            raw = runCodexbarCost(provider);
        }

        JsonElement element = JsonParser.parseString(raw);
        if (element.isJsonObject()) {
            return element.getAsJsonObject();
        }

        if (element.isJsonArray()) {
            JsonArray array = element.getAsJsonArray();
            for (JsonElement item : array) {
                if (item.isJsonObject()) {
                    JsonObject obj = item.getAsJsonObject();
                    JsonElement providerElement = obj.get("provider");
                    if (providerElement != null && providerElement.getAsString().equals(provider)) {
                        return obj;
                    }
                }
            }
            throw new RuntimeException("Provider '" + provider + "' not found in codexbar payload.");
        }

        throw new RuntimeException("Unsupported JSON input format.");
    }

    private static List<JsonObject> parseDailyEntries(JsonObject payload) {
        JsonElement dailyElement = payload.get("daily");
        if (dailyElement == null || !dailyElement.isJsonArray()) {
            return new ArrayList<>();
        }

        List<JsonObject> result = new ArrayList<>();
        JsonArray dailyArray = dailyElement.getAsJsonArray();
        for (JsonElement element : dailyArray) {
            if (element.isJsonObject()) {
                result.add(element.getAsJsonObject());
            }
        }
        return result;
    }

    private static LocalDate parseDate(String value) {
        try {
            return LocalDate.parse(value, DATE_FORMATTER);
        } catch (Exception e) {
            return null;
        }
    }

    private static List<JsonObject> filterByDays(List<JsonObject> entries, Integer days) {
        if (days == null) {
            return entries;
        }
        
        LocalDate cutoff = LocalDate.now().minusDays(days - 1);
        List<JsonObject> filtered = new ArrayList<>();
        
        for (JsonObject entry : entries) {
            JsonElement dateElement = entry.get("date");
            if (dateElement != null && dateElement.isJsonPrimitive()) {
                LocalDate parsed = parseDate(dateElement.getAsString());
                if (parsed != null && !parsed.isBefore(cutoff)) {
                    filtered.add(entry);
                }
            }
        }
        
        return filtered;
    }

    private static Map<String, Double> aggregateCosts(List<JsonObject> entries) {
        Map<String, Double> totals = new HashMap<>();
        
        for (JsonObject entry : entries) {
            JsonElement breakdownsElement = entry.get("modelBreakdowns");
            if (breakdownsElement != null && breakdownsElement.isJsonArray()) {
                JsonArray breakdowns = breakdownsElement.getAsJsonArray();
                for (JsonElement item : breakdowns) {
                    if (item.isJsonObject()) {
                        JsonObject breakdown = item.getAsJsonObject();
                        JsonElement modelElement = breakdown.get("modelName");
                        JsonElement costElement = breakdown.get("cost");
                        
                        if (modelElement != null && modelElement.isJsonPrimitive() &&
                            costElement != null && (costElement.isJsonPrimitive() && 
                            (costElement.getAsJsonPrimitive().isNumber() || costElement.getAsJsonPrimitive().isString()))) {
                            
                            String model = modelElement.getAsString();
                            double cost = costElement.getAsDouble();
                            totals.put(model, totals.getOrDefault(model, 0.0) + cost);
                        }
                    }
                }
            }
        }
        
        return totals;
    }

    private static Map.Entry<String, String> pickCurrentModel(List<JsonObject> entries) {
        if (entries.isEmpty()) {
            return null;
        }

        List<JsonObject> sortedEntries = entries.stream()
            .sorted((a, b) -> {
                String dateA = a.has("date") ? a.get("date").getAsString() : "";
                String dateB = b.has("date") ? b.get("date").getAsString() : "";
                return dateA.compareTo(dateB);
            })
            .collect(Collectors.toList());

        Collections.reverse(sortedEntries);

        for (JsonObject entry : sortedEntries) {
            JsonElement breakdownsElement = entry.get("modelBreakdowns");
            if (breakdownsElement != null && breakdownsElement.isJsonArray() && !breakdownsElement.getAsJsonArray().isEmpty()) {
                List<ModelCost> scored = new ArrayList<>();
                
                JsonArray breakdowns = breakdownsElement.getAsJsonArray();
                for (JsonElement item : breakdowns) {
                    if (item.isJsonObject()) {
                        JsonObject breakdown = item.getAsJsonObject();
                        JsonElement modelElement = breakdown.get("modelName");
                        JsonElement costElement = breakdown.get("cost");
                        
                        if (modelElement != null && modelElement.isJsonPrimitive() &&
                            costElement != null && costElement.isJsonPrimitive()) {
                            
                            String model = modelElement.getAsString();
                            double cost = costElement.getAsDouble();
                            scored.add(new ModelCost(model, cost));
                        }
                    }
                }
                
                if (!scored.isEmpty()) {
                    scored.sort((a, b) -> Double.compare(b.cost, a.cost));
                    JsonElement dateElement = entry.get("date");
                    String dateStr = dateElement != null && dateElement.isJsonPrimitive() ? dateElement.getAsString() : null;
                    return new AbstractMap.SimpleEntry<>(scored.get(0).model, dateStr);
                }
            }
            
            JsonElement modelsUsedElement = entry.get("modelsUsed");
            if (modelsUsedElement != null && modelsUsedElement.isJsonArray() && !modelsUsedElement.getAsJsonArray().isEmpty()) {
                JsonArray modelsUsed = modelsUsedElement.getAsJsonArray();
                JsonElement lastElement = modelsUsed.get(modelsUsed.size() - 1);
                if (lastElement.isJsonPrimitive()) {
                    JsonElement dateElement = entry.get("date");
                    String dateStr = dateElement != null && dateElement.isJsonPrimitive() ? dateElement.getAsString() : null;
                    return new AbstractMap.SimpleEntry<>(lastElement.getAsString(), dateStr);
                }
            }
        }
        
        return null;
    }

    private static String usd(Double value) {
        if (value == null) {
            return "—";
        }
        return String.format("$%,.2f", value);
    }

    private static Map.Entry<String, Double> latestDayCost(List<JsonObject> entries, String model) {
        if (entries.isEmpty()) {
            return new AbstractMap.SimpleEntry<>(null, null);
        }

        List<JsonObject> sortedEntries = entries.stream()
            .sorted((a, b) -> {
                String dateA = a.has("date") ? a.get("date").getAsString() : "";
                String dateB = b.has("date") ? b.get("date").getAsString() : "";
                return dateA.compareTo(dateB);
            })
            .collect(Collectors.toList());

        Collections.reverse(sortedEntries);

        for (JsonObject entry : sortedEntries) {
            JsonElement breakdownsElement = entry.get("modelBreakdowns");
            if (breakdownsElement != null && breakdownsElement.isJsonArray()) {
                JsonArray breakdowns = breakdownsElement.getAsJsonArray();
                for (JsonElement item : breakdowns) {
                    if (item.isJsonObject()) {
                        JsonObject breakdown = item.getAsJsonObject();
                        JsonElement modelNameElement = breakdown.get("modelName");
                        if (modelNameElement != null && modelNameElement.getAsString().equals(model)) {
                            JsonElement costElement = breakdown.get("cost");
                            Double cost = null;
                            if (costElement != null && costElement.isJsonPrimitive()) {
                                cost = costElement.getAsDouble();
                            }
                            JsonElement dateElement = entry.get("date");
                            String dateStr = dateElement != null && dateElement.isJsonPrimitive() ? dateElement.getAsString() : null;
                            return new AbstractMap.SimpleEntry<>(dateStr, cost);
                        }
                    }
                }
            }
        }
        
        return new AbstractMap.SimpleEntry<>(null, null);
    }

    private static String renderTextCurrent(
        String provider,
        String model,
        String latestDate,
        Double totalCost,
        Double latestCost,
        String latestCostDate,
        int entryCount
    ) {
        List<String> lines = new ArrayList<>();
        lines.add("Provider: " + provider);
        lines.add("Current model: " + model);
        if (latestDate != null) {
            lines.add("Latest model date: " + latestDate);
        }
        lines.add("Total cost (rows): " + usd(totalCost));
        if (latestCostDate != null) {
            lines.add("Latest day cost: " + usd(latestCost) + " (" + latestCostDate + ")");
        }
        lines.add("Daily rows: " + entryCount);
        return String.join("\n", lines);
    }

    private static String renderTextAll(String provider, Map<String, Double> totals) {
        List<String> lines = new ArrayList<>();
        lines.add("Provider: " + provider);
        lines.add("Models:");
        
        List<Map.Entry<String, Double>> sortedTotals = new ArrayList<>(totals.entrySet());
        sortedTotals.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));
        
        for (Map.Entry<String, Double> entry : sortedTotals) {
            lines.add("- " + entry.getKey() + ": " + usd(entry.getValue()));
        }
        
        return String.join("\n", lines);
    }

    private static JsonObject buildJsonCurrent(
        String provider,
        String model,
        String latestDate,
        Double totalCost,
        Double latestCost,
        String latestCostDate,
        int entryCount
    ) {
        JsonObject obj = new JsonObject();
        obj.addProperty("provider", provider);
        obj.addProperty("mode", "current");
        obj.addProperty("model", model);
        if (latestDate != null) {
            obj.addProperty("latestModelDate", latestDate);
        }
        if (totalCost != null) {
            obj.addProperty("totalCostUSD", totalCost);
        }
        if (latestCost != null) {
            obj.addProperty("latestDayCostUSD", latestCost);
        }
        if (latestCostDate != null) {
            obj.addProperty("latestDayCostDate", latestCostDate);
        }
        obj.addProperty("dailyRowCount", entryCount);
        return obj;
    }

    private static JsonObject buildJsonAll(String provider, Map<String, Double> totals) {
        JsonObject obj = new JsonObject();
        obj.addProperty("provider", provider);
        obj.addProperty("mode", "all");
        
        JsonArray modelsArray = new JsonArray();
        List<Map.Entry<String, Double>> sortedTotals = new ArrayList<>(totals.entrySet());
        sortedTotals.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));
        
        for (Map.Entry<String, Double> entry : sortedTotals) {
            JsonObject modelObj = new JsonObject();
            modelObj.addProperty("model", entry.getKey());
            modelObj.addProperty("totalCostUSD", entry.getValue());
            modelsArray.add(modelObj);
        }
        
        obj.add("models", modelsArray);
        return obj;
    }

    public static int main(String[] args) {
        Arguments arguments;
        try {
            arguments = Arguments.parse(args);
        } catch (IllegalArgumentException e) {
            eprint(e.getMessage());
            return 1;
        }

        JsonObject payload;
        try {
            payload = loadPayload(arguments.input, arguments.provider);
        } catch (Exception e) {
            eprint(e.getMessage());
            return 1;
        }

        List<JsonObject> entries = parseDailyEntries(payload);
        entries = filterByDays(entries, arguments.days);

        if ("current".equals(arguments.mode)) {
            String model = arguments.model;
            String latestDate = null;
            
            if (model == null) {
                Map.Entry<String, String> currentModel = pickCurrentModel(entries);
                if (currentModel != null) {
                    model = currentModel.getKey();
                    latestDate = currentModel.getValue();
                }
            }
            
            if (model == null) {
                eprint("No model data found in codexbar cost payload.");
                return 2;
            }
            
            Map<String, Double> totals = aggregateCosts(entries);
            Double totalCost = totals.get(model);
            Map.Entry<String, Double> latestCostEntry = latestDayCost(entries, model);
            String latestCostDate = latestCostEntry.getKey();
            Double latestCost = latestCostEntry.getValue();

            if ("json".equals(arguments.format)) {
                JsonObject payloadOut = buildJsonCurrent(
                    arguments.provider,
                    model,
                    latestDate,
                    totalCost,
                    latestCost,
                    latestCostDate,
                    entries.size()
                );
                
                Gson gsonOutput = arguments.pretty ? new GsonBuilder().setPrettyPrinting().create() : new Gson();
                System.out.println(gsonOutput.toJson(payloadOut));
            } else {
                System.out.println(renderTextCurrent(
                    arguments.provider,
                    model,
                    latestDate,
                    totalCost,
                    latestCost,
                    latestCostDate,
                    entries.size()
                ));
            }
            return 0;
        }

        Map<String, Double> totals = aggregateCosts(entries);
        if (totals.isEmpty()) {
            eprint("No model breakdowns found in codexbar cost payload.");
            return 2;
        }

        if ("json".equals(arguments.format)) {
            JsonObject payloadOut = buildJsonAll(arguments.provider, totals);
            Gson gsonOutput = arguments.pretty ? new GsonBuilder().setPrettyPrinting().create() : new Gson();
            System.out.println(gsonOutput.toJson(payloadOut));
        } else {
            System.out.println(renderTextAll(arguments.provider, totals));
        }
        
        return 0;
    }

    public static void main(String[] args) {
        System.exit(main(args));
    }
}
