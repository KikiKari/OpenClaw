#!/usr/bin/perl
# irc_bot_syntax.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON;

=head1 NAME

IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).

=head1 DESCRIPTION

Fetches syntax from documentation sources.

=cut

package BotCommand;
use Moose;

has 'bot' => (is => 'ro', isa => 'Str');
has 'command' => (is => 'ro', isa => 'Str');
has 'syntax' => (is => 'ro', isa => 'Str');
has 'example' => (is => 'ro', isa => 'Str');
has 'description' => (is => 'ro', isa => 'Str');
has 'permission' => (is => 'ro', isa => 'Maybe[Str]');

no Moose;
__PACKAGE__->meta->make_immutable;

package IRCBotSyntax;

=head1 SYNOPSIS

IRC Bot command syntax reference.

Sources:

=over 4

=item * pbot: https://github.com/pragma-/pbot

=item * Limnoria: https://docs.limnoria.net/

=item * Eggdrop: https://docs.eggheads.org/

=back

=cut

my %PBOT_COMMANDS = (
    "keyword add" => BotCommand->new(
        bot => "pbot",
        command => "keyword add",
        syntax => "keyword add <keyword> <text>",
        example => "keyword add hello Hello, World!",
        description => "Add a keyword trigger",
        permission => "admin"
    ),
    "fact add" => BotCommand->new(
        bot => "pbot",
        command => "fact add",
        syntax => "fact add <channel> <subject> <text>",
        example => "fact add #channel python Python is a programming language",
        description => "Add a factoid",
        permission => " whitelisted"
    ),
    "ban" => BotCommand->new(
        bot => "pbot",
        command => "ban",
        syntax => "ban <nick|mask> [duration] [reason]",
        example => "ban spambot 1h Spamming",
        description => "Ban a user",
        permission => "op"
    ),
);

my %LIMNORIA_COMMANDS = (
    "config channel" => BotCommand->new(
        bot => "limnoria",
        command => "config channel",
        syntax => "config channel <#channel> <plugin>.<variable> <value>",
        example => "config channel #bot supybot.plugins.Channel.enabled True",
        description => "Configure channel-specific settings",
        permission => "admin"
    ),
    "load" => BotCommand->new(
        bot => "limnoria",
        command => "load",
        syntax => "load <plugin>",
        example => "load User",
        description => "Load a plugin",
        permission => "owner"
    ),
    "aka add" => BotCommand->new(
        bot => "limnoria",
        command => "aka add",
        syntax => "aka add <name> <command>",
        example => "aka add hi say Hello \$nick!",
        description => "Create command alias",
        permission => "admin"
    ),
);

my %EGGDROP_COMMANDS = (
    "bind" => BotCommand->new(
        bot => "eggdrop",
        command => "bind",
        syntax => "bind <type> <flags> <keyword> <proc>",
        example => "bind pub - !hello pub_hello",
        description => "Bind a command to a Tcl procedure",
        permission => "n/a (script)"
    ),
    "putserv" => BotCommand->new(
        bot => "eggdrop",
        command => "putserv",
        syntax => "putserv <text>",
        example => "putserv PRIVMSG #channel :Hello World",
        description => "Send raw IRC command",
        permission => "n/a (script)"
    ),
    "setudef" => BotCommand->new(
        bot => "eggdrop",
        command => "setudef",
        syntax => "setudef <type> <name>",
        example => "setudef str bot_setting",
        description => "Define user-defined variable",
        permission => "n/a (script)"
    ),
);

my %ALL_COMMANDS = (
    "pbot" => \%PBOT_COMMANDS,
    "limnoria" => \%LIMNORIA_COMMANDS,
    "eggdrop" => \%EGGDROP_COMMANDS,
);

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub get_command {
    my ($self, $bot, $command) = @_;
    $bot = lc($bot);
    $command = lc($command);
    
    my $bot_commands = $ALL_COMMANDS{$bot} // {};
    return $bot_commands->{$command};
}

sub list_commands {
    my ($self, $bot) = @_;
    if (defined $bot) {
        my $commands = $ALL_COMMANDS{lc($bot)} // {};
        return {$bot => [sort keys %$commands]};
    } else {
        my %result;
        for my $b (keys %ALL_COMMANDS) {
            $result{$b} = [sort keys %{$ALL_COMMANDS{$b}}];
        }
        return \%result;
    }
}

sub generate_script_template {
    my ($self, $bot, $purpose) = @_;
    $bot = lc($bot);
    
    if ($bot eq "pbot") {
        my $template_purpose = $purpose;
        $template_purpose =~ s/\s+/_/g;
        return "# pbot applet - $purpose\n# Place in ~/.pbot/applets/\n\nuse strict;\nuse warnings;\n\nsub ${template_purpose} {\n    my (\$self, \$from, \$to, \$args) = \@_;\n    \n    # Your code here\n    return \"Result: \$args\";\n}\n\n1;\n";
    } elsif ($bot eq "limnoria") {
        my $template_purpose = $purpose;
        $template_purpose =~ s/\s+//g;
        my $template_purpose_title = ucfirst($template_purpose);
        my $template_purpose_underline = $purpose;
        $template_purpose_underline =~ s/\s+/_/g;
        return "# Limnoria plugin - $purpose\n# Place in plugins/${template_purpose}/\n\nfrom supybot import utils, plugins, ircutils, callbacks\nfrom supybot.commands import *\n\nclass ${template_purpose_title}(callbacks.Plugin):\n    \"\"\"${purpose}\"\"\"\n    \n    threaded = True\n    \n    def ${template_purpose_underline}(self, irc, msg, args):\n        \"\"\"<args>\"\"\"\n        irc.reply(\"Hello from ${purpose}!\")\n    \nClass = ${template_purpose_title}\n";
    } elsif ($bot eq "eggdrop") {
        my $template_purpose = $purpose;
        $template_purpose =~ s/\s+/_/g;
        return "# Eggdrop Tcl script - $purpose\n# Add to eggdrop.conf: source scripts/${template_purpose}.tcl\n\nproc ${template_purpose} {nick uhost hand chan arg} {\n    putserv \"PRIVMSG \$chan :Hello \$nick, this is ${purpose}!\"\n}\n\nbind pub - !${template_purpose} ${template_purpose}\n";
    } else {
        return "# Unknown bot";
    }
}

sub main {
    use Getopt::Long;
    my %args;
    GetOptions(\%args,
        "bot=s",
        "command=s",
        "list",
        "template=s"
    ) or die "Error in command line arguments\n";
    
    unless ($args{bot}) {
        die "Missing required argument --bot\n";
    }
    
    my $syntax = IRCBotSyntax->new();
    
    if ($args{list}) {
        my $commands = $syntax->list_commands($args{bot});
        print to_json($commands, {pretty => 1});
    } elsif ($args{command}) {
        my $cmd = $syntax->get_command($args{bot}, $args{command});
        if ($cmd) {
            print "Bot: " . $cmd->bot . "\n";
            print "Command: " . $cmd->command . "\n";
            print "Syntax: " . $cmd->syntax . "\n";
            print "Example: " . $cmd->example . "\n";
            print "Description: " . $cmd->description . "\n";
            if (defined $cmd->permission) {
                print "Permission: " . $cmd->permission . "\n";
            }
        } else {
            print "Command not found: $args{command}\n";
            print "Available commands:\n";
            my $cmds = $syntax->list_commands($args{bot});
            print to_json($cmds, {pretty => 1});
        }
    } elsif ($args{template}) {
        my $template = $syntax->generate_script_template($args{bot}, $args{template});
        print $template;
    }
}

unless (caller) {
    main();
}

1;
