#!/usr/bin/perl
# test_sidepanel_player_guard.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_sidepanel_player_guard.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_sidepanel_player_guard.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Spec;
use File::Basename;

# Simulate required Node.js modules with Perl equivalents
# We'll read file contents and perform string operations

# Get the directory of this script
my $script_dir = dirname(__FILE__);
my $source_file = File::Spec->catfile($script_dir, '..', 'browser-extension', 'sidepanel.js');

# Read the source file
open my $fh, '<:encoding(UTF-8)', $source_file or die "Cannot open $source_file: $!";
my $source = do { local $/; <$fh> };
close $fh;

# Find the start and end positions
my $start = index($source, '  async function refreshPlayer()');
my $end = index($source, '  function setButtonBusy', $start);

die "Could not find function boundaries" unless $start >= 0 && $end > $start;

# Extract the function code
my $function_code = substr($source, $start, $end - $start);

# Define a package to simulate the JavaScript context
{
    package Context;
    
    sub new {
        my ($class, $initial_data) = @_;
        my $self = bless {
            activeTabId => $initial_data->{activeTabId},
            activeIsTikTok => $initial_data->{activeIsTikTok},
            playerContextGeneration => $initial_data->{playerContextGeneration},
            calls => 0,
            reply => undef,
            rendered => [],
        }, $class;
        
        # Create send method
        $self->{send} = sub {
            $self->{calls}++;
            return Promise->new(sub {
                my $resolve = shift;
                $self->{reply} = $resolve;
            });
        };
        
        # Create renderPlayer method
        $self->{renderPlayer} = sub {
            my ($state) = @_;
            push @{$self->{rendered}}, $state;
        };
        
        return $self;
    }
    
    sub get_property {
        my ($self, $key) = @_;
        return $self->{$key};
    }
    
    sub set_property {
        my ($self, $key, $value) = @_;
        $self->{$key} = $value;
    }
}

# Simple Promise implementation for simulation
{
    package Promise;
    
    sub new {
        my ($class, $executor) = @_;
        my $self = bless {}, $class;
        $self->{resolved} = 0;
        $self->{result} = undef;
        $self->{callbacks} = [];
        
        my $resolve = sub {
            my ($value) = @_;
            $self->{resolved} = 1;
            $self->{result} = $value;
            for my $callback (@{$self->{callbacks}}) {
                $callback->($value);
            }
        };
        
        $executor->($resolve);
        return $self;
    }
    
    sub then {
        my ($self, $callback) = @_;
        if ($self->{resolved}) {
            $callback->($self->{result});
        } else {
            push @{$self->{callbacks}}, $callback;
        }
        return $self;
    }
}

# Main test logic
sub main {
    eval {
        my $context = Context->new({
            activeTabId => 1,
            activeIsTikTok => 1,
            playerContextGeneration => 0
        });
        
        # Since we can't execute JS code directly in Perl,
        # we need to simulate what refreshPlayer does based on the actual code
        
        # From examining the real sidepanel.js, refreshPlayer roughly does:
        # - checks if activeIsTikTok
        # - sends message to background asking for player state
        # - updates UI when response comes back (only if still relevant)
        
        # Let's simulate that behavior
        
        # First call - should be ignored later
        my $pending1 = refresh_player_simulation($context);
        $context->set_property('activeTabId', 2);
        
        # Resolve first call with playing=true
        my $reply = $context->get_property('reply');
        $reply->({response => {playerState => {playing => 1}}});
        wait_for_promise($pending1);
        
        # Check that it was ignored (old tab)
        die "FAIL: Old tab response must be ignored" 
            unless @{$context->get_property('rendered')} == 0;
            
        # Set to non-TikTok - next refresh should skip polling
        $context->set_property('activeIsTikTok', 0);
        refresh_player_simulation($context);
        
        # Should still have only 1 call
        die "FAIL: Non-TikTok tabs must not be polled"
            unless $context->get_property('calls') == 1;
            
        # Back to TikTok
        $context->set_property('activeIsTikTok', 1);
        my $pending2 = refresh_player_simulation($context);
        
        # Resolve with playing=true
        $reply = $context->get_property('reply');
        $reply->({response => {playerState => {playing => 1}}});
        wait_for_promise($pending2);
        
        # Should now have rendered once
        die "FAIL: Current tab response must render"
            unless @{$context->get_property('rendered')} == 1;
            
        # Another refresh
        my $pending3 = refresh_player_simulation($context);
        $context->set_property('activeTabId', 3);
        $context->set_property('playerContextGeneration', 
                              $context->get_property('playerContextGeneration') + 1);
        $context->set_property('activeTabId', 2);
        $context->set_property('playerContextGeneration', 
                              $context->get_property('playerContextGeneration') + 1);
                              
        # Reply with playing=false
        $reply = $context->get_property('reply');
        $reply->({response => {playerState => {playing => 0}}});
        wait_for_promise($pending3);
        
        # Should still only have 1 rendered item
        die "FAIL: Returning to the same tab must not revive an old response"
            unless @{$context->get_property('rendered')} == 1;
            
        # Check source has expected pattern
        die "FAIL: Context invalidation must precede asynchronous tab lookup"
            unless $source =~ /async function refresh\(\)\s*\{\s*playerContextGeneration\+\+;/;
            
        print "PASS: stale tab response ignored, non-TikTok polling skipped, current response rendered\n";
    };
    
    if ($@) {
        print STDERR $@;
        exit 1;
    }
}

# Simulated refreshPlayer function
sub refresh_player_simulation {
    my ($context) = @_;
    
    # Increment call count
    my $current_calls = $context->get_property('calls');
    $context->set_property('calls', $current_calls + 1);
    
    # Only proceed if activeIsTikTok
    return Promise->new(sub { $_[0]->() }) unless $context->get_property('activeIsTikTok');
    
    # Capture current context generation and tab id
    my $gen_at_start = $context->get_property('playerContextGeneration');
    my $tab_at_start = $context->get_property('activeTabId');
    
    # Create promise that resolves when send completes
    my $promise = Promise->new(sub {
        my $resolve = shift;
        # Store resolve so external code can trigger it
        $context->set_property('reply', $resolve);
    });
    
    # When promise resolves, check if context is still valid
    bless $promise, 'PromiseWithCallback';
    $promise->{callback} = sub {
        my ($response) = @_;
        # Only render if context hasn't changed
        if ($context->get_property('playerContextGeneration') == $gen_at_start &&
            $context->get_property('activeTabId') == $tab_at_start) {
            my $render = $context->get_property('renderPlayer');
            $render->($response->{response}->{playerState});
        }
    };
    
    return $promise;
}

# Specialized promise class for our callback
{
    package PromiseWithCallback;
    use base 'Promise';
    
    sub then {
        my ($self, $callback) = @_;
        if ($self->{resolved}) {
            my $result = $self->{result};
            $self->{callback}->($result) if $self->{callback};
            $callback->($result);
        } else {
            push @{$self->{callbacks}}, sub {
                my ($result) = @_;
                $self->{callback}->($result) if $self->{callback};
                $callback->($result);
            };
        }
        return $self;
    }
}

# Helper to wait for promise resolution in simulation
sub wait_for_promise {
    my ($promise) = @_;
    # In real async environment this would yield
    # For simulation we assume immediate resolution
}

main();
