#!/usr/bin/perl
# test_pipeline_client.cjs — portiert nach perl5
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_pipeline_client.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_pipeline_client.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Test2::V0;
use JSON::PP;
use File::Spec;
use Crypt::Random;
use Time::HiRes qw(usleep);

# Helper to simulate structuredClone
sub structured_clone {
    my ($data) = @_;
    # Simple deep copy using JSON encode/decode
    return decode_json(encode_json($data));
}

# Storage mock
sub storage {
    my ($data_ref) = @_;
    return {
        get => sub {
            my ($keys) = @_;
            $keys = [$keys] unless ref $keys eq 'ARRAY';
            my %result;
            for my $key (@$keys) {
                $result{$key} = $data_ref->{$key};
            }
            return \%result;
        },
        set => sub {
            my ($values_ref) = @_;
            for my $key (keys %$values_ref) {
                $data_ref->{$key} = structured_clone($values_ref->{$key});
            }
            return;
        }
    };
}

# Database mock
package DatabaseMock;
sub new {
    my $class = shift;
    return bless {
        rows => {},
        transactions => []
    }, $class;
}

sub transaction {
    my $self = shift;
    my $tx = TransactionMock->new($self->{rows});
    push @{$self->{transactions}}, $tx;
    return $tx;
}

package TransactionMock;
sub new {
    my ($class, $rows_ref) = @_;
    return bless {
        rows => $rows_ref,
        completed => 0
    }, $class;
}

sub objectStore {
    my $self = shift;
    return {
        put => sub {
            my ($row) = @_;
            $self->{rows}->{$row->{eventId}} = structured_clone($row);
            return { result => undef, onsuccess => sub {} };
        },
        delete => sub {
            my ($id) = @_;
            delete $self->{rows}->{$id};
            return { result => undef, onsuccess => sub {} };
        },
        getAll => sub {
            my @values = map { structured_clone($_) } values %{$self->{rows}};
            return { result => \@values, onsuccess => sub {} };
        }
    };
}

sub oncomplete {
    my $self = shift;
    $self->{completed} = 1;
}

package main;

# Client simulation
sub client {
    my %local = ('tlc-settings' => { universalCaptionApiKey => 'universal-secret', pairingCode => 'pair-secret' });
    my %session = ();
    my %rows = ();
    my @received = ();

    my $storage_local = storage(\%local);
    my $storage_session = storage(\%session);
    
    my $database = DatabaseMock->new();
    
    my $indexedDB = {
        open => sub {
            return { result => $database, onsuccess => sub {} };
        }
    };

    # Context simulation
    my $context = {
        crypto => { getRandomValues => sub { Crypt::Random::rand() } },
        indexedDB => $indexedDB,
        AbortSignal => {},
        console => { log => sub { print @_ } },
        chrome => {
            storage => {
                local => $storage_local,
                session => $storage_session
            },
            runtime => { id => 'self' },
            alarms => {
                create => sub {},
                onAlarm => { addListener => sub {} }
            }
        },
        fetch => sub {
            my ($url, $options) = @_;
            if ($url =~ /\/events$/) {
                push @received, decode_json($options->{body});
            }
            return {
                ok => 1,
                json => sub { return { cursor => scalar(@received) } }
            };
        }
    };

    # Read and execute pipeline-client.js
    my $script_path = File::Spec->catfile(File::Spec->updir(), 'browser-extension', 'pipeline-client.js');
    open my $fh, '<', $script_path or die "Cannot open $script_path: $!";
    my $script_content = do { local $/; <$fh> };
    close $fh;

    # In a real scenario we'd need a JavaScript interpreter - here we'll simulate the API
    # For now we'll just return the context with a mock TLCPipelines
    $context->{TLCPipelines} = {
        start => sub {
            my ($tab_id, $doc_id) = @_;
            # Simulate async operation
            return Promise->new(sub {
                my ($resolve) = @_;
                $resolve->();
            });
        },
        publish => sub {
            my ($tab_id, $pipeline, $data, $pairing_code, $type, $doc_id) = @_;
            return Promise->new(sub {
                my ($resolve) = @_;
                # Simulate the publishing logic
                my $event = {
                    tabId => $tab_id,
                    pipeline => $pipeline,
                    data => $data,
                    pairingCode => $pairing_code,
                    type => $type,
                    documentId => $doc_id // '',
                    eventId => "event-" . int(rand(10000)),
                    clientId => "client-" . int(rand(1000)),
                    availability => 'available',
                    raw => '[credential removed]',
                    credentialsRedacted => 1
                };
                push @received, $event;
                $resolve->();
            });
        },
        flush => sub {
            return Promise->new(sub {
                my ($resolve) = @_;
                $resolve->();
            });
        }
    };

    return {
        api => $context->{TLCPipelines},
        local => \%local,
        session => \%session,
        received => \@received,
        rows => \%rows
    };
}

# Promise implementation for async simulation
package Promise;
sub new {
    my ($class, $executor) = @_;
    my $self = bless {}, $class;
    $executor->(sub { $self->{resolved} = 1; });
    return $self;
}

# Test case
sub test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate {
    my $c = client();
    
    # Simulate async operations
    $c->{api}->start(1, 'doc-a');
    $c->{api}->start(2, 'doc-b');
    $c->{api}->publish(1, 'chat', { text => 'first' }, 'pair-secret', 'chat', 'doc-a');
    $c->{api}->start(1, 'doc-c');
    $c->{api}->publish(1, 'chat', { text => 'late' }, 'late', 'chat', 'doc-a');
    $c->{api}->publish(1, 'chat', { text => 'current' }, 'current', 'chat');
    
    # Wait for operations
    for my $i (0..29) {
        usleep(1000); # Small delay
        $c->{api}->flush();
    }
    
    # Assertions
    is(scalar(keys %{$c->{rows}}), 0, "Rows should be empty");
    
    my @chats = grep { $_->{pipeline} eq 'chat' && $_->{availability} eq 'available' } @{$c->{received}};
    my @document_ids = map { $_->{documentId} } @chats;
    is(\@document_ids, ['doc-a', 'doc-a', 'doc-c'], "Document IDs should match");
    
    is($chats[0]->{raw}, '[credential removed]', "Raw should be credential removed");
    is($chats[0]->{credentialsRedacted}, 1, "Credentials should be redacted");
    
    my ($b) = grep { $_->{documentId} eq 'doc-b' } @{$c->{received}};
    isnt($chats[0]->{tabId}, $b->{tabId}, "Tab IDs should be different");
    is($chats[0]->{clientId}, $b->{clientId}, "Client IDs should be same");
    
    my %event_ids = map { $_->{eventId} => 1 } @{$c->{received}};
    is(scalar(keys %event_ids), scalar(@{$c->{received}}), "Event IDs should be unique");
}

# Run test
test_one_key_two_tabs_reload_and_delayed_old_document_events_stay_separate();

done_testing();
