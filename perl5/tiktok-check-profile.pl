#!/usr/bin/perl
# tiktok-check-profile.js — portiert nach perl5
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live/scripts/tiktok-check-profile.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON;
use Time::HiRes qw(sleep);
use File::Spec;
use Fcntl ':mode';
use HTTP::Tiny;
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;

# /**
#  * Basic TikTok LIVE profile checker.
#  *
#  * Scopes every signal to the requested account and ignores unrelated sidebar
#  * LIVE labels. This profile-only checker does not classify restricted LIVE;
#  * use the enhanced checker or dispatcher for that distinction.
#  *
#  * Exit 0 = account-specific LIVE, 1 = offline, 2 = dependency/technical
#  * failure, 75 = overloaded before Playwright startup.
#  */

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my $username = shift @ARGV;
unless ($username) {
    print STDERR "Usage: perl tiktok-check-profile.pl <username>\n";
    print STDERR "Username required\n";
    exit 64;
}

$username =~ s/[^a-zA-Z0-9_.]/_/g;
$username =~ s/^_+|_+$//g;

sub enforce_load_limit {
    my ($method) = @_;
    # Placeholder for load limiting logic if needed
}

enforce_load_limit('playwright_basic');

sub check_live_status {
    my ($username) = @_;
    
    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    $ua->timeout(30);
    
    my $url = "https://www.tiktok.com/\@$username";
    my $response = $ua->get($url);
    
    unless ($response->is_success) {
        print STDERR encode_json({
            error => JSON::true,
            status => 'technical_error',
            message => $response->status_line,
            timestamp => scalar localtime
        }) . "\n";
        return undef;
    }
    
    my $content = $response->decoded_content;
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($content);
    $tree->eof;
    
    sleep(2); # Wait for initial page build
    
    # Try to close cookie banners by looking for common accept buttons
    my @cookie_selectors = (
        '//button[contains(text(), "Verstanden")]',
        '//*[@data-e2e="cookie-banner-accept"]',
        '//button[contains(text(), "Accept")]',
        '//button[contains(text(), "Akzeptieren")]',
        '//button[contains(text(), "Alle akzeptieren")]',
        '//button[contains(text(), "Allow all")]',
        '//button[contains(text(), "Accept all")]',
        '//button[contains(@class, "TUXButton") and contains(text(), "Accept")]',
        '//*[@data-testid="cookie-policy-banner-accept"]'
    );
    
    foreach my $xpath (@cookie_selectors) {
        my $btn = $tree->findvalue($xpath);
        if ($btn) {
            # In real implementation, we would click here
            sleep(1);
            last;
        }
    }
    
    sleep(3); # Wait for full loading
    
    sleep(2); # Additional wait for TikTok's live status check
    
    # Take screenshot for debugging if DEBUG=1
    if ($ENV{DEBUG} && $ENV{DEBUG} eq '1') {
        open my $fh, '>', "/tmp/tiktok-$username.html" or warn "Could not write debug file: $!";
        print $fh $content if $fh;
        close $fh if $fh;
    }
    
    # Method 1: live icon inside the exact account link
    my $live_link_xpath = "//a[contains(\@href, '/\@$username/live')]";
    my $live_link = $tree->findnodes($live_link_xpath)->[0];
    my $has_live_link = defined $live_link;
    
    my $live_icon_visible = 0;
    if ($has_live_link) {
        my $icon = $live_link->findnodes('.//*[@data-e2e="live-icon"] | .//*[contains(@class, "LiveBadge")] | .//*[contains(@class, "live-indicator")]');
        $live_icon_visible = @$icon > 0;
    }
    
    # Method 2: exact LIVE text/badge inside the account link
    my $live_badge_visible = 0;
    if ($has_live_link) {
        my $badges = $live_link->findnodes('.//*[text()="LIVE"]');
        $live_badge_visible = @$badges > 0;
    }
    
    # Method 3: Live-Rahmen am Profilkopf/Avatar
    my @profile_selectors = (
        '//*[@data-e2e="user-page"]//img[@data-e2e="avatar"]',
        '//*[@data-e2e="user-page"]//*[@data-e2e="profile-avatar"]//img',
        '//main//header//img[@data-e2e="avatar"]',
        '//main//header//*[contains(@class, "avatar")]//img'
    );
    
    my $has_live_border = 0;
    foreach my $selector (@profile_selectors) {
        my $profile_img = $tree->findnodes($selector)->[0];
        if ($profile_img) {
            # Simplified style checking - in reality you'd need to parse CSS
            # This is a placeholder for actual implementation
            $has_live_border = 1; # Placeholder
            last;
        }
    }
    
    # Method 4 & 5: live indicator inside that account link
    my $live_indicator_visible = 0;
    if ($has_live_link) {
        my $indicators = $live_link->findnodes('.//*[contains(@class, "live-indicator")] | .//div[contains(@class, "LiveBadge")]');
        $live_indicator_visible = @$indicators > 0;
    }
    
    my $is_live = $has_live_link || $has_live_border || $live_icon_visible || $live_indicator_visible || $live_badge_visible;
    
    print encode_json({
        username => $username,
        isLive => $is_live ? JSON::true : JSON::false,
        timestamp => scalar localtime,
        indicators => {
            liveIcon => $live_icon_visible ? JSON::true : JSON::false,
            liveBadge => $live_badge_visible ? JSON::true : JSON::false,
            liveBorder => $has_live_border ? JSON::true : JSON::false,
            liveLink => $has_live_link ? JSON::true : JSON::false,
            liveIndicator => $live_indicator_visible ? JSON::true : JSON::false
        }
    }) . "\n";
    
    $tree->delete;
    return $is_live;
}

my $result = check_live_status($username);
exit(defined $result ? ($result ? 0 : 1) : 2);
