// abstraction-provenance: {"artifact_sha256": "4e8747b8175ec3b924e7a9a7a9e4a40494547d97f9ece278de4ec28c8c2ce8f4", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "c"}
// sandbox-setup.sh — portiert nach c
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>

static int skip_heavy = 0;
static int apt_updated = 0;

void log_msg(const char *msg) {
    printf("[sandbox-setup] %s\n", msg);
    fflush(stdout);
}

void log_error(const char *msg) {
    fprintf(stderr, "[sandbox-setup] FEHLER: %s\n", msg);
    fflush(stderr);
}

void log_warning(const char *msg) {
    fprintf(stderr, "[sandbox-setup] WARNUNG: %s\n", msg);
    fflush(stderr);
}

int command_exists(const char *cmd) {
    pid_t pid = fork();
    if (pid == 0) {
        execl("/bin/sh", "sh", "-c", "command -v \"$1\" >/dev/null 2>&1", "sh", cmd, NULL);
        exit(127);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        return WIFEXITED(status) && WEXITSTATUS(status) == 0;
    }
    return 0;
}

int run_command_quiet(const char *cmd) {
    pid_t pid = fork();
    if (pid == 0) {
        int devnull = open("/dev/null", O_WRONLY);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        close(devnull);
        execl("/bin/sh", "sh", "-c", cmd, NULL);
        exit(127);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        return WIFEXITED(status) && WEXITSTATUS(status) == 0;
    }
    return 0;
}

int run_command(const char *cmd) {
    pid_t pid = fork();
    if (pid == 0) {
        execl("/bin/sh", "sh", "-c", cmd, NULL);
        exit(127);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        return WIFEXITED(status) && WEXITSTATUS(status) == 0;
    }
    return 0;
}

void apt_update() {
    if (!apt_updated) {
        setenv("DEBIAN_FRONTEND", "noninteractive", 1);
        if (run_command_quiet("apt-get update -qq")) {
            apt_updated = 1;
        }
    }
}

