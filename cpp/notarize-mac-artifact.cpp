// abstraction-provenance: {"artifact_sha256": "2b0152f9c7dd22d2fea61ae1bfb21b476ee846d3afa7b33cd45f0673b726a09d", "source_sha256": "8efc75d62670dadcb8e085c754c26b48d241d96c51ae4f1c6742a4e894282492", "target_language": "cpp"}
// notarize-mac-artifact.sh — portiert nach cpp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/notarize-mac-artifact.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <cstdlib>
#include <unistd.h>
#include <sys/wait.h>

// Notarize a macOS artifact (zip/dmg/pkg) and optionally staple the app bundle.
//
// Usage:
//   STAPLE_APP_PATH=dist/OpenClaw.app ./notarize_mac_artifact <artifact>
//
// Auth (pick one):
//   NOTARYTOOL_PROFILE   keychain profile created via `xcrun notarytool store-credentials`
//   NOTARYTOOL_KEY       path to App Store Connect API key (.p8)
//   NOTARYTOOL_KEY_ID    API key ID
//   NOTARYTOOL_ISSUER    API issuer ID

std::string getEnvVar(const std::string& name) {
    const char* value = std::getenv(name.c_str());
    return value ? std::string(value) : "";
}

bool commandExists(const std::string& cmd) {
    std::string command = "command -v " + cmd + " >/dev/null 2>&1";
    return std::system(command.c_str()) == 0;
}

int runCommand(const std::vector<std::string>& args) {
    std::string command;
    for (size_t i = 0; i < args.size(); ++i) {
        if (i > 0) command += " ";
        command += args[i];
    }
    return std::system(command.c_str());
}

void printUsage(const std::string& progName) {
    std::cerr << "Usage: " << progName << " <artifact>" << std::endl;
}

void printError(const std::string& msg) {
    std::cerr << "Error: " << msg << std::endl;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printUsage(argv[0]);
        return 1;
    }

    std::string ARTIFACT = argv[1];
    std::string STAPLE_APP_PATH = getEnvVar("STAPLE_APP_PATH");

    if (ARTIFACT.empty()) {
        printUsage(argv[0]);
        return 1;
    }

    // Check if file exists (basic check)
    if (access(ARTIFACT.c_str(), F_OK) == -1) {
        printError("artifact not found: " + ARTIFACT);
        return 1;
    }

    if (!commandExists("xcrun")) {
        printError("xcrun not found; install Xcode command line tools.");
        return 1;
    }

    std::vector<std::string> auth_args;
    std::string NOTARYTOOL_PROFILE = getEnvVar("NOTARYTOOL_PROFILE");
    std::string NOTARYTOOL_KEY = getEnvVar("NOTARYTOOL_KEY");
    std::string NOTARYTOOL_KEY_ID = getEnvVar("NOTARYTOOL_KEY_ID");
    std::string NOTARYTOOL_ISSUER = getEnvVar("NOTARYTOOL_ISSUER");

    if (!NOTARYTOOL_PROFILE.empty()) {
        auth_args.push_back("--keychain-profile");
        auth_args.push_back("\"" + NOTARYTOOL_PROFILE + "\"");
    } else if (!NOTARYTOOL_KEY.empty() && !NOTARYTOOL_KEY_ID.empty() && !NOTARYTOOL_ISSUER.empty()) {
        auth_args.push_back("--key");
        auth_args.push_back("\"" + NOTARYTOOL_KEY + "\"");
        auth_args.push_back("--key-id");
        auth_args.push_back("\"" + NOTARYTOOL_KEY_ID + "\"");
        auth_args.push_back("--issuer");
        auth_args.push_back("\"" + NOTARYTOOL_ISSUER + "\"");
    } else {
        printError("Notary auth missing. Set NOTARYTOOL_PROFILE or NOTARYTOOL_KEY/NOTARYTOOL_KEY_ID/NOTARYTOOL_ISSUER.");
        return 1;
    }

    std::cout << "🧾 Notarizing: " << ARTIFACT << std::endl;

    std::vector<std::string> submit_cmd = {"xcrun", "notarytool", "submit", "\"" + ARTIFACT + "\""};
    submit_cmd.insert(submit_cmd.end(), auth_args.begin(), auth_args.end());
    submit_cmd.push_back("--wait");

    int result = runCommand(submit_cmd);
    if (result != 0) {
        return result;
    }

    if (ARTIFACT.substr(ARTIFACT.find_last_of(".") + 1) == "dmg" ||
        ARTIFACT.substr(ARTIFACT.find_last_of(".") + 1) == "pkg") {
        std::cout << "📌 Stapling artifact: " << ARTIFACT << std::endl;
        std::vector<std::string> staple_cmd = {"xcrun", "stapler", "staple", "\"" + ARTIFACT + "\""};
        runCommand(staple_cmd);
        std::vector<std::string> validate_cmd = {"xcrun", "stapler", "validate", "\"" + ARTIFACT + "\""};
        runCommand(validate_cmd);
    }

    if (!STAPLE_APP_PATH.empty()) {
        if (access(STAPLE_APP_PATH.c_str(), F_OK) != -1) {
            std::cout << "📌 Stapling app: " << STAPLE_APP_PATH << std::endl;
            std::vector<std::string> staple_app_cmd = {"xcrun", "stapler", "staple", "\"" + STAPLE_APP_PATH + "\""};
            runCommand(staple_app_cmd);
            std::vector<std::string> validate_app_cmd = {"xcrun", "stapler", "validate", "\"" + STAPLE_APP_PATH + "\""};
            runCommand(validate_app_cmd);
        } else {
            std::cerr << "Warn: STAPLE_APP_PATH not found: " << STAPLE_APP_PATH << std::endl;
        }
    }

    std::cout << "✅ Notarization complete" << std::endl;
    return 0;
}
