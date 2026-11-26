// abstraction-provenance: {"artifact_sha256": "04bdb6baa124bae0e6c92d4e87baae3becdf8efc9c7e3226da6f4177291fec88", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "cpp"}
// sandbox-setup.sh — portiert nach cpp
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>

namespace fs = std::filesystem;

// Globale Variablen
bool SKIP_HEAVY = false;
bool APT_UPDATED = false;

void log(const std::string& message) {
    std::cout << "[sandbox-setup] " << message << std::endl;
}

std::string exec_command(const std::string& cmd, bool quiet = false) {
    std::array<char, 128> buffer;
    std::string result;
    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) {
        if (!quiet) log("FEHLER: Befehl konnte nicht ausgeführt werden: " + cmd);
        return "";
    }
    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {
        result += buffer.data();
    }
    pclose(pipe);
    return result;
}

bool command_exists(const std::string& cmd) {
    return exec_command("command -v " + cmd + " >/dev/null 2>&1", true).empty() == false;
}

int system_quiet(const std::string& cmd) {
    return system((cmd + " >/dev/null 2>&1").c_str());
}

void apt_update() {
    if (!APT_UPDATED) {
        setenv("DEBIAN_FRONTEND", "noninteractive", 1);
        int ret = system_quiet("apt-get update -qq");
        if (ret == 0) {
            APT_UPDATED = true;
        } else {
            log("WARNUNG: apt-get update fehlgeschlagen");
        }
    }
}

void apt_install(const std::string& pkg, const std::string& bin) {
    if (command_exists(bin)) {
        std::string version_output = exec_command(bin + " --version 2>&1 | head -1", true);
        if (version_output.empty()) {
            version_output = exec_command(bin + " -version 2>&1 | head -1", true);
        }
        log(pkg + " bereits vorhanden (" + version_output + ")");
        return;
    }
    
    log("Installiere " + pkg + " …");
    apt_update();
    setenv("DEBIAN_FRONTEND", "noninteractive", 1);
    int ret = system_quiet("apt-get install -y -qq " + pkg);
    if (ret != 0) {
        log("WARNUNG: " + pkg + " konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschränkt");
    }
}

void setup_node_dependencies() {
    log("Node-Dependencies (npm install) …");
    int ret = system("npm install --no-audit --no-fund");
    if (ret != 0) {
        log("FEHLER: npm install fehlgeschlagen");
        exit(1);
    }
}

void setup_python_dependencies() {
    log("Python-Dependencies (backend/requirements-dev.txt) …");
    int ret = system_quiet("pip3 install --quiet -r backend/requirements-dev.txt");
    if (ret != 0) {
        log("FEHLER: pip install fehlgeschlagen");
        exit(1);
    }
}

void setup_media_tools() {
    apt_install("ffmpeg", "ffmpeg");
    apt_install("imagemagick", "convert");
    
    if (!SKIP_HEAVY) {
        apt_install("gimp", "gimp");
        apt_install("blender", "blender");
    }
}

void setup_visual_qa_tools() {
    apt_install("xvfb", "Xvfb");
    apt_install("x11-utils", "xdpyinfo");
    apt_install("libnss3-tools", "certutil");
    
    if (!command_exists("google-chrome-stable")) {
        log("Installiere Google Chrome Stable …");
        std::string tmp_deb = "/tmp/chrome.deb";
        int ret = system(("curl -fsSL -o " + tmp_deb + " https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb").c_str());
        if (ret == 0) {
            setenv("DEBIAN_FRONTEND", "noninteractive", 1);
            ret = system_quiet("apt-get install -y -qq " + tmp_deb);
            if (ret == 0) {
                std::string version = exec_command("google-chrome-stable --version 2>/dev/null", true);
                log("Chrome installiert: " + version);
            } else {
                log("WARNUNG: Chrome-Installation fehlgeschlagen");
            }
        } else {
            log("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)");
        }
        unlink(tmp_deb.c_str());
    }
    
    // Proxy-CA in Chromes NSS-DB
    if (command_exists("certutil") && fs::exists("/root/.ccr/ca-bundle.crt")) {
        fs::create_directories(std::getenv("HOME") + std::string("/.pki/nssdb"));
        system("certutil -d sql:$HOME/.pki/nssdb -N --empty-password 2>/dev/null || true");
        std::string cert_check = exec_command("certutil -d sql:$HOME/.pki/nssdb -L 2>/dev/null | grep -q ccr-proxy-ca && echo 'found'", true);
        if (cert_check.empty()) {
            int ret = system_quiet("certutil -d sql:$HOME/.pki/nssdb -A -t \"C,,\" -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt");
            if (ret == 0) {
                log("Proxy-CA in Chrome-NSS-Store importiert");
            }
        }
    }
    
    // Playwright-Node-Module
    if (fs::exists("node_modules") && !fs::exists("node_modules/playwright")) {
        if (command_exists("npm")) {
            int ret = system_quiet("npm install --no-audit --no-fund --no-save playwright");
            if (ret == 0) {
                log("Playwright (Node) installiert");
            } else {
                log("WARNUNG: Playwright-npm-Install fehlgeschlagen");
            }
        }
    }
}