void apt_install(const char *pkg, const char *bin) {
    if (command_exists(bin)) {
        char version_cmd[256];
        snprintf(version_cmd, sizeof(version_cmd), "%s --version 2>&1 | head -1", bin);
        
        pid_t pid = fork();
        if (pid == 0) {
            execl("/bin/sh", "sh", "-c", version_cmd, NULL);
            exit(127);
        } else if (pid > 0) {
            int status;
            waitpid(pid, &status, 0);
        }
        
        char msg[256];
        snprintf(msg, sizeof(msg), "%s bereits vorhanden", pkg);
        log_msg(msg);
        return;
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Installiere %s …", pkg);
    log_msg(msg);
    
    apt_update();
    
    setenv("DEBIAN_FRONTEND", "noninteractive", 1);
    char install_cmd[256];
    snprintf(install_cmd, sizeof(install_cmd), "apt-get install -y -qq \"%s\"", pkg);
    
    if (!run_command_quiet(install_cmd)) {
        char warn_msg[256];
        snprintf(warn_msg, sizeof(warn_msg), 
                "%s konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt", pkg);
        log_warning(warn_msg);
    }
}

int file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

int main(int argc, char *argv[]) {
    if (argc > 1 && strcmp(argv[1], "--skip-heavy") == 0) {
        skip_heavy = 1;
    }
    
    // Change to parent directory
    char cwd[1024];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
        char *dir = strrchr(cwd, '/');
        if (dir) {
            *dir = '\0';
            chdir(cwd);
        }
    }
    
    log_msg("Node-Dependencies (npm install) …");
    if (!run_command("npm install --no-audit --no-fund")) {
        log_error("npm install fehlgeschlagen");
        return 1;
    }
    
    log_msg("Python-Dependencies (backend/requirements-dev.txt) …");
    if (!run_command_quiet("pip3 install -r backend/requirements-dev.txt")) {
        log_error("pip install fehlgeschlagen");
        return 1;
    }
    
    apt_install("ffmpeg", "ffmpeg");
    apt_install("imagemagick", "convert");
    
    if (!skip_heavy) {
        apt_install("gimp", "gimp");
        apt_install("blender", "blender");
    }
    
    apt_install("xvfb", "Xvfb");
    apt_install("x11-utils", "xdpyinfo");
    apt_install("libnss3-tools", "certutil");
    
    if (!command_exists("google-chrome-stable")) {
        log_msg("Installiere Google Chrome Stable …");
        if (run_command_quiet("curl -fsSL -o /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")) {
            setenv("DEBIAN_FRONTEND", "noninteractive", 1);
            if (run_command_quiet("apt-get install -y -qq /tmp/chrome.deb")) {
                if (command_exists("google-chrome-stable")) {
                    char version[128] = {0};
                    FILE *fp = popen("google-chrome-stable --version 2>/dev/null", "r");
                    if (fp) {
                        fgets(version, sizeof(version)-1, fp);
                        pclose(fp);
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Chrome installiert: %s", version);
                        log_msg(msg);
                    }
                }
            } else {
                log_warning("Chrome-Installation fehlgeschlagen");
            }
        } else {
            log_warning("Chrome-Download fehlgeschlagen (Netzwerk-Policy?)");
        }
        unlink("/tmp/chrome.deb");
    }
    
    if (command_exists("certutil") && file_exists("/root/.ccr/ca-bundle.crt")) {
        system("mkdir -p \"$HOME/.pki/nssdb\"");
        system("certutil -d sql:\"$HOME/.pki/nssdb\" -N --empty-password 2>/dev/null || true");
        
        if (!run_command("certutil -d sql:\"$HOME/.pki/nssdb\" -L 2>/dev/null | grep -q ccr-proxy-ca")) {
            if (run_command_quiet("certutil -d sql:\"$HOME/.pki/nssdb\" -A -t \"C,,\" -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt 2>/dev/null")) {
                log_msg("Proxy-CA in Chrome-NSS-Store importiert");
            }
        }
    }
    
    if (file_exists("node_modules") && !file_exists("node_modules/playwright")) {
        if (command_exists("npm")) {
            if (run_command_quiet("npm install --no-audit --no-fund --no-save playwright")) {
                log_msg("Playwright (Node) installiert");
            } else {
                log_warning("Playwright-npm-Install fehlgeschlagen");
            }
        }
    }
    
    if (run_command("git rev-parse --is-inside-work-tree >/dev/null 2>&1")) {
        system("git config credential.\"https://x-access-token@github.com\".helper \"!$(pwd)/.claude/git-credential-pat.sh\"");
        system("git remote set-url --push origin \"https://x-access-token@github.com/KikiKari/Onboarding.git\"");
        log_msg("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)");
    }
    
    if (command_exists("dockerd") && !run_command("docker info >/dev/null 2>&1")) {
        log_msg("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …");
        system("mkdir -p /etc/docker");
        if (!file_exists("/etc/docker/daemon.json")) {
            system("echo '{\"registry-mirrors\":[\"https://mirror.gcr.io\"]}' > /etc/docker/daemon.json");
        }
        system("(dockerd >/tmp/dockerd.log 2>&1 &)");
        
        for (int i = 0; i < 15; i++) {
            if (run_command("docker info >/dev/null 2>&1")) {
                break;
            }
            sleep(1);
        }
        
        if (run_command("docker info >/dev/null 2>&1")) {
            log_msg("Docker-Daemon laeuft");
        } else {
            log_warning("Docker-Daemon nicht gestartet");
        }
    }
    
    log_msg("Fertig. Versionen:");
    if (run_command("node --version")) {
        system("node --version | sed 's/^/[sandbox-setup]   node /'");
    }
    if (run_command("python3 --version")) {
        system("python3 --version | sed 's/^/[sandbox-setup]   /'");
    }
    if (command_exists("ffmpeg")) {
        system("ffmpeg -version 2>/dev/null | head -1 | sed 's/^/[sandbox-setup]   /'");
    }
    if (command_exists("convert")) {
        system("convert -version 2>/dev/null | head -1 | sed 's/^/[sandbox-setup]   /'");
    }
    if (command_exists("gimp")) {
        system("gimp --version 2>/dev/null | head -1 | sed 's/^/[sandbox-setup]   /'");
    }
    if (command_exists("blender")) {
        system("blender --version 2>/dev/null | head -1 | sed 's/^/[sandbox-setup]   /'");
    }
    
    return 0;
}
