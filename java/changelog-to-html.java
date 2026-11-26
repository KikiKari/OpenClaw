// abstraction-provenance: {"artifact_sha256": "a3f979c977644202389d629f9cf459692d633a2ced51db8dec0a168887a7c392", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "java"}
// changelog-to-html.sh — portiert nach java
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;

public class ChangelogToHtml {
    private static final String VERSION_PATTERN = "^##\\s+%s(?:\\s+.*)?$";
    private static final Pattern HEADING_5 = Pattern.compile("^##### (.*)$");
    private static final Pattern HEADING_4 = Pattern.compile("^#### (.*)$");
    private static final Pattern HEADING_3 = Pattern.compile("^### (.*)$");
    private static final Pattern HEADING_2 = Pattern.compile("^## (.*)$");
    private static final Pattern LIST_ITEM_BOLD = Pattern.compile("^- \\*\\*([^*]*)\\*\\*(.*)$");
    private static final Pattern LIST_ITEM = Pattern.compile("^- ([^*].*)$");
    private static final Pattern BOLD = Pattern.compile("\\*\\*([^*]+)\\*\\*");
    private static final Pattern CODE = Pattern.compile("`([^`]*)`");
    private static final Pattern LINK = Pattern.compile("\\[([^\\]]*)\\]\\(([^)]*)\\)");

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java ChangelogToHtml <version> [changelog_file]");
            System.exit(1);
        }

        String version = args[0];
        String changelogFile = args.length > 1 ? args[1] : findChangelogFile();

        if (changelogFile == null || !Files.exists(Paths.get(changelogFile))) {
            System.err.println("Error: Changelog file '" + (changelogFile != null ? changelogFile : "CHANGELOG.md") + "' not found");
            System.exit(1);
        }

        try {
            String versionContent = extractVersionSection(version, changelogFile);
            if (versionContent.isEmpty()) {
                System.out.println("<h2>OpenClaw " + version + "</h2>");
                System.out.println("<p>Latest OpenClaw update.</p>");
                System.out.println("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>");
                return;
            }

            System.out.println("<h2>OpenClaw " + version + "</h2>");

            boolean inList = false;
            String[] lines = versionContent.split("\n");
            for (String line : lines) {
                line = line.trim();
                if (line.startsWith("-")) {
                    if (!inList) {
                        System.out.println("<ul>");
                        inList = true;
                    }
                    System.out.println(markdownToHtml(line));
                } else {
                    if (inList) {
                        System.out.println("</ul>");
                        inList = false;
                    }
                    if (!line.isEmpty()) {
                        System.out.println(markdownToHtml(line));
                    }
                }
            }

            if (inList) {
                System.out.println("</ul>");
            }

            System.out.println("<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>");

        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String findChangelogFile() {
        String scriptDir = new File(ChangelogToHtml.class.getProtectionDomain().getCodeSource().getLocation().getPath()).getParent();
        String[] paths = {
            scriptDir + "/../CHANGELOG.md",
            "CHANGELOG.md",
            "../CHANGELOG.md"
        };

        for (String path : paths) {
            if (Files.exists(Paths.get(path))) {
                return path;
            }
        }
        return null;
    }

    private static String extractVersionSection(String version, String file) throws IOException {
        List<String> lines = Files.readAllLines(Paths.get(file));
        boolean found = false;
        StringBuilder result = new StringBuilder();
        String versionPattern = String.format(VERSION_PATTERN, Pattern.quote(version));

        for (String line : lines) {
            if (line.startsWith("## ")) {
                if (line.matches(versionPattern)) {
                    found = true;
                    continue;
                }
                if (found) {
                    break;
                }
            } else if (found) {
                result.append(line).append("\n");
            }
        }

        return result.toString().trim();
    }

    private static String markdownToHtml(String text) {
        // Handle headings
        text = HEADING_5.matcher(text).replaceAll("<h5>$1</h5>");
        text = HEADING_4.matcher(text).replaceAll("<h4>$1</h4>");
        text = HEADING_3.matcher(text).replaceAll("<h3>$1</h3>");
        text = HEADING_2.matcher(text).replaceAll("<h2>$1</h2>");
        
        // Handle list items
        text = LIST_ITEM_BOLD.matcher(text).replaceAll("<li><strong>$1</strong>$2</li>");
        text = LIST_ITEM.matcher(text).replaceAll("<li>$1</li>");
        
        // Handle inline formatting
        text = BOLD.matcher(text).replaceAll("<strong>$1</strong>");
        text = CODE.matcher(text).replaceAll("<code>$1</code>");
        text = LINK.matcher(text).replaceAll("<a href=\"$2\">$1</a>");
        
        return text;
    }
}
