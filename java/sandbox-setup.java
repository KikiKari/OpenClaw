// abstraction-provenance: {"artifact_sha256": "ff4aeac530d52c5845d050152c6f99b9437fb3f867726973af478f31d9fad989", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "java"}
// sandbox-setup.sh — portiert nach java
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class SandboxSetup {
    private static boolean SKIP_HEAVY = false;
    private static boolean APT_UPDATED = false;
    private static String HOME = System.getProperty("user.home");

    public static void main(String[] args) {
        if (args.length > 0 && "--skip-heavy".equals(args[0])) {
            SKIP_HEAVY = true;
        }

        try {
            // Change to parent directory
            Path currentDir = Paths.get("").toAbsolutePath();
            Path parentDir = currentDir.getParent();
            if (parentDir != null) {
                System.setProperty("user.dir", parentDir.toString());
            }

            log("Node-Dependencies (npm install) …");
            if (!runCommand("npm", "install", "--no-audit", "--no-fund")) {
                log("FEHLER: npm install fehlgeschlagen");
                System.exit(1);
            }

            log("Python-Dependencies (backend/requirements-dev.txt) …");
            if (!runCommand("pip3", "install", "--quiet", "-r", "backend/requirements-dev.txt")) {
                log("FEHLER: pip install fehlgeschlagen");
                System.exit(1);
            }

            aptInstall("ffmpeg", "ffmpeg");
            aptInstall("imagemagick", "convert");
            if (!SKIP_HEAVY) {
                aptInstall("gimp", "gimp");
                aptInstall("blender", "blender");
            }

            aptInstall("xvfb", "Xvfb");
            aptInstall("x11-utils", "xdpyinfo");
            aptInstall("libnss3-tools", "certutil");

            if (!commandExists("google-chrome-stable")) {
                log("Installiere Google Chrome Stable …");
                String tmpDeb = "/tmp/google-chrome-stable_current_amd64.deb";
                if (runCommand("curl", "-fsSL", "-o", tmpDeb, "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")) {
                    if (runCommand("sudo", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", "-qq", tmpDeb)) {
                        String versionOutput = runAndGetOutput("google-chrome-stable", "--version");
                        if (versionOutput != null) {
                            log("Chrome installiert: " + versionOutput.trim());
                        }
                    } else {
                        log("WARNUNG: Chrome-Installation fehlgeschlagen");
                    }
                } else {
                    log("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)");
                }
                new File(tmpDeb).delete();
            }

            // Proxy-CA in Chromes NSS-DB
            if (commandExists("certutil") && new File("/root/.ccr/ca-bundle.crt").exists()) {
                new File(HOME + "/.pki/nssdb").mkdirs();
                runCommand("certutil", "-d", "sql:" + HOME + "/.pki/nssdb", "-N", "--empty-password");
                String certList = runAndGetOutput("certutil", "-d", "sql:" + HOME + "/.pki/nssdb", "-L");
                if (certList == null || !certList.contains("ccr-proxy-ca")) {
                    if (runCommand("certutil", "-d", "sql:" + HOME + "/.pki/nssdb", "-A", "-t", "C,,", "-n", "ccr-proxy-ca", "-i", "/root/.ccr/ca-bundle.crt")) {
                        log("Proxy-CA in Chrome-NSS-Store importiert");
                    }
                }
            }

            // Playwright installation
            if (new File("node_modules").exists() && !new File("node_modules/playwright").exists()) {
                if (commandExists("npm")) {
                    if (runCommand("npm", "install", "--no-audit", "--no-fund", "--no-save", "playwright")) {
                        log("Playwright (Node) installiert");
                    } else {
                        log("WARNUNG: Playwright-npm-Install fehlgeschlagen");
                    }
                }
            }

            // Git configuration
            if (runCommand("git", "rev-parse", "--is-inside-work-tree")) {
                String pwd = System.getProperty("user.dir");
                runCommand("git", "config", "credential.https://x-access-token@github.com.helper", "!" + pwd + "/.claude/git-credential-pat.sh");
                runCommand("git", "remote", "set-url", "--push", "origin", "https://x-access-token@github.com/KikiKari/Onboarding.git");
                log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)");
            }

            // Docker daemon
            if (commandExists("dockerd") && !runCommand("docker", "info")) {
                log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …");
                new File("/etc/docker").mkdirs();
                File daemonFile = new File("/etc/docker/daemon.json");
                if (!daemonFile.exists()) {
                    Files.write(daemonFile.toPath(), "{\"registry-mirrors\":[\"https://mirror.gcr.io\"]}".getBytes());
                }
                
                ProcessBuilder pb = new ProcessBuilder("dockerd");
                pb.redirectOutput(new File("/tmp/dockerd.log"));
                pb.redirectError(new File("/tmp/dockerd.log"));
                pb.start();

                for (int i = 0; i < 15; i++) {
                    if (runCommand("docker", "info")) {
                        break;
                    }
                    Thread.sleep(1000);
                }
                
                if (runCommand("docker", "info")) {
                    log("Docker-Daemon laeuft");
                } else {
                    log("WARNUNG: Docker-Daemon nicht gestartet");
                }
            }

            log("Fertig. Versionen:");
            String nodeVersion = runAndGetOutput("node", "--version");
            if (nodeVersion != null) {
                log("  node " + nodeVersion.trim());
            }
            
            String pythonVersion = runAndGetOutput("python3", "--version");
            if (pythonVersion != null) {
                log("  " + pythonVersion.trim());
            }
            
            if (commandExists("ffmpeg")) {
                String ffmpegVersion = runAndGetOutput("ffmpeg", "-version");
                if (ffmpegVersion != null) {
                    String[] lines = ffmpegVersion.split("\n");
                    if (lines.length > 0) {
                        log("  " + lines[0].trim());
                    }
                }
            }
            
            if (commandExists("convert")) {
                String convertVersion = runAndGetOutput("convert", "-version");
                if (convertVersion != null) {
                    String[] lines = convertVersion.split("\n");
                    if (lines.length > 0) {
                        log("  " + lines[0].trim());
                    }
                }
            }
            
            if (commandExists("gimp") && !SKIP_HEAVY) {
                String gimpVersion = runAndGetOutput("gimp", "--version");
                if (gimpVersion != null) {
                    String[] lines = gimpVersion.split("\n");
                    if (lines.length > 0) {
                        log("  " + lines[0].trim());
                    }
                }
            }
            
            if (commandExists("blender") && !SKIP_HEAVY) {
                String blenderVersion = runAndGetOutput("blender", "--version");
                if (blenderVersion != null) {
                    String[] lines = blenderVersion.split("\n");
                    if (lines.length > 0) {
                        log("  " + lines[0].trim());
                    }
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static void log(String message) {
        System.out.println("[sandbox-setup] " + message);
    }

    private static boolean commandExists(String command) {
        try {
            ProcessBuilder pb = new ProcessBuilder("which", command);
            Process process = pb.start();
            return process.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    private static boolean runCommand(String... command) {
        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.inheritIO();
            Process process = pb.start();
            return process.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    private static String runAndGetOutput(String... command) {
        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            Process process = pb.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
            process.waitFor();
            return output.toString();
        } catch (Exception e) {
            return null;
        }
    }

    private static void aptInstall(String pkg, String bin) {
        if (commandExists(bin)) {
            String versionInfo = runAndGetOutput(bin, "-version");
            if (versionInfo == null || versionInfo.isEmpty()) {
                versionInfo = runAndGetOutput(bin, "--version");
            }
            if (versionInfo != null && !versionInfo.isEmpty()) {
                String[] lines = versionInfo.split("\n");
                log(pkg + " bereits vorhanden (" + (lines.length > 0 ? lines[0] : "") + ")");
            } else {
                log(pkg + " bereits vorhanden");
            }
            return;
        }
        
        log("Installiere " + pkg + " …");
        if (!APT_UPDATED) {
            if (runCommand("sudo", "DEBIAN_FRONTEND=noninteractive", "apt-get", "update", "-qq")) {
                APT_UPDATED = true;
            }
        }
        
        if (!runCommand("sudo", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", "-qq", pkg)) {
            log("WARNUNG: " + pkg + " konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt");
        }
    }
}
