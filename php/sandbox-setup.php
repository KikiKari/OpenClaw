<?php
// abstraction-provenance: {"artifact_sha256": "6200a8eaeafaf36ebbacff76521df896e1aa1f81940fb11712b96edaee0e4670", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "php"}
// sandbox-setup.sh — portiert nach php
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py
// Provisioniert die Claude-Code-Sandbox (Remote-Umgebung) reproduzierbar:
//   - Node-Dependencies (Frontend, npm)
//   - Python-Dependencies (Backend inkl. pytest)
//   - Medien-Tools: ffmpeg, ImageMagick, GIMP, Blender headless (apt) —
//     Fehlschlag blockiert die Session nicht; --skip-heavy laesst GIMP/Blender aus
// Idempotent: bereits Vorhandenes wird uebersprungen; der Container-Cache der
// Umgebung macht die apt-Installation zum Einmal-Aufwand.

$SKIP_HEAVY = ($argc > 1 && $argv[1] === '--skip-heavy') ? 1 : 0;

chdir(dirname(__DIR__));
function log($message) {
    echo "[sandbox-setup] $message\n";
}

log("Node-Dependencies (npm install) …");
exec('npm install --no-audit --no-fund 2>&1', $output, $return_code);
if ($return_code !== 0) {
    log("FEHLER: npm install fehlgeschlagen");
    exit(1);
}

log("Python-Dependencies (backend/requirements-dev.txt) …");
exec('pip3 install --quiet -r backend/requirements-dev.txt 2>&1', $output, $return_code);
if ($return_code !== 0) {
    log("FEHLER: pip install fehlgeschlagen");
    exit(1);
}

function apt_install($pkg, $bin) {
    exec("command -v $bin >/dev/null 2>&1", $output, $return_code);
    if ($return_code === 0) {
        exec("$bin --version 2>&1", $version_output, $version_return);
        $version_line = isset($version_output[0]) ? $version_output[0] : '';
        log("$pkg bereits vorhanden ($version_line)");
        return;
    }
    log("Installiere $pkg …");
    static $APT_UPDATED = false;
    if (!$APT_UPDATED) {
        putenv('DEBIAN_FRONTEND=noninteractive');
        exec('apt-get update -qq 2>&1', $update_output, $update_return);
        if ($update_return === 0) {
            $APT_UPDATED = true;
        }
    }
    putenv('DEBIAN_FRONTEND=noninteractive');
    exec("apt-get install -y -qq $pkg >/dev/null 2>&1", $install_output, $install_return);
    if ($install_return !== 0) {
        log("WARNUNG: $pkg konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt");
    }
}

apt_install('ffmpeg', 'ffmpeg');
apt_install('imagemagick', 'convert');
if ($SKIP_HEAVY === 0) {
    apt_install('gimp', 'gimp');
    apt_install('blender', 'blender');
}

// Visual QA: echtes Google Chrome (H.264/AAC-Codecs → Videos sichtbar; der
// Playwright-Bundle-Chromium hat keine proprietären Codecs), Xvfb (headed-Läufe
// für echte Web-Logins) und NSS-Tools, um die Proxy-CA in Chromes Trust-Store zu
// importieren. Ohne all das: Videos schwarz bzw. TLS-Fehler beim externen Surfen.
apt_install('xvfb', 'Xvfb');
apt_install('x11-utils', 'xdpyinfo');
apt_install('libnss3-tools', 'certutil');

exec('command -v google-chrome-stable >/dev/null 2>&1', $chrome_check_output, $chrome_check_return);
if ($chrome_check_return !== 0) {
    log("Installiere Google Chrome Stable …");
    $tmpdeb = tempnam(sys_get_temp_dir(), 'chrome') . '.deb';
    $download_result = @file_put_contents($tmpdeb, file_get_contents('https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'));
    if ($download_result !== false) {
        putenv('DEBIAN_FRONTEND=noninteractive');
        exec("apt-get install -y -qq $tmpdeb >/dev/null 2>&1", $install_chrome_output, $install_chrome_return);
        if ($install_chrome_return === 0) {
            exec('google-chrome-stable --version 2>/dev/null', $chrome_version_output, $chrome_version_return);
            $chrome_version = isset($chrome_version_output[0]) ? $chrome_version_output[0] : '';
            log("Chrome installiert: $chrome_version");
        } else {
            log("WARNUNG: Chrome-Installation fehlgeschlagen");
        }
    } else {
        log("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)");
    }
    unlink($tmpdeb);
}

// Proxy-CA in Chromes NSS-DB, damit externes HTTPS ohne Zertifikatsfehler läuft.
exec('command -v certutil >/dev/null 2>&1', $certutil_check_output, $certutil_check_return);
if ($certutil_check_return === 0 && file_exists('/root/.ccr/ca-bundle.crt')) {
    $home = getenv('HOME') ?: '/root';
    $nssdb_path = "$home/.pki/nssdb";
    if (!is_dir($nssdb_path)) {
        mkdir($nssdb_path, 0700, true);
    }
    exec("certutil -d sql:\"$nssdb_path\" -N --empty-password 2>/dev/null", $init_nss_output, $init_nss_return);
    exec("certutil -d sql:\"$nssdb_path\" -L 2>/dev/null", $list_certs_output, $list_certs_return);
    $cert_found = false;
    foreach ($list_certs_output as $line) {
        if (strpos($line, 'ccr-proxy-ca') !== false) {
            $cert_found = true;
            break;
        }
    }
    if (!$cert_found) {
        exec("certutil -d sql:\"$nssdb_path\" -A -t \"C,,\" -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt 2>/dev/null", $import_cert_output, $import_cert_return);
        if ($import_cert_return === 0) {
            log("Proxy-CA in Chrome-NSS-Store importiert");
        }
    }
}

