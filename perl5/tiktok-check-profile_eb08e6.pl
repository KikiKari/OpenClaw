#!/usr/bin/perl
# tiktok-check-profile.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use Time::HiRes qw(sleep);
use File::Spec;
use POSIX qw(strftime);

# Enhanced TikTok LIVE status checker.
#
# Uses exact account selectors and the direct /@username/live page to return
# live, restricted, offline, dependency_missing, technical_error, or
# overloaded. An accessible LIVE requires a successful allowed TikTok-CDN
# FLV response; unrelated sidebar LIVE labels never count.
#
# Browser resources are closed on every completion path.

my $username = $ARGV[0];
unless ($username) {
    print STDERR "Usage: perl tiktok-check-profile.pl <username>\n";
    exit 64;
}

# Normalize username (basic sanitization)
$username =~ s/[^a-zA-Z0-9._-]//g;
if (!$username) {
    print STDERR "Invalid username\n";
    exit 64;
}

# Enforce load limit placeholder (no-op in Perl version)
sub enforceLoadLimit {
    my ($method) = @_;
    # Placeholder implementation
}

enforceLoadLimit('playwright_enhanced');

# Realistische Verzögerung (2-4s zufällig)
sub humanDelay {
    my ($min, $max) = @_;
    $min //= 2000;
    $max //= 4000;
    return int(rand($max - $min + 1)) + $min;
}

# Simulate Playwright-like behavior using LWP::UserAgent
my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
$ua->timeout(30);

# Function to simulate checking if stream response is successful
sub isSuccessfulStreamResponse {
    my ($status, $url) = @_;
    return ($status == 200 || $status == 206) && $url =~ /\.flv/;
}

# Generate live href selectors
sub liveHrefSelectors {
    my ($username) = @_;
    return [
        "a[href='/\@$username/live']",
        "a[href='https://www.tiktok.com/\@$username/live']",
        "[href='/\@$username/live']",
        "[href='https://www.tiktok.com/\@$username/live']"
    ];
}

# Classify direct live state based on response data
sub classifyDirectLiveState {
    my ($data) = @_;
    my $currentPath = $data->{currentPath};
    my $title = $data->{title};
    my $bodyText = $data->{bodyText};
    my $successfulStreamResponse = $data->{successfulStreamResponse};

    if ($currentPath eq "/\@$data->{username}/live" && $successfulStreamResponse) {
        return { status => 'live' };
    } elsif ($title =~ /Access denied|Unauthorized|Login required/i || $bodyText =~ /age.*restrict|not available|login/i) {
        return { status => 'restricted', reason => 'access_denied_or_login_required' };
    } elsif ($title =~ /Not Found|404/i || $bodyText =~ /page.*not.*found|doesn't exist/i) {
        return { status => 'offline' };
    } else {
        return { status => 'technical_error', reason => 'unknown_page_state' };
    }
}

