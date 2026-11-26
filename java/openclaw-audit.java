// abstraction-provenance: {"artifact_sha256": "700a7068bd2c95e786c327224ff710fe03ae85ab032003e69f1e98e542081e76", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "java"}
// openclaw-audit.sh — portiert nach java
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// auch in: workspace@local:scripts/openclaw-audit.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

public class OpenClawAudit {
    private static final String SCRIPT_NAME = "openclaw-audit";
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter ISO_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    public static void main(String[] args) {
        try {
            Path scriptDir = Paths.get("").toAbsolutePath();
            String dateStamp = LocalDate.now().format(DATE_FORMAT);
            Path outFile = scriptDir.resolve(SCRIPT_NAME + "-" + dateStamp + ".log");

            List<String> ocCommand = Arrays.asList("openclaw", "--no-color");

            try (PrintWriter writer = new PrintWriter(new FileWriter(outFile.toFile()))) {
                writeHeader(writer, outFile.toString());
                
                runCmd(writer, "tasks audit --severity error", ocCommand, "tasks", "audit", "--severity", "error");
                runCmd(writer, "secrets audit", ocCommand, "secrets", "audit");
                runCmd(writer, "security audit", ocCommand, "security", "audit");
                runCmd(writer, "plugins doctor", ocCommand, "plugins", "doctor");
                runCmd(writer, "plugins deps", ocCommand, "plugins", "deps");
                runCmd(writer, "plugins registry", ocCommand, "plugins", "registry");
                runCmd(writer, "skills check", ocCommand, "skills", "check");
                runCmd(writer, "hooks check", ocCommand, "hooks", "check");
                runCmd(writer, "gateway status --deep", ocCommand, "gateway", "status", "--deep");
                runCmd(writer, "channels status --probe", ocCommand, "channels", "status", "--probe");
                runCmd(writer, "memory status --deep", ocCommand, "memory", "status", "--deep");
                runCmd(writer, "sessions --all-agents", ocCommand, "sessions", "--all-agents");
                runCmd(writer, "tasks list", ocCommand, "tasks", "list");
                runCmd(writer, "cron list", ocCommand, "cron", "list");

                writeFooter(writer);
            }

            System.out.println("Audit complete. Output: " + outFile.toString());

        } catch (Exception e) {
            System.err.println("Error running audit: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static void writeHeader(PrintWriter writer, String outFile) {
        writer.println("================================================================");
        writer.println("OpenClaw audit run");
        writer.println("Started:  " + LocalDateTime.now().format(ISO_FORMAT));
        try {
            writer.println("Host:     " + java.net.InetAddress.getLocalHost().getHostName());
        } catch (Exception e) {
            writer.println("Host:     unknown");
        }
        writer.println("User:     " + System.getProperty("user.name"));
        writer.println("Version:  " + getVersion());
        writer.println("Output:   " + outFile);
        writer.println("================================================================");
    }

    private static String getVersion() {
        try {
            Process process = new ProcessBuilder("openclaw", "--version").start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String version = reader.readLine();
            process.waitFor();
            return version != null ? version : "unknown";
        } catch (Exception e) {
            return "unknown";
        }
    }

    private static void runCmd(PrintWriter writer, String title, List<String> baseCmd, String... args) {
        List<String> command = new ArrayList<>(baseCmd);
        Collections.addAll(command, args);

        writer.println();
        writer.println("----------------------------------------------------------------");
        writer.println("### " + title);
        writer.print("### $ ");
        writer.println(String.join(" ", command));
        writer.println("### " + LocalDateTime.now().format(ISO_FORMAT));
        writer.println("----------------------------------------------------------------");

        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.redirectErrorStream(true);
            Process process = pb.start();
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                writer.println(line);
            }
            
            int exitCode = process.waitFor();
            writer.println("[exit: " + exitCode + "]");
        } catch (Exception e) {
            writer.println("Error executing command: " + e.getMessage());
            writer.println("[exit: 1]");
        }
    }

    private static void writeFooter(PrintWriter writer) {
        writer.println();
        writer.println("================================================================");
        writer.println("Audit complete: " + LocalDateTime.now().format(ISO_FORMAT));
        writer.println("================================================================");
    }
}
