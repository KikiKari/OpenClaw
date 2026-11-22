#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "31ad71b29b2c493029c36d0ec6578b2b6b7cc5ac6ed78a1c08223b84a01cae93", "source_sha256": "29aab8d3e497ddaa7ec77edf107b153fe17970d064df8a91d7cfcedb7e30a7fd", "target_language": "perl5"}
# sandbox-browser-entrypoint.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/sandbox-browser-entrypoint.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use POSIX qw(mktime);
use Time::HiRes qw(time);
use File::Path qw(make_path);

$ENV{DBUS_SESSION_BUS_ADDRESS} = "/dev/null";

$ENV{DISPLAY} = ":1";
$ENV{HOME} = "/tmp/openclaw-home";
$ENV{XDG_CONFIG_HOME} = "$ENV{HOME}/.config";
$ENV{XDG_CACHE_HOME} = "$ENV{HOME}/.cache";

my $CDP_PORT = $ENV{OPENCLAW_BROWSER_CDP_PORT} // 9222;
my $CDP_SOURCE_RANGE = $ENV{OPENCLAW_BROWSER_CDP_SOURCE_RANGE} // "";
my $VNC_PORT = $ENV{OPENCLAW_BROWSER_VNC_PORT} // 5900;
my $NOVNC_PORT = $ENV{OPENCLAW_BROWSER_NOVNC_PORT} // 6080;
my $ENABLE_NOVNC = $ENV{OPENCLAW_BROWSER_ENABLE_NOVNC} // 1;
my $HEADLESS = $ENV{OPENCLAW_BROWSER_HEADLESS} // 0;
my $ALLOW_NO_SANDBOX = $ENV{OPENCLAW_BROWSER_NO_SANDBOX} // 0;
my $NOVNC_PASSWORD = $ENV{OPENCLAW_BROWSER_NOVNC_PASSWORD} // "";

my $DISABLE_GRAPHICS_FLAGS = $ENV{OPENCLAW_BROWSER_DISABLE_GRAPHICS_FLAGS} // 1;
my $DISABLE_EXTENSIONS = $ENV{OPENCLAW_BROWSER_DISABLE_EXTENSIONS} // 1;
my $RENDERER_PROCESS_LIMIT = $ENV{OPENCLAW_BROWSER_RENDERER_PROCESS_LIMIT} // 2;
my $AUTO_START_TIMEOUT_MS = $ENV{OPENCLAW_BROWSER_AUTO_START_TIMEOUT_MS} // 12000;

sub validate_uint {
    my ($name, $value, $min, $max) = @_;
    $min //= 0;
    $max //= 4294967295;

    if ($value !~ /^\d+$/) {
        print STDERR "[sandbox] ERROR: $name must be an integer, got: $value\n";
        exit 1;
    }
    if ($value < $min || $value > $max) {
        print STDERR "[sandbox] ERROR: $name out of range ($min..$max), got: $value\n";
        exit 1;
    }
}

validate_uint("CDP_PORT", $CDP_PORT, 1, 65535);
validate_uint("VNC_PORT", $VNC_PORT, 1, 65535);
validate_uint("NOVNC_PORT", $NOVNC_PORT, 1, 65535);
validate_uint("AUTO_START_TIMEOUT_MS", $AUTO_START_TIMEOUT_MS, 1, 2147483647);
if (defined $RENDERER_PROCESS_LIMIT && $RENDERER_PROCESS_LIMIT ne "") {
    validate_uint("RENDERER_PROCESS_LIMIT", $RENDERER_PROCESS_LIMIT, 0, 2147483647);
}

my %pids = ();

sub cleanup {
    my $code = shift // 1;
    
    $SIG{INT} = $SIG{TERM} = $SIG{__DIE__} = undef;
    
    my @kill_pids = grep { defined $_ && $_ ne "" } (
        $pids{WEBSOCKIFY},
        $pids{X11VNC},
        $pids{SOCAT},
        $pids{CHROME},
        $pids{XVFB}
    );
    
    if (@kill_pids) {
        kill('TERM', @kill_pids);
        
        my $alive = 1;
        for my $i (1..10) {
            $alive = 0;
            for my $pid (@kill_pids) {
                if (kill(0, $pid)) {
                    $alive = 1;
                    last;
                }
            }
            last unless $alive;
            select(undef, undef, undef, 0.2);
        }
        
        if ($alive) {
            kill('KILL', @kill_pids);
        }
        
        eval {
            local $SIG{CHLD} = sub {};
            wait();
        };
    }
    
    exit($code);
}

