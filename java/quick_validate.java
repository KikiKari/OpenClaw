// abstraction-provenance: {"artifact_sha256": "60b04038b7eba0feb7e90813f4ce3227c35d0a18a4cbfca5d93731f2be1aa565", "source_sha256": "3e3cdceba2daa893e260551c8c5f09937f94be1153307185c7fc7c24c0896750", "target_language": "java"}
// quick_validate.py — portiert nach java
// Quelle: python, OpenClaw@gateway1:skills/skill-creator/scripts/quick_validate.py
// auch in: OpenClaw@gateway2:skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:git/skills/skill-creator/scripts/quick_validate.py
// auch in: workspace@local:skills/github-clones/openclaw/skills/skill-creator/scripts/quick_validate.py
// auch in: 1 weiteren Fundstellen
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.regex.Pattern;

/**
 * Quick validation script for skills - minimal version
 */
public class QuickValidate {
    
    private static final int MAX_SKILL_NAME_LENGTH = 64;
    private static final Pattern NAME_PATTERN = Pattern.compile("^[a-z0-9-]+$");
    
    /**
     * Extract frontmatter from content
     */
    private static String extractFrontmatter(String content) {
        String[] lines = content.split("\n");
        if (lines.length == 0 || !lines[0].trim().equals("---")) {
            return null;
        }
        for (int i = 1; i < lines.length; i++) {
            if (lines[i].trim().equals("---")) {
                StringBuilder result = new StringBuilder();
                for (int j = 1; j < i; j++) {
                    result.append(lines[j]).append("\n");
                }
                return result.toString();
            }
        }
        return null;
    }
    
    /**
     * Minimal fallback parser used when YAML library is unavailable.
     * Supports simple `key: value` mappings used by SKILL.md frontmatter.
     */
    private static Map<String, String> parseSimpleFrontmatter(String frontmatterText) {
        Map<String, String> parsed = new HashMap<>();
        String currentKey = null;
        
        for (String rawLine : frontmatterText.split("\n")) {
            String stripped = rawLine.trim();
            if (stripped.isEmpty() || stripped.startsWith("#")) {
                continue;
            }
            
            boolean isIndented = rawLine.length() > 0 && Character.isWhitespace(rawLine.charAt(0));
            if (isIndented) {
                if (currentKey == null) {
                    return null;
                }
                String currentValue = parsed.get(currentKey);
                parsed.put(currentKey, currentValue.isEmpty() ? stripped : currentValue + "\n" + stripped);
                continue;
            }
            
            if (!stripped.contains(":")) {
                return null;
            }
            
            String[] parts = stripped.split(":", 2);
            String key = parts[0].trim();
            String value = parts.length > 1 ? parts[1].trim() : "";
            
            if (key.isEmpty()) {
                return null;
            }
            
            if ((value.startsWith("\"") && value.endsWith("\"")) || 
                (value.startsWith("'") && value.endsWith("'"))) {
                value = value.substring(1, value.length() - 1);
            }
            
            parsed.put(key, value);
            currentKey = key;
        }
        
        return parsed;
    }
    
    /**
     * Basic validation of a skill
     */
    private static ValidationResult validateSkill(String skillPathStr) {
        Path skillPath = Paths.get(skillPathStr);
        Path skillMd = skillPath.resolve("SKILL.md");
        
        if (!Files.exists(skillMd)) {
            return new ValidationResult(false, "SKILL.md not found");
        }
        
        String content;
        try {
            content = Files.readString(skillMd);
        } catch (IOException e) {
            return new ValidationResult(false, "Could not read SKILL.md: " + e.getMessage());
        }
        
        String frontmatterText = extractFrontmatter(content);
        if (frontmatterText == null) {
            return new ValidationResult(false, "Invalid frontmatter format");
        }
        
        Map<String, String> frontmatter = parseSimpleFrontmatter(frontmatterText);
        if (frontmatter == null) {
            return new ValidationResult(false, 
                "Invalid YAML in frontmatter: unsupported syntax without PyYAML installed");
        }
        
        Set<String> allowedProperties = new HashSet<>(Arrays.asList(
            "name", "description", "license", "allowed-tools", "metadata"));
        
        Set<String> unexpectedKeys = new HashSet<>(frontmatter.keySet());
        unexpectedKeys.removeAll(allowedProperties);
        
        if (!unexpectedKeys.isEmpty()) {
            List<String> allowedList = new ArrayList<>(allowedProperties);
            Collections.sort(allowedList);
            List<String> unexpectedList = new ArrayList<>(unexpectedKeys);
            Collections.sort(unexpectedList);
            
            String allowed = String.join(", ", allowedList);
            String unexpected = String.join(", ", unexpectedList);
            
            return new ValidationResult(false, 
                "Unexpected key(s) in SKILL.md frontmatter: " + unexpected + 
                ". Allowed properties are: " + allowed);
        }
        
        if (!frontmatter.containsKey("name")) {
            return new ValidationResult(false, "Missing 'name' in frontmatter");
        }
        if (!frontmatter.containsKey("description")) {
            return new ValidationResult(false, "Missing 'description' in frontmatter");
        }
        
        String name = frontmatter.getOrDefault("name", "").trim();
        if (!name.isEmpty()) {
            if (!NAME_PATTERN.matcher(name).matches()) {
                return new ValidationResult(false, 
                    "Name '" + name + "' should be hyphen-case (lowercase letters, digits, and hyphens only)");
            }
            if (name.startsWith("-") || name.endsWith("-") || name.contains("--")) {
                return new ValidationResult(false, 
                    "Name '" + name + "' cannot start/end with hyphen or contain consecutive hyphens");
            }
            if (name.length() > MAX_SKILL_NAME_LENGTH) {
                return new ValidationResult(false, 
                    "Name is too long (" + name.length() + " characters). " +
                    "Maximum is " + MAX_SKILL_NAME_LENGTH + " characters.");
            }
        }
        
        String description = frontmatter.getOrDefault("description", "").trim();
        if (!description.isEmpty()) {
            if (description.contains("<") || description.contains(">")) {
                return new ValidationResult(false, "Description cannot contain angle brackets (< or >)");
            }
            if (description.length() > 1024) {
                return new ValidationResult(false, 
                    "Description is too long (" + description.length() + " characters). Maximum is 1024 characters.");
            }
        }
        
        return new ValidationResult(true, "Skill is valid!");
    }
    
    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println("Usage: java QuickValidate <skill_directory>");
            System.exit(1);
        }
        
        ValidationResult result = validateSkill(args[0]);
        System.out.println(result.message);
        System.exit(result.valid ? 0 : 1);
    }
    
    private static class ValidationResult {
        final boolean valid;
        final String message;
        
        ValidationResult(boolean valid, String message) {
            this.valid = valid;
            this.message = message;
        }
    }
}
