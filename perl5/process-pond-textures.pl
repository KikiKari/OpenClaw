#!/usr/bin/perl
# process-pond-textures.py — portiert nach perl5
# Quelle: python, Onboarding@main:scripts/process-pond-textures.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Path qw(make_path);
use Image::Magick;

my $BASE = "public/media/pond";
my $OUT = "public/media/pond/processed";

make_path($OUT) unless -d $OUT;

sub key_out {
    my ($path, $out, $mode, $feather) = @_;
    $feather //= 2.0;

    my $im = Image::Magick->new();
    $im->Read($path);
    $im->Set(colorspace => 'RGB');

    # Create a new image for alpha channel
    my $alpha = Image::Magick->new();
    $alpha->Set(size => $im->Get('width') . 'x' . $im->Get('height'));
    $alpha->Read('xc:black');

    if ($mode eq "green") {
        # Dark-green background: low overall brightness AND green-dominant-but-dark.
        # Foreground leaf is much brighter / lighter green.
        for my $y (0 .. $im->Get('height') - 1) {
            for my $x (0 .. $im->Get('width') - 1) {
                my @pixel = $im->GetPixel(x => $x, y => $y);
                my ($r, $g, $b) = map { $_ * 255 } @pixel[0..2];
                my $lum = ($r + $g + $b) / 3.0;
                # background pixels: very dark (lum < ~35) — the bg is ~(3,50,0)=17
                my $bg = $lum < 40.0;
                my $alpha_val = $bg ? 0 : 255;
                $alpha->SetPixel(x => $x, y => $y, color => "rgb($alpha_val,$alpha_val,$alpha_val)");
            }
        }
    } elsif ($mode eq "white") {
        # White background: near-white, low saturation.
        for my $y (0 .. $im->Get('height') - 1) {
            for my $x (0 .. $im->Get('width') - 1) {
                my @pixel = $im->GetPixel(x => $x, y => $y);
                my ($r, $g, $b) = map { $_ * 255 } @pixel[0..2];
                my $mn = min($r, $g, $b);
                my $mx = max($r, $g, $b);
                # background: bright and low chroma
                my $white = ($mn > 218.0) && (($mx - $mn) < 28.0);
                my $alpha_val = $white ? 0 : 255;
                $alpha->SetPixel(x => $x, y => $y, color => "rgb($alpha_val,$alpha_val,$alpha_val)");
            }
        }
    } else {
        die "Unknown mode: $mode\n";
    }

    # Feather the mask edges to avoid hard aliasing.
    $alpha->Blur(radius => $feather);

    # Add alpha channel to original image
    $im->Composite(image => $alpha, compose => 'CopyOpacity');

    # Trim to content to keep the plane tight and reduce empty texels.
    $im->Trim();

    # Save as PNG
    $im->Set(format => 'png');
    $im->Write($out);

    my ($name) = $path =~ m|([^/]+)$|;
    my ($out_name) = $out =~ m|([^/]+)$|;
    print "$name -> $out_name " . $im->Get('width') . "x" . $im->Get('height') . " ($mode)\n";
}

sub min {
    my ($a, $b, $c) = @_;
    my $min = $a;
    $min = $b if $b < $min;
    $min = $c if $c < $min;
    return $min;
}

sub max {
    my ($a, $b, $c) = @_;
    my $max = $a;
    $max = $b if $b > $max;
    $max = $c if $c > $max;
    return $max;
}

# Lily pads
key_out("$BASE/blaetter/12130585.webp", "$OUT/leaf-a.png", "green");
key_out("$BASE/blaetter/48178242.webp", "$OUT/leaf-b.png", "white");

# Blossoms with white backgrounds -> clean cutouts (only these two key cleanly)
key_out("$BASE/blueten/78370994.webp", "$OUT/blossom-a.png", "white", 3.0);
key_out("$BASE/blueten/70017289.webp", "$OUT/blossom-b.png", "white", 3.0);

print "done\n";
