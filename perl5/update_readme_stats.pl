#!/usr/bin/perl
# update_readme_stats.py — portiert nach perl5
# Quelle: python, OpenClaw@main:scripts/update_readme_stats.py
# Erzeugt: 2026-08-24 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use LWP::UserAgent;
use JSON qw(decode_json);
use File::Slurp qw(read_file write_file);

my $API_BASE = "https://clawhub.ai/api/v1";
my $TOKEN = $ENV{"CLAWHUB_TOKEN"} // "";

my @SKILLS = (
    ["Cluster Gateway",           "cluster-gateway"],
    ["MCP Tool Utils",            "mcp-tool-utils"],
    ["Reports Creator",           "reports-creator"],
    ["Relay Node",                "relay-node"],
    ["JSON Utils",                "json-utils"],
    ["Log Collector",             "log-collector"],
    ["TikTok Live Monitor",       "tiktok-live-monitor"],
    ["Doc Scraper",               "doc-scraper"],
    ["Workspace Database Manager","workspace-database-manager"],
    ["Scripting Utils",           "scripting-utils"],
);

sub fetch_skill {
    my ($slug) = @_;
    my $url = "$API_BASE/skills/$slug";
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    my $req = HTTP::Request->new(GET => $url);
    $req->header('Accept' => 'application/json');
    if ($TOKEN) {
        $req->header('Authorization' => "Bearer $TOKEN");
    }
    my $res = $ua->request($req);
    if ($res->is_success) {
        return decode_json($res->decoded_content);
    } else {
        die "HTTP GET error: " . $res->status_line;
    }
}

sub parse_skill {
    my ($data) = @_;
    my $skill = $data->{"skill"} // {};
    my $stats = $skill->{"stats"} // {};
    my $version_data = $data->{"latestVersion"} // {};
    my $version = $version_data->{"version"} // "1.0.0";
    my $mod = $data->{"moderation"};

    my $downloads = $stats->{"downloads"} // 0;

    my $security;
    if (!defined $mod) {
        $security = "✅ Pass";
    } elsif ($mod->{"isMalwareBlocked"}) {
        $security = "🚫 Blocked";
    } else {
        $security = "🔍 Review";
    }

    if (!$version =~ /^v/) {
        $version = "v$version";
    }

    return {
        "downloads" => $downloads,
        "version"   => $version,
        "security"  => $security,
    };
}

sub main {
    my %stats = ();
    my $errors = 0;
    foreach my $entry (@SKILLS) {
        my ($name, $slug) = @$entry;
        eval {
            my $data = fetch_skill($slug);
            my $s = parse_skill($data);
            $stats{$slug} = $s;
            print "  OK  $slug: $s->{downloads} downloads, $s->{version}, $s->{security}\n";
        };
        if ($@) {
            warn "  ERR $slug: $@\n";
            $errors++;
        }
    }

    if (keys %stats == 0) {
        warn "No data fetched — aborting.\n";
        exit 1;
    }

    my $content = read_file("README.md", binmode => ':utf8');

    foreach my $entry (@SKILLS) {
        my ($name, $slug) = @$entry;
        if (!exists $stats{$slug}) {
            next;
        }
        my $dl = $stats{$slug}->{"downloads"};
        my $pattern = qr/(\|\s*\[?\Q$name\E\]?[^|]*\|[^|]*\|)\s*\d+\s*(\|)/i;
        my $replacement = "\$1 $dl \$2";
        $content =~ s/$pattern/$replacement/egi;
    }

    write_file("README.md", {binmode => ':utf8'}, $content);
    print "Done: " . scalar(keys %stats) . " skills, $errors errors.\n";
}

main() if __FILE__ eq $0;
