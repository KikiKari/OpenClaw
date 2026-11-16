#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "c8e8e57097ee72241119821d2409f80bdf5adc354fb00ea6911488b6147e70b3", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "perl5"}
# bundled-plugin-root-runtime-mirrors.mjs — portiert nach perl5
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use JSON::PP;
use File::Find;
use File::Spec;
use Cwd 'abs_path';

my $JS_EXTENSIONS = { map { $_ => 1 } qw(.cjs .js .mjs) };

sub collectRuntimeDependencySpecs {
    my ($packageJson) = @_;
    $packageJson //= {};

    my @entries = ();
    if (exists $packageJson->{dependencies}) {
        push @entries, %{$packageJson->{dependencies}};
    }
    if (exists $packageJson->{optionalDependencies}) {
        push @entries, %{$packageJson->{optionalDependencies}};
    }

    my %result = ();
    for (my $i = 0; $i < @entries; $i += 2) {
        my $key = $entries[$i];
        my $value = $entries[$i+1];
        if (defined $value && ref($value) eq '' && length($value) > 0) {
            $result{$key} = $value;
        }
    }

    return \%result;
}

sub packageNameFromSpecifier {
    my ($specifier) = @_;

    if (!defined $specifier || ref($specifier) ne '' ||
        $specifier =~ m{^\.} || $specifier =~ m{^/} ||
        $specifier =~ m{^node:} || $specifier =~ m{^#}) {
        return undef;
    }

    my @parts = split('/', $specifier);
    my $first = $parts[0];
    return undef unless defined $first;

    if ($first =~ /^@/ && defined $parts[1]) {
        return "$first/$parts[1]";
    }
    return $first;
}

sub readJson {
    my ($filePath) = @_;
    open my $fh, '<:encoding(UTF-8)', $filePath or die "Cannot open $filePath: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    my $json = JSON::PP->new->utf8;
    return $json->decode($content);
}

sub collectPackageJsonPaths {
    my ($rootDir) = @_;
    return [] unless -d $rootDir;

    opendir(my $dh, $rootDir) or die "Cannot opendir $rootDir: $!";
    my @dirs = grep { -d "$rootDir/$_" && $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir $dh;

    my @paths = map { "$rootDir/$_/package.json" } sort @dirs;
    return [grep { -f $_ } @paths];
}

sub collectBundledPluginRuntimeDependencySpecs {
    my ($bundledPluginsDir) = @_;
    my %specs = ();

    my $packageJsonPaths = collectPackageJsonPaths($bundledPluginsDir);
    for my $packageJsonPath (@$packageJsonPaths) {
        my $packageJson = readJson($packageJsonPath);
        my @path_parts = File::Spec->splitdir(File::Spec->rel2abs(File::Spec->catfile($packageJsonPath)));
        my $pluginId = $path_parts[-2]; # Get parent directory name
        my $deps = collectRuntimeDependencySpecs($packageJson);
        for my $name (keys %$deps) {
            my $spec = $deps->{$name};
            if (exists $specs{$name}) {
                my $existing = $specs{$name};
                if ($existing->{spec} ne $spec) {
                    push @{$existing->{conflicts}}, { pluginId => $pluginId, spec => $spec };
                } elsif (!grep { $_ eq $pluginId } @{$existing->{pluginIds}}) {
                    push @{$existing->{pluginIds}}, $pluginId;
                }
                next;
            }
            $specs{$name} = { conflicts => [], pluginIds => [$pluginId], spec => $spec };
        }
    }

    return \%specs;
}

sub walkJavaScriptFiles {
    my ($rootDir) = @_;
    my @files = ();
    return \@files unless -d $rootDir;

    find(sub {
        return if $_ eq 'extensions';
        return unless -f $_;
        my $ext = ($_ =~ /(\.[^.]+)$/)[0] // '';
        if (exists $JS_EXTENSIONS->{$ext}) {
            push @files, $File::Find::name;
        }
    }, $rootDir);

    @files = sort @files;
    return \@files;
}

sub extractModuleSpecifiers {
    my ($source) = @_;
    my %specifiers = ();

    my @patterns = (
        qr/\bfrom\s*["']([^"']+)["']/,
        qr/\bimport\s*["']([^"']+)["']/,
        qr/\bimport\s*\(\s*["']([^"']+)["']\s*\)/,
        qr/\brequire\s*\(\s*["']([^"']+)["']\s*\)/
    );

    for my $pattern (@patterns) {
        while ($source =~ /$pattern/g) {
            $specifiers{$1} = 1 if defined $1;
        }
    }

    return [keys %specifiers];
}

sub collectRootDistBundledRuntimeMirrors {
    my ($params) = @_;
    my $distDir = $params->{distDir};
    my $bundledSpecs = $params->{bundledRuntimeDependencySpecs};
    my %mirrors = ();

    my $files = walkJavaScriptFiles($distDir);
    for my $filePath (@$files) {
        open my $fh, '<:encoding(UTF-8)', $filePath or die "Cannot open $filePath: $!";
        local $/;
        my $source = <$fh>;
        close $fh;

        my $relativePath = File::Spec->abs2rel($filePath, $distDir);
        $relativePath =~ s!\\!/!g; # Normalize path separators

        my $specifiers = extractModuleSpecifiers($source);
        for my $specifier (@$specifiers) {
            my $dependencyName = packageNameFromSpecifier($specifier);
            next unless defined $dependencyName;
            next unless exists $bundledSpecs->{$dependencyName};

            my $bundledSpec = $bundledSpecs->{$dependencyName};
            if (exists $mirrors{$dependencyName}) {
                push @{$mirrors{$dependencyName}->{importers}}, $relativePath;
                next;
            }
            $mirrors{$dependencyName} = {
                importers => [$relativePath],
                pluginIds => $bundledSpec->{pluginIds},
                spec => $bundledSpec->{spec}
            };
        }
    }

    return \%mirrors;
}

sub collectBundledPluginRootRuntimeMirrorErrors {
    my ($params) = @_;
    my $rootRuntimeDeps = collectRuntimeDependencySpecs($params->{rootPackageJson});
    my @errors = ();

    # Check for conflicts in bundled dependencies
    for my $dependencyName (keys %{$params->{bundledRuntimeDependencySpecs}}) {
        my $record = $params->{bundledRuntimeDependencySpecs}->{$dependencyName};
        for my $conflict (@{$record->{conflicts}}) {
            push @errors, "bundled runtime dependency '$dependencyName' has conflicting plugin specs: " . join(", ", @{$record->{pluginIds}}) . " use '$record->{spec}', $conflict->{pluginId} uses '$conflict->{spec}'.";
        }
    }

    # Check required root mirrors
    for my $dependencyName (keys %{$params->{requiredRootMirrors}}) {
        my $mirror = $params->{requiredRootMirrors}->{$dependencyName};
        my $rootSpec = $rootRuntimeDeps->{$dependencyName} // '';
        my @importers = sort @{$mirror->{importers}};
        my $importerLabel = join(", ", @importers);
        my @pluginIds = sort @{$mirror->{pluginIds}};
        my $pluginLabel = join(", ", @pluginIds);

        if (!defined $rootSpec || ref($rootSpec) ne '' || length($rootSpec) == 0) {
            push @errors, "root dist imports bundled plugin runtime dependency '$dependencyName' from $importerLabel; mirror '$dependencyName: $mirror->{spec}' in root package.json (declared by $pluginLabel).";
            next;
        }
        if ($rootSpec ne $mirror->{spec}) {
            push @errors, "root dist imports bundled plugin runtime dependency '$dependencyName' from $importerLabel; root package.json has '$rootSpec' but plugin manifest declares '$mirror->{spec}' ($pluginLabel).";
        }
    }

    return \@errors;
}

1;