void setup_git_push_route() {
    if (system("git rev-parse --is-inside-work-tree >/dev/null 2>&1") == 0) {
        system("git config credential.\"https://x-access-token@github.com\".helper \"!$(pwd)/.claude/git-credential-pat.sh\"");
        system("git remote set-url --push origin \"https://x-access-token@github.com/KikiKari/Onboarding.git\"");
        log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)");
    }
}

void setup_docker_daemon() {
    if (command_exists("dockerd") && system("docker info >/dev/null 2>&1") != 0) {
        log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …");
        fs::create_directories("/etc/docker");
        if (!fs::exists("/etc/docker/daemon.json")) {
            std::ofstream daemon_file("/etc/docker/daemon.json");
            daemon_file << "{\"registry-mirrors\":[\"https://mirror.gcr.io\"]}";
            daemon_file.close();
        }
        
        if (fork() == 0) {
            freopen("/tmp/dockerd.log", "w", stdout);
            freopen("/tmp/dockerd.log", "w", stderr);
            execlp("dockerd", "dockerd", nullptr);
        }
        
        for (int i = 0; i < 15; ++i) {
            if (system("docker info >/dev/null 2>&1") == 0) break;
            sleep(1);
        }
        
        if (system("docker info >/dev/null 2>&1") == 0) {
            log("Docker-Daemon läuft");
        } else {
            log("WARNUNG: Docker-Daemon nicht gestartet");
        }
    }
}

void print_versions() {
    log("Fertig. Versionen:");
    std::string node_version = exec_command("node --version", true);
    if (!node_version.empty()) {
        log("  node " + node_version);
    }
    
    std::string python_version = exec_command("python3 --version", true);
    if (!python_version.empty()) {
        log("  " + python_version);
    }
    
    if (command_exists("ffmpeg")) {
        std::string ffmpeg_version = exec_command("ffmpeg -version 2>/dev/null | head -1", true);
        if (!ffmpeg_version.empty()) {
            log("  " + ffmpeg_version);
        }
    }
    
    if (command_exists("convert")) {
        std::string convert_version = exec_command("convert -version 2>/dev/null | head -1", true);
        if (!convert_version.empty()) {
            log("  " + convert_version);
        }
    }
    
    if (command_exists("gimp")) {
        std::string gimp_version = exec_command("gimp --version 2>/dev/null | head -1", true);
        if (!gimp_version.empty()) {
            log("  " + gimp_version);
        }
    }
    
    if (command_exists("blender")) {
        std::string blender_version = exec_command("blender --version 2>/dev/null | head -1", true);
        if (!blender_version.empty()) {
            log("  " + blender_version);
        }
    }
}

int main(int argc, char* argv[]) {
    if (argc > 1 && std::string(argv[1]) == "--skip-heavy") {
        SKIP_HEAVY = true;
    }
    
    // Change to parent directory of script location
    fs::path script_path(argv[0]);
    fs::path parent_dir = script_path.parent_path().parent_path();
    fs::current_path(parent_dir);
    
    setup_node_dependencies();
    setup_python_dependencies();
    setup_media_tools();
    setup_visual_qa_tools();
    setup_git_push_route();
    setup_docker_daemon();
    print_versions();
    
    return 0;
}