$SIG{__DIE__} = sub { cleanup(shift // 1); };
$SIG{INT} = sub { cleanup(130); };
$SIG{TERM} = sub { cleanup(143); };

make_path($ENV{HOME}, "$ENV{HOME}/.chrome", $ENV{XDG_CONFIG_HOME}, $ENV{XDG_CACHE_HOME});

my $cmd = "Xvfb :1 -screen 0 1280x800x24 -ac -nolisten tcp &";
system($cmd) == 0 or die "Failed to start Xvfb: $?";
$pids{XVFB} = $!;
print "[sandbox] Xvfb started (PID: $pids{XVFB})\n";

my $CHROME_CDP_PORT;
if ($CDP_PORT >= 65535) {
    $CHROME_CDP_PORT = $CDP_PORT - 1;
} else {
    $CHROME_CDP_PORT = $CDP_PORT + 1;
}

my @CHROME_ARGS = (
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=$CHROME_CDP_PORT",
    "--user-data-dir=$ENV{HOME}/.chrome",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-dev-shm-usage",
    "--disable-background-networking",
    "--disable-breakpad",
    "--disable-crash-reporter",
    "--no-zygote",
    "--metrics-recording-only",
    "--password-store=basic",
    "--use-mock-keychain"
);

if ($HEADLESS eq "1") {
    push @CHROME_ARGS, "--headless=new";
}

if ($ALLOW_NO_SANDBOX eq "1") {
    push @CHROME_ARGS, "--no-sandbox", "--disable-setuid-sandbox";
}

my $DISABLE_GRAPHICS_FLAGS_LOWER = lc($DISABLE_GRAPHICS_FLAGS);
if ($DISABLE_GRAPHICS_FLAGS_LOWER =~ /^(1|true|yes|on)$/) {
    push @CHROME_ARGS, "--disable-3d-apis", "--disable-gpu", "--disable-software-rasterizer";
}

my $DISABLE_EXTENSIONS_LOWER = lc($DISABLE_EXTENSIONS);
if ($DISABLE_EXTENSIONS_LOWER =~ /^(1|true|yes|on)$/) {
    push @CHROME_ARGS, "--disable-extensions";
}

if (defined $RENDERER_PROCESS_LIMIT && $RENDERER_PROCESS_LIMIT =~ /^\d+$/ && $RENDERER_PROCESS_LIMIT > 0) {
    push @CHROME_ARGS, "--renderer-process-limit=$RENDERER_PROCESS_LIMIT";
}

print "[sandbox] Starting Chromium...\n";
my $chrome_cmd = "chromium " . join(" ", map { "'$_'" } @CHROME_ARGS) . " about:blank &";
system($chrome_cmd) == 0 or die "Failed to start Chromium: $?";
$pids{CHROME} = $!;
print "[sandbox] Chromium started (PID: $pids{CHROME})\n";

my $start_time = time() * 1000;
my $deadline = $start_time + $AUTO_START_TIMEOUT_MS;
my $CDP_READY = 0;
my $probe_url = "http://127.0.0.1:$CHROME_CDP_PORT/json/version";

print "[sandbox] Waiting up to $AUTO_START_TIMEOUT_MS ms for CDP on port $CHROME_CDP_PORT...\n";

while (time() * 1000 < $deadline) {
    unless (kill(0, $pids{CHROME})) {
        print "[sandbox] ERROR: Chromium exited before CDP became ready.\n";
        exit 1;
    }
    
    my $curl_result = system("curl -fsS --max-time 0.5 '$probe_url' >/dev/null 2>&1");
    if ($curl_result == 0) {
        $CDP_READY = 1;
        last;
    }
    
    select(undef, undef, undef, 0.2);
}

unless ($CDP_READY) {
    print "[sandbox] ERROR: CDP failed to start within $AUTO_START_TIMEOUT_MS ms.\n";
    exit 1;
}

print "[sandbox] CDP ready. Starting socat...\n";

if ($CDP_SOURCE_RANGE eq "") {
    print STDERR "[sandbox-browser] WARNING: CDP_SOURCE_RANGE unset; socat CDP relay will not start.\n";
    print STDERR "[sandbox-browser] Set OPENCLAW_BROWSER_CDP_SOURCE_RANGE to an explicit CIDR to enable CDP access.\n";
} else {
    my $SOCAT_LISTEN_ADDR = "TCP-LISTEN:$CDP_PORT,fork,reuseaddr,bind=0.0.0.0,range=$CDP_SOURCE_RANGE";
    my $socat_cmd = "socat '$SOCAT_LISTEN_ADDR' 'TCP:127.0.0.1:$CHROME_CDP_PORT' &";
    system($socat_cmd) == 0 or die "Failed to start socat: $?";
    $pids{SOCAT} = $!;
    print "[sandbox] socat started (PID: $pids{SOCAT})\n";
}

if ($ENABLE_NOVNC eq "1" && $HEADLESS ne "1") {
    if ($NOVNC_PASSWORD eq "") {
        open(my $fh, '<', '/proc/sys/kernel/random/uuid') or die "Cannot read UUID: $!";
        $NOVNC_PASSWORD = <$fh>;
        close($fh);
        chomp $NOVNC_PASSWORD;
        $NOVNC_PASSWORD =~ s/-//g;
        $NOVNC_PASSWORD = substr($NOVNC_PASSWORD, 0, 8);
    }
    
    make_path("$ENV{HOME}/.vnc");
    
    open(my $fh, '>', "$ENV{HOME}/.vnc/passwd") or die "Cannot create passwd file: $!";
    print $fh $NOVNC_PASSWORD;
    close($fh);
    chmod 0600, "$ENV{HOME}/.vnc/passwd";
    
    my $x11vnc_cmd = "x11vnc -display :1 -rfbport $VNC_PORT -shared -forever -rfbauth '$ENV{HOME}/.vnc/passwd' -localhost &";
    system($x11vnc_cmd) == 0 or die "Failed to start x11vnc: $?";
    $pids{X11VNC} = $!;
    print "[sandbox] x11vnc started (PID: $pids{X11VNC})\n";
    
    my $websockify_cmd = "websockify --web /usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT &";
    system($websockify_cmd) == 0 or die "Failed to start websockify: $?";
    $pids{WEBSOCKIFY} = $!;
    print "[sandbox] websockify started (PID: $pids{WEBSOCKIFY})\n";
}

print "[sandbox] Container running. Monitoring all sub-processes...\n";

# Wait for any child process to exit
while (1) {
    my $pid = wait();
    last if $pid == -1;
}
