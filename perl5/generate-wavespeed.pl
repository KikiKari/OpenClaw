#!/usr/bin/perl
# generate-wavespeed.mjs — portiert nach perl5
# Quelle: javascript, Onboarding@main:scripts/generate-wavespeed.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON qw(decode_json encode_json);
use File::Spec;
use File::Path qw(make_path);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST GET);
use MIME::Base64;
use Time::HiRes qw(sleep);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# Umgebungsvariable prüfen
my $key = $ENV{WAVESPEED_API_KEY};
die "WAVESPEED_API_KEY fehlt." unless defined $key;

# Pfade bestimmen
my $script_dir = __FILE__;
$script_dir =~ s/[^\/\\]+$//;
my $project_root = ($script_dir =~ /^(.*?)[\/\\]media-production/) ? $1 : $script_dir . "../../";

my $jobs_file = "$project_root/media-production/wavespeed-jobs.json";
my $raw_dir = "$project_root/media-production/raw/";
my $public_dir = "$project_root/public/media/";
my $result_url = "$project_root/media-production/wavespeed-results.json";

# Verzeichnisse erstellen
make_path($raw_dir) or die "Konnte Verzeichnis nicht erstellen: $raw_dir\n";
make_path($public_dir) or die "Konnte Verzeichnis nicht erstellen: $public_dir\n";

# Jobs laden
open my $fh_jobs, '<:encoding(UTF-8)', $jobs_file or die "Kann $jobs_file nicht öffnen: $!";
my $json_text = do { local $/; <$fh_jobs> };
close $fh_jobs;
my $jobs = decode_json($json_text);

# Log laden oder initialisieren
my $log = [];
if (-f $result_url) {
    open my $fh_log, '<:encoding(UTF-8)', $result_url or die "Kann $result_url nicht öffnen: $!";
    my $log_text = do { local $/; <$fh_log> };
    close $fh_log;
    $log = decode_json($log_text // '[]');
}

# User-Agent für HTTP-Anfragen
my $ua = LWP::UserAgent->new;
$ua->timeout(60);

# Jobs verarbeiten
foreach my $job (@$jobs) {
    my $raw_path = "$raw_dir$job->{id}.png";
    my $target_path = "$public_dir$job->{output}.png";
    
    # Prüfen, ob bereits generiert
    if (-f $raw_path) {
        my $found = 0;
        foreach my $entry (@$log) {
            if ($entry->{id} eq $job->{id}) {
                $found = 1;
                last;
            }
        }
        unless ($found) {
            push @$log, {
                id => $job->{id},
                requestId => "completed-before-resume",
                model => "google/nano-banana-2/edit",
                resolution => "4k",
                plannedCostUsd => 0.14,
                output => $job->{output} . ".png"
            };
            
            open my $fh_res, '>:encoding(UTF-8)', $result_url or die "Kann $result_url nicht schreiben: $!";
            print $fh_res encode_json($log);
            close $fh_res;
        }
        print "Übersprungen: $job->{id} ist bereits vorhanden.\n";
        next;
    }
    
    # Bilder laden
    my @images;
    foreach my $image (@{$job->{images}}) {
        if ($image =~ /^https?:|^data:/) {
            push @images, $image;
        } else {
            my $image_path = File::Spec->catfile($project_root, $image);
            open my $fh_img, '<:raw', $image_path or die "Kann Bild nicht öffnen: $image_path - $!";
            my $content;
            {
                local $/;
                $content = <$fh_img>;
            }
            close $fh_img;
            my $encoded = encode_base64($content, '');
            push @images, "data:image/png;base64,$encoded";
        }
    }
    
    # Anfrage an WaveSpeed senden
    my $req_data = {
        prompt => $job->{prompt},
        images => \@images,
        aspect_ratio => $job->{aspectRatio},
        resolution => "4k",
        output_format => "png",
        enable_web_search => JSON::false,
        enable_image_search => JSON::false,
        enable_sync_mode => JSON::false,
        enable_base64_output => JSON::false,
    };
    
    my $req = POST 'https://api.wavespeed.ai/api/v3/google/nano-banana-2/edit',
        Content_Type => 'application/json',
        Authorization => "Bearer $key",
        Content => encode_json($req_data);
        
    my $res = $ua->request($req);
    unless ($res->is_success) {
        die "WaveSpeed submit fehlgeschlagen: " . $res->status_line . " " . $res->decoded_content;
    }
    
    my $submitted = decode_json($res->decoded_content);
    my $requestId = $submitted->{data}->{id} // $submitted->{id};
    my $result;
    
    # Ergebnis abrufen
    for my $attempt (0..89) {
        sleep(4);
        my $poll_req = GET "https://api.wavespeed.ai/api/v3/predictions/$requestId/result",
            Authorization => "Bearer $key";
        my $poll_res = $ua->request($poll_req);
        $result = decode_json($poll_res->decoded_content);
        if ($result->{data}->{status} eq "completed") {
            last;
        }
        if ($result->{data}->{status} eq "failed") {
            die "WaveSpeed job fehlgeschlagen: $job->{id}";
        }
    }
    
    my $url = $result->{data}->{outputs}->[0];
    unless (defined $url) {
        die "Kein Output für $job->{id}";
    }
    
    # Bilddaten herunterladen
    my $img_req = GET $url;
    my $img_res = $ua->request($img_req);
    unless ($img_res->is_success) {
        die "Konnte Bilddaten nicht abrufen: " . $img_res->status_line;
    }
    
    my $bytes = $img_res->decoded_content;
    
    # Rohdaten speichern
    open my $fh_raw, '>:raw', $raw_path or die "Kann $raw_path nicht schreiben: $!";
    print $fh_raw $bytes;
    close $fh_raw;
    
    # Öffentliche Kopie speichern
    open my $fh_pub, '>:raw', $target_path or die "Kann $target_path nicht schreiben: $!";
    print $fh_pub $bytes;
    close $fh_pub;
    
    # Logeintrag hinzufügen
    push @$log, {
        id => $job->{id},
        requestId => $requestId,
        model => "google/nano-banana-2/edit",
        resolution => "4k",
        plannedCostUsd => 0.14,
        output => $job->{output} . ".png"
    };
    
    # Log speichern
    open my $fh_res_out, '>:encoding(UTF-8)', $result_url or die "Kann $result_url nicht schreiben: $!";
    print $fh_res_out encode_json($log);
    close $fh_res_out;
    
    print "Abgeschlossen: $job->{id}\n";
}

# Finale Log-Aktualisierung
open my $fh_final, '>:encoding(UTF-8)', $result_url or die "Kann $result_url nicht schreiben: $!";
print $fh_final encode_json($log);
close $fh_final;

my $count = scalar @$log;
my $cost = $count * 0.14;
printf "WaveSpeed abgeschlossen: %d Assets, geplante Basiskosten \$%.2f.\n", $count, $cost;
