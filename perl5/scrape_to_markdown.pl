#!/usr/bin/perl
# scrape_to_markdown.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# auch in: OpenClaw@gateway2:skills/web-markdown-scraper/scripts/scrape_to_markdown.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use utf8;
use JSON qw(decode_json encode_json);
use URI::URL;
use HTML::TreeBuilder;
use LWP::UserAgent;
use Getopt::Long;
use File::Path qw(make_path);
use File::Spec;
use Encode qw(decode encode);

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

sub to_str {
    my ($value) = @_;
    return "" unless defined $value;
    return decode("UTF-8", $value) if ref($value) eq 'SCALAR' && ref($value) =~ /GLOB|IO/;
    return "$value";
}

sub slugify {
    my ($text, $max_len) = @_;
    $max_len //= 80;
    $text =~ s/[^\w\s\-]//g;
    $text =~ s/[\-\s]+/-/g;
    $text = substr(lc($text), 0, $max_len);
    $text =~ s/^-+|-+$//g;
    return $text || "page";
}

sub extract_html {
    my ($obj) = @_;
    return "" unless defined $obj;

    my @attrs = qw(html raw_html content markup body inner_html);
    for my $attr (@attrs) {
        if (exists $obj->{$attr}) {
            my $value = $obj->{$attr};
            my $text = to_str($value);
            return $text if $text && $text =~ /</ && $text =~ />/;
        }
    }

    my $text = to_str($obj);
    return ($text =~ /</ && $text =~ />/) ? $text : "";
}

sub extract_title {
    my ($html) = @_;
    return "" unless $html;
    if ($html =~ /<title[^>]*>(.*?)<\/title>/si) {
        my $title = $1;
        $title =~ s/<[^>]+>/ /g;
        $title =~ s/\s+/ /g;
        return $title =~ s/^\s+|\s+$//gr;
    }
    return "";
}

sub fetch_page {
    my ($url, $js, $wait_selector, $timeout, $automatch_domain) = @_;
    $timeout //= 30;

    my $ua = LWP::UserAgent->new;
    $ua->timeout($timeout);
    my $response = $ua->get($url);

    if ($response->is_success) {
        return {
            content => $response->decoded_content,
            status => $response->code,
        }, "LWP::UserAgent.get";
    } else {
        die "HTTP Error: " . $response->status_line;
    }
}

sub pick_main_html {
    my ($page, $preferred_selector) = @_;
    my @selectors = $preferred_selector ? ($preferred_selector) : ();
    push @selectors, qw(article main [role='main'] .post-content .entry-content .article-content body);

    my $html = $page->{content} || "";
    return $html, undef;
}

sub html_to_markdown {
    my ($html, $preserve_links, $body_width) = @_;
    $body_width //= 0;

    # Simple HTML to Markdown conversion
    $html =~ s/<\/?(?:div|p)[^>]*>/\n/gi;
    $html =~ s/<br\s*\/?>/\\n/gi;
    $html =~ s/<[^>]+>//g unless $preserve_links;
    $html =~ s/\n{3,}/\n\n/g;
    $html =~ s/^\s+|\s+$//g;

    return $html;
}

sub load_urls {
    my ($url_args, $url_file) = @_;
    my @urls = @$url_args;
    if ($url_file) {
        open my $fh, '<:encoding(UTF-8)', $url_file or die "Cannot open $url_file: $!";
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
            push @urls, $line;
        }
        close $fh;
    }
    my %seen;
    my @clean = grep { !$seen{$_}++ } @urls;
    return \@clean;
}

sub validate_url {
    my ($url) = @_;
    my $parsed = URI::URL->new($url);
    return $parsed && $parsed->scheme =~ /^(http|https)$/ && $parsed->netloc;
}

sub main {
    my @urls;
    my $url_file = "";
    my $selector = "";
    my $js = 0;
    my $wait_selector = "";
    my $preserve_links = 0;
    my $body_width = 0;
    my $timeout = 30;
    my $output_dir = "outputs";
    my $automatch_domain = "";

    GetOptions(
        "url=s@" => \@urls,
        "url-file=s" => \$url_file,
        "selector=s" => \$selector,
        "js!" => \$js,
        "wait-selector=s" => \$wait_selector,
        "preserve-links!" => \$preserve_links,
        "body-width=i" => \$body_width,
        "timeout=i" => \$timeout,
        "output-dir=s" => \$output_dir,
        "automatch-domain=s" => \$automatch_domain,
    ) or die "Error in command line arguments\n";

    my $urls_ref = load_urls(\@urls, $url_file);
    if (!@$urls_ref) {
        print encode_json({ ok => JSON::false, error => "No URLs provided" }) . "\n";
        exit 1;
    }

    for my $url (@$urls_ref) {
        if (!validate_url($url)) {
            print encode_json({ ok => JSON::false, error => "Invalid URL: $url" }) . "\n";
            exit 1;
        }
    }

    make_path($output_dir) unless -d $output_dir;

    my @results;

    for my $url (@$urls_ref) {
        my %item = (
            url => $url,
            ok => JSON::false,
            title => "",
            status => undef,
            selector_used => undef,
            backend => undef,
            markdown => "",
            preview => "",
            output_markdown_file => undef,
            error => undef,
        );

        eval {
            my ($page, $backend) = fetch_page(
                $url,
                $js,
                $wait_selector || undef,
                $timeout,
                $automatch_domain || undef,
            );
            my ($html, $selector_used) = pick_main_html($page, $selector || undef);
            die "No HTML content extracted from page" unless $html;

            my $title = extract_title($html) || do {
                my $u = URI::URL->new($url);
                $u->netloc;
            };

            my $markdown = html_to_markdown(
                $html,
                $preserve_links,
                $body_width,
            );

            my $filename = slugify("$url-$title") . ".md";
            my $md_path = File::Spec->catfile($output_dir, $filename);
            open my $fh, '>:encoding(UTF-8)', $md_path or die "Cannot write to $md_path: $!";
            print $fh $markdown;
            close $fh;

            my $status = $page->{status};

            %item = (
                %item,
                ok => JSON::true,
                title => $title,
                status => $status,
                selector_used => $selector_used,
                backend => $backend,
                markdown => $markdown,
                preview => substr($markdown, 0, 1200),
                output_markdown_file => $md_path,
            );
        };
        if ($@) {
            $item{error} = "$@";
        }

        push @results, \%item;
    }

    my $ok = grep { $_->{ok} } @results;
    my $index_path = File::Spec->catfile($output_dir, "index.json");
    my %payload = (
        ok => $ok ? JSON::true : JSON::false,
        count => scalar(@results),
        success_count => scalar(grep { $_->{ok} } @results),
        failure_count => scalar(grep { !$_->{ok} } @results),
        output_index_file => $index_path,
        results => \@results,
    );

    open my $fh, '>:encoding(UTF-8)', $index_path or die "Cannot write to $index_path: $!";
    print $fh encode_json(\%payload);
    close $fh;

    print encode_json(\%payload) . "\n";
}

main() unless caller;
