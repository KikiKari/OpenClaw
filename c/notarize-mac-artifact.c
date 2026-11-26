// abstraction-provenance: {"artifact_sha256": "035dae1be4a622eb8a12b05b1d3d6925e99af8c288f19a9e7809c7e423b66cfe", "source_sha256": "8efc75d62670dadcb8e085c754c26b48d241d96c51ae4f1c6742a4e894282492", "target_language": "c"}
// notarize-mac-artifact.sh — portiert nach c
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/notarize-mac-artifact.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

// Notarize a macOS artifact (zip/dmg/pkg) and optionally staple the app bundle.
//
// Usage:
//   STAPLE_APP_PATH=dist/OpenClaw.app scripts/notarize-mac-artifact <artifact>
//
// Auth (pick one):
//   NOTARYTOOL_PROFILE   keychain profile created via `xcrun notarytool store-credentials`
//   NOTARYTOOL_KEY       path to App Store Connect API key (.p8)
//   NOTARYTOOL_KEY_ID    API key ID
//   NOTARYTOOL_ISSUER    API issuer ID

int run_command(char *const argv[]) {
    pid_t pid = fork();
    if (pid == 0) {
        // Child process
        execvp(argv[0], argv);
        perror("execvp failed");
        _exit(127);
    } else if (pid > 0) {
        // Parent process
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status)) {
            return WEXITSTATUS(status);
        }
        return 1;
    } else {
        perror("fork failed");
        return 1;
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <artifact>\n", argv[0]);
        return 1;
    }

    char *artifact = argv[1];
    if (access(artifact, F_OK) != 0) {
        fprintf(stderr, "Error: artifact not found: %s\n", artifact);
        return 1;
    }

    // Check if xcrun exists
    if (access("/usr/bin/xcrun", F_OK) != 0 && access("/bin/xcrun", F_OK) != 0) {
        fprintf(stderr, "Error: xcrun not found; install Xcode command line tools.\n");
        return 1;
    }

    // Get environment variables
    char *notarytool_profile = getenv("NOTARYTOOL_PROFILE");
    char *notarytool_key = getenv("NOTARYTOOL_KEY");
    char *notarytool_key_id = getenv("NOTARYTOOL_KEY_ID");
    char *notarytool_issuer = getenv("NOTARYTOOL_ISSUER");
    char *staple_app_path = getenv("STAPLE_APP_PATH");

    // Build auth arguments
    char *auth_args[16];
    int auth_argc = 0;

    if (notarytool_profile && strlen(notarytool_profile) > 0) {
        auth_args[auth_argc++] = "--keychain-profile";
        auth_args[auth_argc++] = notarytool_profile;
    } else if (notarytool_key && strlen(notarytool_key) > 0 &&
               notarytool_key_id && strlen(notarytool_key_id) > 0 &&
               notarytool_issuer && strlen(notarytool_issuer) > 0) {
        auth_args[auth_argc++] = "--key";
        auth_args[auth_argc++] = notarytool_key;
        auth_args[auth_argc++] = "--key-id";
        auth_args[auth_argc++] = notarytool_key_id;
        auth_args[auth_argc++] = "--issuer";
        auth_args[auth_argc++] = notarytool_issuer;
    } else {
        fprintf(stderr, "Error: Notary auth missing. Set NOTARYTOOL_PROFILE or NOTARYTOOL_KEY/NOTARYTOOL_KEY_ID/NOTARYTOOL_ISSUER.\n");
        return 1;
    }
    auth_args[auth_argc] = NULL;

    // Submit for notarization
    printf("🧾 Notarizing: %s\n", artifact);

    char *submit_cmd[] = {"xcrun", "notarytool", "submit", artifact, "--wait", NULL};
    // Append auth arguments
    int base_argc = 5; // "xcrun", "notarytool", "submit", artifact, "--wait"
    for (int i = 0; i < auth_argc; i++) {
        submit_cmd[base_argc + i] = auth_args[i];
    }
    submit_cmd[base_argc + auth_argc] = NULL;

    int result = run_command(submit_cmd);
    if (result != 0) {
        return result;
    }

    // Staple if artifact is dmg or pkg
    char *extension = strrchr(artifact, '.');
    if (extension) {
        if (strcmp(extension, ".dmg") == 0 || strcmp(extension, ".pkg") == 0) {
            printf("📌 Stapling artifact: %s\n", artifact);
            
            char *staple_cmd[] = {"xcrun", "stapler", "staple", artifact, NULL};
            run_command(staple_cmd);
            
            char *validate_cmd[] = {"xcrun", "stapler", "validate", artifact, NULL};
            run_command(validate_cmd);
        }
    }

    // Staple app if STAPLE_APP_PATH is set
    if (staple_app_path && strlen(staple_app_path) > 0) {
        if (access(staple_app_path, F_OK) == 0) {
            printf("📌 Stapling app: %s\n", staple_app_path);
            
            char *staple_app_cmd[] = {"xcrun", "stapler", "staple", staple_app_path, NULL};
            run_command(staple_app_cmd);
            
            char *validate_app_cmd[] = {"xcrun", "stapler", "validate", staple_app_path, NULL};
            run_command(validate_app_cmd);
        } else {
            fprintf(stderr, "Warn: STAPLE_APP_PATH not found: %s\n", staple_app_path);
        }
    }

    printf("✅ Notarization complete\n");
    return 0;
}