// Playwright-Node-Module ins Projekt verlinken (visual-qa.mjs / browser-session.mjs).
if (is_dir('node_modules') && !file_exists('node_modules/playwright')) {
    exec('command -v npm >/dev/null 2>&1', $npm_check_output, $npm_check_return);
    if ($npm_check_return === 0) {
        exec('npm install --no-audit --no-fund --no-save playwright >/dev/null 2>&1', $playwright_install_output, $playwright_install_return);
        if ($playwright_install_return === 0) {
            log("Playwright (Node) installiert");
        } else {
            log("WARNUNG: Playwright-npm-Install fehlgeschlagen");
        }
    }
}

// Git-Push-Weg: Der Session-Git-Proxy (origin) ist read-only. Pushes laufen
// direkt zu github.com mit dem Nutzer-PAT (GH_ACCESS_TOKEN aus Umgebungs-Env
// oder .env, geliefert vom Credential-Helper — kein Secret in der Git-Config).
exec('git rev-parse --is-inside-work-tree >/dev/null 2>&1', $git_check_output, $git_check_return);
if ($git_check_return === 0) {
    $pwd = getcwd();
    exec("git config credential.\"https://x-access-token@github.com\".helper \"!$pwd/.claude/git-credential-pat.sh\" 2>&1");
    exec("git remote set-url --push origin \"https://x-access-token@github.com/KikiKari/Onboarding.git\" 2>&1");
    log("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)");
}

// Docker-Daemon fuer Dev-Compose-Verifikation in der Sandbox.
// Docker-Hub-Blobs (cloudfront.docker.com) sind von der Netz-Policy blockiert —
// mirror.gcr.io liefert die Library-Images. Container brauchen zusaetzlich die
// Proxy-CA (siehe docker-compose.sandbox.yml).
exec('command -v dockerd >/dev/null 2>&1', $dockerd_check_output, $dockerd_check_return);
if ($dockerd_check_return === 0) {
    exec('docker info >/dev/null 2>&1', $docker_info_output, $docker_info_return);
    if ($docker_info_return !== 0) {
        log("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …");
        if (!is_dir('/etc/docker')) {
            mkdir('/etc/docker', 0755, true);
        }
        if (!file_exists('/etc/docker/daemon.json')) {
            file_put_contents('/etc/docker/daemon.json', '{"registry-mirrors":["https://mirror.gcr.io"]}');
        }
        // Start dockerd in background
        exec('(dockerd >/tmp/dockerd.log 2>&1 &) 2>&1');
        for ($i = 1; $i <= 15; $i++) {
            exec('docker info >/dev/null 2>&1', $wait_docker_output, $wait_docker_return);
            if ($wait_docker_return === 0) {
                break;
            }
            sleep(1);
        }
        exec('docker info >/dev/null 2>&1', $final_docker_check_output, $final_docker_check_return);
        if ($final_docker_check_return === 0) {
            log("Docker-Daemon laeuft");
        } else {
            log("WARNUNG: Docker-Daemon nicht gestartet");
        }
    }
}

log("Fertig. Versionen:");
exec('node --version 2>&1', $node_version_output, $node_version_return);
echo "[sandbox-setup]   node " . (isset($node_version_output[0]) ? $node_version_output[0] : '') . "\n";

exec('python3 --version 2>&1', $python_version_output, $python_version_return);
echo "[sandbox-setup]   " . (isset($python_version_output[0]) ? $python_version_output[0] : '') . "\n";

exec('command -v ffmpeg >/dev/null 2>&1', $ffmpeg_check_output, $ffmpeg_check_return);
if ($ffmpeg_check_return === 0) {
    exec('ffmpeg -version 2>/dev/null', $ffmpeg_version_output, $ffmpeg_version_return);
    echo "[sandbox-setup]   " . (isset($ffmpeg_version_output[0]) ? $ffmpeg_version_output[0] : '') . "\n";
}

exec('command -v convert >/dev/null 2>&1', $convert_check_output, $convert_check_return);
if ($convert_check_return === 0) {
    exec('convert -version 2>/dev/null', $convert_version_output, $convert_version_return);
    echo "[sandbox-setup]   " . (isset($convert_version_output[0]) ? $convert_version_output[0] : '') . "\n";
}

exec('command -v gimp >/dev/null 2>&1', $gimp_check_output, $gimp_check_return);
if ($gimp_check_return === 0) {
    exec('gimp --version 2>/dev/null', $gimp_version_output, $gimp_version_return);
    echo "[sandbox-setup]   " . (isset($gimp_version_output[0]) ? $gimp_version_output[0] : '') . "\n";
}

exec('command -v blender >/dev/null 2>&1', $blender_check_output, $blender_check_return);
if ($blender_check_return === 0) {
    exec('blender --version 2>/dev/null', $blender_version_output, $blender_version_return);
    echo "[sandbox-setup]   " . (isset($blender_version_output[0]) ? $blender_version_output[0] : '') . "\n";
}

exit(0);
?>
