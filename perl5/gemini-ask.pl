#!/usr/bin/perl
# gemini-ask.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway1:scripts/gemini-ask.js
# auch in: OpenClaw@gateway2:scripts/gemini-ask.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use JSON qw(decode_json encode_json);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Getopt::Long qw(GetOptions);
use File::Basename qw(basename);
use Encode qw(decode);

# gemini-ask.pl - CLI tool for Google Gemini API
# 
# Usage:
#   perl gemini-ask.pl "Your question here"
#   echo "Your question" | perl gemini-ask.pl
#   perl gemini-ask.pl --file prompt.txt
#   perl gemini-ask.pl --model gemini-pro "Your question"
# 
# Environment:
#   GEMINI_API_KEY - Required API key
#   GEMINI_MODEL   - Optional default model (default: gemini-pro)

my $DEFAULT_MODEL = $ENV{'GEMINI_MODEL'} || 'gemini-pro';

sub main {
    # Check API key
    my $api_key = $ENV{'GEMINI_API_KEY'};
    if (!$api_key) {
        print STDERR "Error: GEMINI_API_KEY environment variable is required\n";
        exit 1;
    }

    # Parse arguments
    my $prompt = '';
    my $modelName = $DEFAULT_MODEL;
    my $systemPrompt = '';
    my $file_path = '';
    my @remaining_args;

    GetOptions(
        'model|m=s'  => \$modelName,
        'system|s=s' => \$systemPrompt,
        'file|f=s'   => \$file_path,
        '<>'         => sub { push @remaining_args, $_[0] }
    ) or die "Error in command line arguments\n";

    if ($file_path) {
        open my $fh, '<:encoding(UTF-8)', $file_path
            or die "Error: Cannot read file '$file_path': $!\n";
        {
            local $/;
            $prompt = <$fh>;
        }
        close $fh;
    } elsif (@remaining_args) {
        $prompt = join(' ', @remaining_args);
    } elsif (!-t STDIN) {
        # Read from stdin
        my @chunks;
        while (my $chunk = <STDIN>) {
            push @chunks, $chunk;
        }
        $prompt = join('', @chunks);
    }

    if (!$prompt || !length($prompt)) {
        print STDERR "Error: No prompt provided\n";
        print STDERR "Usage: gemini-ask \"your question\"\n";
        print STDERR "       gemini-ask --model gemini-pro \"your question\"\n";
        print STDERR "       echo \"your question\" | gemini-ask\n";
        exit 1;
    }

    eval {
        # Prepare generation config
        my $generationConfig = {
            maxOutputTokens => 8192,
            temperature     => 0.7,
            topP           => 0.95,
        };

        my $ua = LWP::UserAgent->new;
        $ua->timeout(60);

        my $url;
        my $req;
        my $response;

        if ($systemPrompt) {
            # Use chat with system prompt
            $url = "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$api_key";
            
            my $data = {
                contents => [
                    { role => 'user', parts => [{ text => $systemPrompt }] },
                    { role => 'model', parts => [{ text => 'Understood. I will follow that instruction.' }] },
                    { role => 'user', parts => [{ text => $prompt }] }
                ],
                generationConfig => $generationConfig
            };
            
            $req = POST $url,
                'Content-Type' => 'application/json',
                'Content'      => encode_json($data);
                
            $response = $ua->request($req);
        } else {
            # Direct generation
            $url = "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$api_key";
            
            my $data = {
                contents => [
                    { role => 'user', parts => [{ text => $prompt }] }
                ],
                generationConfig => $generationConfig
            };
            
            $req = POST $url,
                'Content-Type' => 'application/json',
                'Content'      => encode_json($data);
                
            $response = $ua->request($req);
        }

        if ($response->is_success) {
            my $json_response = decode_json($response->decoded_content);
            if (exists $json_response->{candidates} && @{$json_response->{candidates}} > 0) {
                my $text = $json_response->{candidates}[0]->{content}->{parts}[0]->{text};
                print "$text\n";
            } else {
                die "No content returned from API";
            }
        } else {
            my $status = $response->code;
            my $message = $response->decoded_content;
            die "HTTP $status: $message";
        }
    };
    
    if ($@) {
        my $error = $@;
        chomp $error;
        print STDERR "Error: $error\n";
        if ($error =~ /API key/) {
            print STDERR "Make sure GEMINI_API_KEY is set correctly\n";
        }
        exit 1;
    }
}

main();
