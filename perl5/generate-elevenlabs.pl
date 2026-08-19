#!/usr/bin/perl
# generate-elevenlabs.mjs — portiert nach perl5
# Quelle: javascript, Onboarding@main:scripts/generate-elevenlabs.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON qw(encode_json decode_json);
use File::Path qw(make_path);
use File::Spec;
use Cwd qw(abs_path);

# Umgebungsvariablen abrufen
my $key = $ENV{ELEVENLABS_API_KEY};
my $voiceId = $ENV{ELEVENLABS_VOICE_ID} // "JBFqnCBsd6RMkjVDRZzb";

# Fehler werfen, wenn API-Key fehlt
die "ELEVENLABS_API_KEY fehlt." unless $key;

my $text = "Neun Projekte. Zwei Plattformen. Ein Ort, an dem Ideen verbunden und weiterentwickelt werden.";

# URL für ElevenLabs API zusammenstellen
my $url = "https://api.elevenlabs.io/v1/text-to-speech/$voiceId?output_format=mp3_44100_128";

# User-Agent für HTTP-Anfragen erstellen
my $ua = LWP::UserAgent->new;

# POST-Request vorbereiten
my $req = POST $url,
    Content_Type => 'application/json',
    'xi-api-key' => $key,
    Content => encode_json({
        text => $text,
        model_id => "eleven_multilingual_v2",
        voice_settings => {
            stability => 0.58,
            similarity_boost => 0.72,
            style => 0.18,
            use_speaker_boost => \1  # true in JSON
        }
    });

# Request senden
my $response = $ua->request($req);

# Fehler werfen, wenn Response nicht erfolgreich
die "ElevenLabs fehlgeschlagen: " . $response->code unless $response->is_success;

# Zielverzeichnis bestimmen und ggf. erstellen
my $script_dir = dirname(abs_path(__FILE__));
my $project_root = dirname($script_dir);
my $audio_dir = File::Spec->catdir($project_root, 'public', 'audio');
make_path($audio_dir) unless -d $audio_dir;

# Audiodatei speichern
my $audio_file = File::Spec->catfile($audio_dir, 'project-narration.mp3');
open my $fh, '>', $audio_file or die "Konnte Datei nicht öffnen: $!";
print $fh $response->content;
close $fh;

# JSON-Ergebnisdatei schreiben
my $result_data = {
    model => "eleven_multilingual_v2",
    voiceId => $voiceId,
    characters => length($text),
    text => $text,
    output => "public/audio/project-narration.mp3"
};

my $json_output = JSON->new->pretty->encode($result_data);
my $json_file = File::Spec->catfile($project_root, 'media-production', 'elevenlabs-result.json');
open my $json_fh, '>', $json_file or die "Konnte JSON-Datei nicht öffnen: $!";
print $json_fh $json_output;
close $json_fh;

print "ElevenLabs abgeschlossen: " . length($text) . " Zeichen.\n";

# Hilfsfunktion für dirname (ähnlich node:path)
sub dirname {
    my ($path) = @_;
    $path =~ s/[\/\\][^\/\\]*$//;
    return $path || '.';
}
