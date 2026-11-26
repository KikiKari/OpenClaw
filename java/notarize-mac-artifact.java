// abstraction-provenance: {"artifact_sha256": "b449ad1c750b9fb99eea60f1c92c89864238cd6b2f5eef680108d51324f86de9", "source_sha256": "8efc75d62670dadcb8e085c754c26b48d241d96c51ae4f1c6742a4e894282492", "target_language": "java"}
// notarize-mac-artifact.sh — portiert nach java
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/notarize-mac-artifact.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

public class NotarizeMacArtifact {

    // Notarize a macOS artifact (zip/dmg/pkg) and optionally staple the app bundle.
    //
    // Usage:
    //   STAPLE_APP_PATH=dist/OpenClaw.app java NotarizeMacArtifact <artifact>
    //
    // Auth (pick one):
    //   NOTARYTOOL_PROFILE   keychain profile created via `xcrun notarytool store-credentials`
    //   NOTARYTOOL_KEY       path to App Store Connect API key (.p8)
    //   NOTARYTOOL_KEY_ID    API key ID
    //   NOTARYTOOL_ISSUER    API issuer ID

    public static void main(String[] args) {
        String artifact = args.length > 0 ? args[0] : "";
        String stapleAppPath = System.getenv("STAPLE_APP_PATH") != null ? System.getenv("STAPLE_APP_PATH") : "";

        if (artifact.isEmpty()) {
            System.err.println("Usage: java NotarizeMacArtifact <artifact>");
            System.exit(1);
        }

        File artifactFile = new File(artifact);
        if (!artifactFile.exists()) {
            System.err.println("Error: artifact not found: " + artifact);
            System.exit(1);
        }

        try {
            ProcessBuilder pb = new ProcessBuilder("which", "xcrun");
            Process process = pb.start();
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                System.err.println("Error: xcrun not found; install Xcode command line tools.");
                System.exit(1);
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("Error checking for xcrun: " + e.getMessage());
            System.exit(1);
        }

        List<String> authArgs = new ArrayList<>();
        String notarytoolProfile = System.getenv("NOTARYTOOL_PROFILE");
        String notarytoolKey = System.getenv("NOTARYTOOL_KEY");
        String notarytoolKeyId = System.getenv("NOTARYTOOL_KEY_ID");
        String notarytoolIssuer = System.getenv("NOTARYTOOL_ISSUER");

        if (notarytoolProfile != null && !notarytoolProfile.isEmpty()) {
            authArgs.add("--keychain-profile");
            authArgs.add(notarytoolProfile);
        } else if (notarytoolKey != null && !notarytoolKey.isEmpty() &&
                   notarytoolKeyId != null && !notarytoolKeyId.isEmpty() &&
                   notarytoolIssuer != null && !notarytoolIssuer.isEmpty()) {
            authArgs.add("--key");
            authArgs.add(notarytoolKey);
            authArgs.add("--key-id");
            authArgs.add(notarytoolKeyId);
            authArgs.add("--issuer");
            authArgs.add(notarytoolIssuer);
        } else {
            System.err.println("Error: Notary auth missing. Set NOTARYTOOL_PROFILE or NOTARYTOOL_KEY/NOTARYTOOL_KEY_ID/NOTARYTOOL_ISSUER.");
            System.exit(1);
        }

        System.out.println("🧾 Notarizing: " + artifact);

        List<String> notaryCommand = new ArrayList<>();
        notaryCommand.add("xcrun");
        notaryCommand.add("notarytool");
        notaryCommand.add("submit");
        notaryCommand.add(artifact);
        notaryCommand.addAll(authArgs);
        notaryCommand.add("--wait");

        try {
            ProcessBuilder pb = new ProcessBuilder(notaryCommand);
            Process process = pb.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println(line);
            }
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                System.err.println("Notarization failed with exit code: " + exitCode);
                System.exit(exitCode);
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("Error during notarization: " + e.getMessage());
            System.exit(1);
        }

        if (artifact.endsWith(".dmg") || artifact.endsWith(".pkg")) {
            System.out.println("📌 Stapling artifact: " + artifact);
            runStaplerCommand("staple", artifact);
            runStaplerCommand("validate", artifact);
        }

        if (!stapleAppPath.isEmpty()) {
            File stapleAppFile = new File(stapleAppPath);
            if (stapleAppFile.isDirectory()) {
                System.out.println("📌 Stapling app: " + stapleAppPath);
                runStaplerCommand("staple", stapleAppPath);
                runStaplerCommand("validate", stapleAppPath);
            } else {
                System.err.println("Warn: STAPLE_APP_PATH not found: " + stapleAppPath);
            }
        }

        System.out.println("✅ Notarization complete");
    }

    private static void runStaplerCommand(String command, String path) {
        try {
            ProcessBuilder pb = new ProcessBuilder("xcrun", "stapler", command, path);
            Process process = pb.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println(line);
            }
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                System.err.println("Stapler " + command + " failed with exit code: " + exitCode);
                System.exit(exitCode);
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("Error running stapler " + command + ": " + e.getMessage());
            System.exit(1);
        }
    }
}
