// abstraction-provenance: {"artifact_sha256": "3b5ad9027bbe9d6615ef6f2c5b1efc0e190e2a80afbccc0201e9d266b0965451", "source_sha256": "c451131599cab4bee1c4c62c6eac8c382c366e4cacf443d53c179c01a326a251", "target_language": "java"}
// test_voice_groups.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_voice_groups.cjs
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_voice_groups.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;
import javax.script.*;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.core.type.TypeReference;

public class TestVoiceGroups {
    static class Element {
        String tag;
        List<Element> children = new ArrayList<>();
        Map<String, String> dataset = new HashMap<>();
        String value = "";
        String label = "";
        
        void append(Element node) {
            this.children.add(node);
        }
    }

    static Element element(String tag) {
        Element el = new Element();
        el.tag = tag;
        return el;
    }

    public static void main(String[] args) throws Exception {
        // Load files
        Path basePath = Paths.get("").toAbsolutePath();
        String source = new String(Files.readAllBytes(basePath.resolve("../browser-extension/sidepanel.js")), "UTF-8");
        
        ObjectMapper mapper = new ObjectMapper();
        Map<String, Object> voiceData = mapper.readValue(
            new File(basePath.resolve("../companion-service/voice-catalog.json").toString()), 
            new TypeReference<Map<String, Object>>() {}
        );
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> voices = (List<Map<String, Object>>) voiceData.get("voices");

        // Create mock DOM elements
        Element select = element("select");

        // Create JavaScript engine context
        ScriptEngine engine = new ScriptEngineManager().getEngineByName("javascript");
        Bindings bindings = engine.createBindings();
        
        bindings.put("document", new Object() {
            public Element createElement(String tag) {
                return element(tag);
            }
        });
        
        Map<String, Element> elements = new HashMap<>();
        elements.put("speech-voice", select);
        bindings.put("elements", elements);
        bindings.put("speechVoiceName", "sherpa-de-supertonic-7");
        bindings.put("voiceCatalog", voices);
        bindings.put("clearChildren", (java.util.function.Consumer<Element>) (node) -> node.children.clear());

        engine.setBindings(bindings, ScriptContext.GLOBAL_SCOPE);

        // Extract and run relevant JS code
        String baseVoiceOrderCode = source.substring(
            source.indexOf("  const BASE_VOICE_ORDER"),
            source.indexOf("  const core =")
        );
        
        String sherpaSpeechVoicesCode = source.substring(
            source.indexOf("  function sherpaSpeechVoices"),
            source.indexOf("  async function loadSpeechVoices")
        );

        engine.eval(baseVoiceOrderCode);
        engine.eval(sherpaSpeechVoicesCode);

        // Define setSpeechVoiceOptions function in JS context
        engine.eval(
            "function setSpeechVoiceOptions(styles, voices) {" +
            "  clearChildren(elements['speech-voice']);" +
            "  const groups = {};" +
            "  for (const label of BASE_VOICE_ORDER) {" +
            "    const group = document.createElement('optgroup');" +
            "    group.label = label;" +
            "    elements['speech-voice'].append(group);" +
            "    groups[label] = group;" +
            "  }" +
            "  const ungrouped = document.createElement('optgroup');" +
            "  ungrouped.label = '';" +
            "  elements['speech-voice'].append(ungrouped);" +
            "  groups[''] = ungrouped;" +
            "  for (const voice of voices) {" +
            "    const option = document.createElement('option');" +
            "    option.textContent = voice.name;" +
            "    option.dataset.id = voice.id;" +
            "    option.value = voice.id;" +
            "    (groups[voice.group] || groups['']).append(option);" +
            "  }" +
            "  for (const style of styles) {" +
            "    const option = document.createElement('option');" +
            "    option.textContent = style.name;" +
            "    option.dataset.id = style.id;" +
            "    option.value = style.id;" +
            "    groups['Effekt Stimmen'].append(option);" +
            "  }" +
            "  for (const group of elements['speech-voice'].children) {" +
            "    if (!group.children.length && group.label !== '') {" +
            "      elements['speech-voice'].children = elements['speech-voice'].children.filter(g => g !== group);" +
            "    }" +
            "  }" +
            "  elements['speech-voice'].value = speechVoiceName;" +
            "}"
        );

        // Call setSpeechVoiceOptions
        engine.eval("setSpeechVoiceOptions([], voiceCatalog);");

        // Assertions
        String[] labels = {"Kyrillisch", "Asiatisch", "Abjad", "Indisch", "Effekt Stimmen"};
        for (String label : labels) {
            Element group = findGroup(select, label);
            if (group == null) {
                throw new AssertionError("Group not found: " + label);
            }
            if (group.children.size() < 3) {
                throw new AssertionError("Group has less than 3 children: " + label);
            }
        }

        Element effectGroup = findGroup(select, "Effekt Stimmen");
        if (effectGroup.children.size() != 5) {
            throw new AssertionError("Effekt Stimmen group should have 5 children, but has: " + effectGroup.children.size());
        }

        if (!select.value.equals("sherpa-de-supertonic-7")) {
            throw new AssertionError("Select value should be 'sherpa-de-supertonic-7', but is: " + select.value);
        }

        // Create styles list for second call
        List<Map<String, Object>> styles = new ArrayList<>();
        Map<String, Object> style = new HashMap<>();
        style.put("id", "sherpa-de-supertonic-7");
        style.put("name", "Stil 3");
        style.put("group", "");
        styles.add(style);

        bindings.put("styles", styles);
        engine.setBindings(bindings, ScriptContext.GLOBAL_SCOPE);
        engine.eval("setSpeechVoiceOptions(styles, voiceCatalog);");

        if (!select.value.equals("sherpa-de-supertonic-7")) {
            throw new AssertionError("Select value should be 'sherpa-de-supertonic-7', but is: " + select.value);
        }

        boolean foundStyle = findGroup(select, "Effekt Stimmen").children.stream()
            .anyMatch(node -> node.value.equals(select.value));
        if (!foundStyle) {
            throw new AssertionError("Selected value not found in Effekt Stimmen group");
        }

        bindings.put("speechVoiceName", "sherpa-ru-irina");
        engine.setBindings(bindings, ScriptContext.GLOBAL_SCOPE);

        // Create modified voices without group property
        List<Map<String, Object>> modifiedVoices = voices.stream().map(voice -> {
            Map<String, Object> newVoice = new HashMap<>(voice);
            newVoice.remove("group");
            return newVoice;
        }).collect(Collectors.toList());

        bindings.put("modifiedVoices", modifiedVoices);
        engine.setBindings(bindings, ScriptContext.GLOBAL_SCOPE);
        engine.eval("setSpeechVoiceOptions([], modifiedVoices);");

        if (!select.value.equals("sherpa-ru-irina")) {
            throw new AssertionError("Select value should be 'sherpa-ru-irina', but is: " + select.value);
        }

        Element kyrillischGroup = findGroup(select, "Kyrillisch");
        boolean foundRussianVoice = kyrillischGroup.children.stream()
            .anyMatch(node -> node.value.equals("sherpa-ru-irina"));
        if (!foundRussianVoice) {
            throw new AssertionError("Russian voice not found in Kyrillisch group");
        }

        System.out.println("PASS: five groups, all styles selectable, retained selection, legacy catalog fallback");
    }

    private static Element findGroup(Element select, String label) {
        return select.children.stream()
            .filter(node -> node.label.equals(label))
            .findFirst()
            .orElse(null);
    }
}
