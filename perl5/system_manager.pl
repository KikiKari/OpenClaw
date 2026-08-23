#!/usr/bin/perl
# system_manager.py — portiert nach perl5
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

system_manager.pl - System management abstraction for Ubuntu and CentOS 8

=head1 SYNOPSIS

system_manager.pl [options]

 Options:
   --os          OS type (ubuntu or centos)
   --action      Action to perform
   --package     Package name
   --service     Service name
   --port        Port number
   --proto       Protocol (tcp/udp) [default: tcp]
   --username    Username
   --generate    Generate script instead of execute
   --help        Show this help message

=cut

# Define SystemCommand structure
package SystemCommand {
    sub new {
        my ($class, $ubuntu, $centos, $description) = @_;
        return bless {
            ubuntu => $ubuntu,
            centos => $centos,
            description => $description,
        }, $class;
    }
}

# SystemManager class
package SystemManager {
    # Command matrix
    my %COMMANDS = (
        "install" => SystemCommand->new(
            "apt-get install -y {package}",
            "dnf install -y {package}",
            "Install a package"
        ),
        "remove" => SystemCommand->new(
            "apt-get remove -y {package}",
            "dnf remove -y {package}",
            "Remove a package"
        ),
        "update" => SystemCommand->new(
            "apt-get update && apt-get upgrade -y",
            "dnf update -y",
            "Update all packages"
        ),
        "search" => SystemCommand->new(
            "apt-cache search {package}",
            "dnf search {package}",
            "Search for package"
        ),
        "service_start" => SystemCommand->new(
            "systemctl start {service}",
            "systemctl start {service}",
            "Start a service"
        ),
        "service_stop" => SystemCommand->new(
            "systemctl stop {service}",
            "systemctl stop {service}",
            "Stop a service"
        ),
        "service_enable" => SystemCommand->new(
            "systemctl enable {service}",
            "systemctl enable {service}",
            "Enable service at boot"
        ),
        "service_status" => SystemCommand->new(
            "systemctl status {service}",
            "systemctl status {service}",
            "Check service status"
        ),
        "firewall_allow" => SystemCommand->new(
            "ufw allow {port}/{proto}",
            "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload",
            "Open firewall port"
        ),
        "firewall_status" => SystemCommand->new(
            "ufw status",
            "firewall-cmd --list-all",
            "Check firewall status"
        ),
        "add_user" => SystemCommand->new(
            "adduser --disabled-password --gecos '' {username}",
            "adduser {username}",
            "Add system user"
        ),
        "add_to_sudo" => SystemCommand->new(
            "usermod -aG sudo {username}",
            "usermod -aG wheel {username}",
            "Add user to sudoers"
        ),
    );
    
    # Package name mappings
    my %PACKAGE_MAP = (
        "apache" => { "ubuntu" => "apache2", "centos" => "httpd" },
        "mysql" => { "ubuntu" => "mysql-server", "centos" => "mysql-server" },
        "php" => { "ubuntu" => "php", "centos" => "php" },
        "nodejs" => { "ubuntu" => "nodejs", "centos" => "nodejs" },
        "nginx" => { "ubuntu" => "nginx", "centos" => "nginx" },
    );
    
    sub new {
        my ($class, $os_type) = @_;
        my $self = {
            os => lc($os_type),
        };
        if ($self->{os} ne "ubuntu" && $self->{os} ne "centos") {
            die "Unsupported OS: $os_type\n";
        }
        return bless $self, $class;
    }
    
    sub get_command {
        my ($self, $action, %kwargs) = @_;
        my $cmd_template = $COMMANDS{$action};
        if (!$cmd_template) {
            die "Unknown action: $action\n";
        }
        
        # Get OS-specific command
        my $cmd;
        if ($self->{os} eq "ubuntu") {
            $cmd = $cmd_template->{ubuntu};
        } else {
            $cmd = $cmd_template->{centos};
        }
        
        # Format with arguments
        for my $key (keys %kwargs) {
            my $value = $kwargs{$key};
            $cmd =~ s/\{$key\}/$value/g;
        }
        return $cmd;
    }
    
    sub get_package_name {
        my ($self, $software) = @_;
        my $mapping = $PACKAGE_MAP{lc($software)} || {};
        return $mapping->{$self->{os}} || $software;
    }
    
    sub detect_os {
        my ($self) = @_;
        if (-r "/etc/os-release") {
            open(my $fh, '<', '/etc/os-release') or return undef;
            my $content = do { local $/; <$fh> };
            close($fh);
            $content = lc($content);
            if ($content =~ /ubuntu|debian/) {
                return "ubuntu";
            } elsif ($content =~ /centos|rhel|fedora/) {
                return "centos";
            }
        }
        return undef;
    }
    
    sub generate_script {
        my ($self, $actions) = @_;
        my @lines = ("#!/bin/bash", "set -e", "");
        
        for my $action (@$actions) {
            my $cmd_name = delete $action->{action};
            push @lines, "# " . $COMMANDS{$cmd_name}->{description};
            push @lines, $self->get_command($cmd_name, %$action);
            push @lines, "";
        }
        
        return join("\n", @lines);
    }
}

# Main execution
sub main {
    my %args = (
        proto => "tcp",
    );
    
    GetOptions(
        "os=s" => \$args{os},
        "action=s" => \$args{action},
        "package=s" => \$args{package},
        "service=s" => \$args{service},
        "port=s" => \$args{port},
        "proto=s" => \$args{proto},
        "username=s" => \$args{username},
        "generate" => \$args{generate},
        "help|h" => sub { pod2usage(1); },
    ) or pod2usage(2);
    
    if (!$args{os} || !$args{action}) {
        pod2usage(2);
    }
    
    my $manager = SystemManager->new($args{os});
    
    # Build kwargs from args
    my %kwargs = ();
    if ($args{package}) {
        $kwargs{package} = $manager->get_package_name($args{package});
    }
    if ($args{service}) {
        $kwargs{service} = $args{service};
    }
    if ($args{port}) {
        $kwargs{port} = $args{port};
        $kwargs{proto} = $args{proto};
    }
    if ($args{username}) {
        $kwargs{username} = $args{username};
    }
    
    my $cmd = $manager->get_command($args{action}, %kwargs);
    
    if ($args{generate}) {
        print "$cmd\n";
    } else {
        print "Executing: $cmd\n";
        # system($cmd);  # Uncomment to actually execute
    }
}

main() unless caller;
