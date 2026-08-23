#!/usr/bin/perl
# tavily_search.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/tavily/scripts/tavily_search.py
# auch in: OpenClaw@gateway2:skills/tavily/scripts/tavily_search.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use JSON;
use HTTP::Tiny;
use URI::Escape;

=head1 NAME

Tavily AI Search - Optimized search for LLMs and AI applications

=cut

sub search {
    my %args = @_;
    
    my $query = $args{query};
    my $api_key = $args{api_key};
    my $search_depth = $args{search_depth} // "basic";
    my $topic = $args{topic} // "general";
    my $max_results = $args{max_results} // 5;
    my $include_answer = $args{include_answer} // 1;
    my $include_raw_content = $args{include_raw_content} // 0;
    my $include_images = $args{include_images} // 0;
    my $include_domains = $args{include_domains};
    my $exclude_domains = $args{exclude_domains};
    
    # Check if we have an API key
    unless ($api_key) {
        return {
            error => "Tavily API key required. Get one at https://tavily.com",
            setup_instructions => "Set TAVILY_API_KEY environment variable or pass --api-key"
        };
    }
    
    # Prepare the request data
    my $data = {
        api_key => $api_key,
        query => $query,
        search_depth => $search_depth,
        topic => $topic,
        max_results => $max_results,
        include_answer => $include_answer ? JSON::true : JSON::false,
        include_raw_content => $include_raw_content ? JSON::true : JSON::false,
        include_images => $include_images ? JSON::true : JSON::false,
    };
    
    if ($include_domains && @$include_domains) {
        $data->{include_domains} = $include_domains;
    }
    
    if ($exclude_domains && @$exclude_domains) {
        $data->{exclude_domains} = $exclude_domains;
    }
    
    # Convert to JSON
    my $json_text = encode_json($data);
    
    # Make the HTTP request
    my $http = HTTP::Tiny->new;
    my $response = $http->post("https://api.tavily.com/search", {
        headers => {
            'Content-Type' => 'application/json',
        },
        content => $json_text,
    });
    
    if ($response->{success}) {
        my $result = decode_json($response->{content});
        return {
            success => JSON::true,
            query => $query,
            answer => $result->{answer},
            results => $result->{results} || [],
            images => $result->{images} || [],
            response_time => $result->{response_time},
            usage => $result->{usage} || {},
        };
    } else {
        return {
            error => "HTTP Error: " . $response->{status} . " - " . $response->{reason},
            query => $query
        };
    }
}

sub main {
    my $query;
    my $api_key;
    my $depth = "basic";
    my $topic = "general";
    my $max_results = 5;
    my $no_answer = 0;
    my $raw_content = 0;
    my $images = 0;
    my @include_domains;
    my @exclude_domains;
    my $json_output = 0;
    
    GetOptions(
        "query=s"           => \$query,
        "api-key=s"         => \$api_key,
        "depth=s"           => \$depth,
        "topic=s"           => \$topic,
        "max-results=i"     => \$max_results,
        "no-answer"         => \$no_answer,
        "raw-content"       => \$raw_content,
        "images"            => \$images,
        "include-domains=s@" => \@include_domains,
        "exclude-domains=s@" => \@exclude_domains,
        "json"              => \$json_output,
        "help|h"            => sub { print_usage(); exit 0; },
    ) or die "Error in command line arguments\n";
    
    # If no query provided as option, check remaining args
    if (!$query && @ARGV) {
        $query = join(" ", @ARGV);
    }
    
    # Get API key from args or environment
    $api_key //= $ENV{TAVILY_API_KEY};
    
    # Validate inputs
    unless ($query) {
        print STDERR "Error: Search query is required\n";
        print_usage();
        exit 1;
    }
    
    my $result = search(
        query             => $query,
        api_key           => $api_key,
        search_depth      => $depth,
        topic             => $topic,
        max_results       => $max_results,
        include_answer    => !$no_answer,
        include_raw_content => $raw_content,
        include_images    => $images,
        include_domains   => \@include_domains,
        exclude_domains   => \@exclude_domains,
    );
    
    if ($json_output) {
        print encode_json($result) . "\n";
    } else {
        if (exists $result->{error}) {
            print STDERR "Error: $result->{error}\n";
            if (exists $result->{setup_instructions}) {
                print STDERR "\nSetup: $result->{setup_instructions}\n";
            }
            exit 1;
        }
        
        # Format human-readable output
        print "Query: $result->{query}\n";
        print "Response time: " . ($result->{response_time} // 'N/A') . "s\n";
        my $credits = exists $result->{usage}->{credits} ? $result->{usage}->{credits} : 'N/A';
        print "Credits used: $credits\n\n";
        
        if ($result->{answer}) {
            print "=== AI ANSWER ===\n";
            print "$result->{answer}\n\n";
        }
        
        if ($result->{results} && @{$result->{results}}) {
            print "=== RESULTS ===\n";
            for my $i (0 .. $#{$result->{results}}) {
                my $item = $result->{results}[$i];
                my $title = $item->{title} // 'No title';
                print "\n" . ($i+1) . ". $title\n";
                print "   URL: " . ($item->{url} // 'N/A') . "\n";
                printf "   Score: %.3f\n", $item->{score} // 'N/A';
                if ($item->{content}) {
                    my $content = $item->{content};
                    if (length($content) > 200) {
                        $content = substr($content, 0, 200) . "...";
                    }
                    print "   $content\n";
                }
            }
        }
        
        if ($result->{images} && @{$result->{images}}) {
            my $count = scalar(@{$result->{images}});
            print "\n=== IMAGES ($count) ===\n";
            my $limit = @{$result->{images}} < 5 ? @{$result->{images}} : 5;
            for my $i (0 .. $limit-1) {
                print "   $result->{images}[$i]\n";
            }
        }
    }
}

sub print_usage {
    print <<'EOF';
Tavily AI Search - Optimized search for LLMs

Usage: tavily_search.pl [OPTIONS] QUERY

Options:
  --api-key KEY          Tavily API key (or set TAVILY_API_KEY env var)
  --depth basic|advanced Search depth: 'basic' (fast) or 'advanced' (comprehensive)
  --topic general|news  Search topic: 'general' or 'news' (current events)
  --max-results NUM      Maximum number of results (1-10) [default: 5]
  --no-answer            Exclude AI-generated answer summary
  --raw-content          Include raw HTML content of sources
  --images               Include relevant images in results
  --include-domains DOMAINS Include specific domains (space-separated)
  --exclude-domains DOMAINS Exclude specific domains (space-separated)
  --json                 Output raw JSON response
  -h, --help             Show this help message

Examples:
  # Basic search
  tavily_search.pl "What is quantum computing?"
  
  # Advanced search with more results
  tavily_search.pl "Climate change solutions" --depth advanced --max-results 10
  
  # News-focused search
  tavily_search.pl "AI developments" --topic news
  
  # Domain filtering
  tavily_search.pl "Python tutorials" --include-domains python.org --exclude-domains w3schools.com
  
  # Include images in results
  tavily_search.pl "Eiffel Tower" --images

Environment Variables:
  TAVILY_API_KEY    Your Tavily API key (get one at https://tavily.com)
EOF
}

main() unless caller;