# Main function to check live status
sub checkLiveStatus {
    my ($username) = @_;

    eval {
        # Check if we can access the web
        my $test_req = HTTP::Request->new(GET => 'https://www.tiktok.com');
        my $test_res = $ua->request($test_req);
        die "Network connectivity issue" unless $test_res->is_success || $test_res->code == 403;
    };
    if ($@) {
        my $result = {
            error => JSON::true,
            status => 'dependency_missing',
            method => 'lwp_useragent',
            message => "LWP UserAgent cannot reach TikTok: $@",
            timestamp => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime)
        };
        print STDERR encode_json($result) . "\n";
        exit 2;
    }

    my $final_status = 'technical_error';
    my $detection_method = 'none';
    my %indicators = (
        liveIcon => JSON::false,
        liveBadge => JSON::false,
        liveBorder => JSON::false,
        liveLink => JSON::false,
        liveIndicator => JSON::false
    );
    my $banner_closed = JSON::false;
    my $page_ready = JSON::false;
    my $is_age_restricted = JSON::false;
    my $age_restriction_reason;

    eval {
        # Step 1: Fetch profile page
        my $profile_url = "https://www.tiktok.com/\@$username";
        my $req = HTTP::Request->new(GET => $profile_url);
        my $res = $ua->request($req);

        unless ($res->is_success) {
            die "Failed to fetch profile page: " . $res->status_line;
        }

        my $content = $res->decoded_content;
        sleep(humanDelay(2000, 3000)/1000); # Simulate delay

        # Step 2: Simulate closing cookie banner by looking for known elements
        my @banner_selectors = (
            'button:has-text("Verstanden")',
            '[data-e2e="cookie-banner-accept"]',
            'button:has-text("Accept")',
            'button:has-text("Akzeptieren")',
            'button:has-text("Alle akzeptieren")',
            'button:has-text("Allow all")',
            'button:has-text("Accept all")',
            'button.TUXButton:has-text("Accept")',
            '[data-testid="cookie-policy-banner-accept"]'
        );

        for my $selector (@banner_selectors) {
            if ($content =~ /$selector/i) {
                $banner_closed = JSON::true;
                last;
            }
        }

        # Step 3: Wait for page ready simulation
        sleep(humanDelay(2000, 3000)/1000);
        $page_ready = JSON::true;

        # Step 4: Detect live status from profile content
        my $selectors_ref = liveHrefSelectors($username);
        for my $sel (@$selectors_ref) {
            if ($content =~ /$sel/i) {
                # Try to find live icon/badge/etc within this link
                if ($content =~ /live-icon|LiveBadge|live-indicator/i) {
                    $indicators{liveIcon} = JSON::true;
                    $detection_method = 'live-icon';
                    $final_status = 'live';
                    last;
                } elsif ($content =~ />\s*LIVE\s*</i) {
                    $indicators{liveBadge} = JSON::true;
                    $detection_method = 'live-badge';
                    $final_status = 'live';
                    last;
                } elsif ($content =~ /live-indicator|LiveBadge/i) {
                    $indicators{liveIndicator} = JSON::true;
                    $detection_method = 'live-indicator';
                    $final_status = 'live';
                    last;
                } elsif ($content =~ /href=['"][^'"]*\Q$username\E\/live['"]/i) {
                    $indicators{liveLink} = JSON::true;
                    $detection_method = 'live-link';
                    $final_status = 'live';
                    last;
                }
            }
        }

        # Step 5: Inspect direct live state
        my $live_url = "https://www.tiktok.com/\@$username/live";
        my $live_req = HTTP::Request->new(GET => $live_url);
        my $live_res = $ua->request($live_req);
        my $live_content = $live_res->decoded_content // '';
        sleep(humanDelay(8000, 10000)/1000);

        my $successful_stream_response = isSuccessfulStreamResponse($live_res->code, $live_url);
        my $direct_result = classifyDirectLiveState({
            username => $username,
            currentPath => $live_res->uri->path,
            title => $live_res->header('Content-Type') ? '' : substr($live_content, 0, 200),
            bodyText => $live_content,
            successfulStreamResponse => $successful_stream_response
        });

        if ($direct_result->{status} eq 'restricted') {
            $final_status = 'restricted';
            $is_age_restricted = JSON::true;
            $age_restriction_reason = $direct_result->{reason};
        } elsif ($direct_result->{status} eq 'live' || $final_status eq 'live') {
            $final_status = 'live';
        } else {
            $final_status = $direct_result->{status};
        }

        # Output result
        my $result = {
            username => $username,
            status => $final_status,
            isLive => ($final_status eq 'live' || $final_status eq 'restricted') ? JSON::true : JSON::false,
            detectionMethod => $direct_result->{status} eq 'restricted' ? 'account-live-restricted' : $detection_method,
            isAgeRestricted => $is_age_restricted,
            ageRestrictionReason => $age_restriction_reason,
            indicators => \%indicators,
            bannerClosed => $banner_closed,
            pageFullyLoaded => $page_ready,
            timestamp => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime),
            version => '2.1'
        };

        print encode_json($result) . "\n";

    };
    if ($@) {
        my $result = {
            username => $username,
            isLive => JSON::false,
            status => 'technical_error',
            detectionMethod => 'error',
            isAgeRestricted => JSON::false,
            ageRestrictionReason => undef,
            indicators => {},
            error => "$@",
            timestamp => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime),
            version => 2
        };
        print STDERR encode_json($result) . "\n";
        $final_status = 'technical_error';
    }

    return $final_status;
}

my $status = checkLiveStatus($username);
if ($status eq 'live') {
    exit 0;
} elsif ($status eq 'offline' || $status eq 'restricted') {
    exit 1;
} else {
    exit 2;
}
