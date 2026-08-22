#!/usr/bin/perl
# sandbox-setup.sh — portiert nach perl5
# Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Basename;
use Cwd qw(abs_path);
use IPC::Run3;

my $SKIP_HEAVY = 0;
$SKIP_HEAVY = 1 if (@ARGV && $ARGV[0] eq "--skip-heavy");

my $script_dir = dirname(abs_path($0));
chdir("$script_dir/..") or die "[sandbox-setup] FEHLER: Konnte nicht ins Projektverzeichnis wechseln";

sub log_msg {
    my ($msg) = @_;
    print "[sandbox-setup] $msg\n";
}

sub run_cmd {
    my ($cmd_ref, $stdout, $stderr) = @_;
    eval {
        run3($cmd_ref, undef, $stdout, $stderr);
    };
    return $? == 0;
}

sub check_command {
    my ($bin) = @_;
    open(my $fh, "-|", "command -v $bin 2>/dev/null") or return 0;
    my $result = <$fh>;
    close($fh);
    chomp($result) if defined $result;
    return defined $result && length($result) > 0;
}

sub get_version {
    my ($bin, $version_opt) = @_;
    $version_opt //= "--version";
    my ($stdout, $stderr);
    if (run_cmd([$bin, $version_opt], \$stdout, \$stderr)) {
        my @lines = split(/\n/, $stdout // $stderr);
        return $lines[0];
    }
    return "";
}

sub apt_install {
    my ($pkg, $bin) = @_;
    if (check_command($bin)) {
        my $version_info = get_version($bin);
        log_msg("$pkg bereits vorhanden ($version_info)");
        return 1;
    }
    log_msg("Installiere $pkg …");
    state $APT_UPDATED = 0;
    if (!$APT_UPDATED) {
        $ENV{DEBIAN_FRONTEND} = "noninteractive";
        system("apt-get update -qq >/dev/null 2>&1") == 0 and $APT_UPDATED = 1;
    }
    $ENV{DEBIAN_FRONTEND} = "noninteractive";
    my $result = system("apt-get install -y -qq $pkg >/dev/null 2>&1") == 0;
    unless ($result) {
        log_msg("WARNUNG: $pkg konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschränkt");
    }
    return $result;
}

log_msg("Node-Dependencies (npm install) …");
{
    my $result = system("npm install --no-audit --no-fund >/dev/null 2>&1") == 0;
    unless ($result) {
        log_msg("FEHLER: npm install fehlgeschlagen");
        exit 1;
    }
}

log_msg("Python-Dependencies (backend/requirements-dev.txt) …");
{
    my $result = system("pip3 install --quiet -r backend/requirements-dev.txt >/dev/null 2>&1") == 0;
    unless ($result) {
        log_msg("FEHLER: pip install fehlgeschlagen");
        exit 1;
    }
}

apt_install("ffmpeg", "ffmpeg");
apt_install("imagemagick", "convert");
if (!$SKIP_HEAVY) {
    apt_install("gimp", "gimp");
    apt_install("blender", "blender");
}

apt_install("xvfb", "Xvfb");
apt_install("x11-utils", "xdpyinfo");
apt_install("libnss3-tools", "certutil");

unless (check_command("google-chrome-stable")) {
    log_msg("Installiere Google Chrome Stable …");
    my $tmpdeb = `mktemp --suffix=.deb`;
    chomp($tmpdeb);
    my $download_ok = system("curl -fsSL -o '$tmpdeb' https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb >/dev/null 2>&1") == 0;
    if ($download_ok) {
        $ENV{DEBIAN_FRONTEND} = "noninteractive";
        my $install_ok = system("apt-get install -y -qq '$tmpdeb' >/dev/null 2>&1") == 0;
        if ($install_ok && check_command("google-chrome-stable")) {
            my $chrome_version = get_version("google-chrome-stable", "--version");
            log_msg("Chrome installiert: $chrome_version");
        } else {
            log_msg("WARNUNG: Chrome-Installation fehlgeschlagen");
        }
    } else {
        log_msg("WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)");
    }
    unlink($tmpdeb);
}

if (check_command("certutil") && -f "/root/.ccr/ca-bundle.crt") {
    system("mkdir -p '$ENV{HOME}/.pki/nssdb'");
    system("certutil -d sql:'$ENV{HOME}/.pki/nssdb' -N --empty-password 2>/dev/null");
    my $cert_check = `certutil -d sql:'$ENV{HOME}/.pki/nssdb' -L 2>/dev/null | grep -q ccr-proxy-ca; echo \$?`;
    chomp($cert_check);
    if ($cert_check ne "0") {
        my $import_result = system("certutil -d sql:'$ENV{HOME}/.pki/nssdb' -A -t 'C,,' -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt 2>/dev/null") == 0;
        if ($import_result) {
            log_msg("Proxy-CA in Chrome-NSS-Store importiert");
        }
    }
}

if (-d "node_modules" && !(-l "node_modules/playwright" || -d "node_modules/playwright")) {
    if (check_command("npm")) {
        my $pw_install = system("npm install --no-audit --no-fund --no-save playwright >/dev/null 2>&1") == 0;
        if ($pw_install) {
            log_msg("Playwright (Node) installiert");
        } else {
            log_msg("WARNUNG: Playwright-npm-Install fehlgeschlagen");
        }
    }
}

if (system("git rev-parse --is-inside-work-tree >/dev/null 2>&1") == 0) {
    system("git config credential.'https://x-access-token\@github.com'.helper '!'.`pwd`.'/.claude/git-credential-pat.sh'");
    system("git remote set-url --push origin 'https://x-access-token\@github.com/KikiKari/Onboarding.git'");
    log_msg("Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)");
}

if (check_command("dockerd") && system("docker info >/dev/null 2>&1") != 0) {
    log_msg("Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) …");
    system("mkdir -p /etc/docker");
    unless (-f "/etc/docker/daemon.json") {
        open(my $fh, ">", "/etc/docker/daemon.json") or die "Konnte daemon.json nicht erstellen";
        print $fh '{"registry-mirrors":["https://mirror.gcr.io"]}';
        close($fh);
    }
    system("(dockerd >/tmp/dockerd.log 2>&1 &)");

    for my $i (1..15) {
        last if system("docker info >/dev/null 2>&1") == 0;
        sleep(1);
    }

    if (system("docker info >/dev/null 2>&1") == 0) {
        log_msg("Docker-Daemon läuft");
    } else {
        log_msg("WARNUNG: Docker-Daemon nicht gestartet");
    }
}

log_msg("Fertig. Versionen:");
print "[sandbox-setup]   node ", `node --version`, "\n";
print "[sandbox-setup]   ", `python3 --version`, "\n";
if (check_command("ffmpeg")) {
    print "[sandbox-setup]   ", `ffmpeg -version 2>/dev/null | head -1`, "\n";
}
if (check_command("convert")) {
    print "[sandbox-setup]   ", `convert -version 2>/dev/null | head -1`, "\n";
}
if (check_command("gimp")) {
    print "[sandbox-setup]   ", `gimp --version 2>/dev/null | head -1`, "\n";
}
if (check_command("blender")) {
    print "[sandbox-setup]   ", `blender --version 2>/dev/null | head -1`, "\n";
}
exit 0;
