#!/bin/perl

# Naive package downloader for the Jetpack/AndroidX suite
# Check out https://developer.android.com/jetpack/androidx/versions for a list of packages and versions

use strict;
use warnings;

use File::Fetch;
use File::Path;

$File::Fetch::WARN = 0;

my $REPO;
my $PKG_OUTPUT;

# This seems to be the only way to include perl files without creating modules and messing with environment variables.
# 'do' and 'require' silently and mysteriously don't work.
# The problem seems to be ideological, which makes this workaround all the more ironic, but that's Perl for you.
{
	open(my $FILE, '<', "includes.pl");

	foreach my $line (<$FILE>) {
		if (length($line) < 2 or substr($line, 0, 1) eq '#') {
			next;
		}
		my $decl = $line =~ s/\r//r;
		$decl =~ s/\n//;
		eval($decl . "\n");
	}

	close($FILE);
}

sub download_package {
	my $path = shift;
	my $fname = shift;
	my $url = "$REPO/$path/$fname";
	my $ff = File::Fetch->new(uri => $url);
	my $where = $ff->fetch(to => $PKG_OUTPUT);
	return $where;
}

sub get {
	my $path = shift;
	my $file = shift;
	print "$file: ";
	if (download_package($path, "$file.aar")) {
		print "OK\n";
	}
	else {
		if (download_package($path, "$file.jar")) {
			print "OK\n";
		} else {
			print "ERROR\n";
		}
	}
}

sub get_naive {
	my $first  = shift;
	my $second = shift;
	my $path = "androidx/$first/$first/$second";
	my $name = "$first-$second";
	get($path, $name);
}

sub parse_then_get {
	my $source = shift;
	if (index($source, "//") != -1) {
		my @parts = split(/\//, $source);
		my $fname = $parts[$#parts];

		print "$fname: ";
		my $ff = File::Fetch->new(uri => $source);
		my $where = $ff->fetch(to => $PKG_OUTPUT);
		if (not $where) {
			print "ERROR\n";
		}
		else {
			print "OK\n";
		}
	} elsif (index($source, ":") != -1) {
		my @parts = split(/:/, $source);
		my $prefix = $parts[0] =~ s/\./\//gr; # substr($parts[0], index($parts[0], ".") + 1);
		my $path = "$prefix/${parts[1]}/${parts[2]}";
		my $name = "${parts[1]}-${parts[2]}";
		get($path, $name);
	} else {
		my @parts = split(/ /, $source);
		get_naive($parts[0], $parts[1]);
	}
}

if (not defined $ARGV[0]) {
	print "AndroidX Package Downloader\n";
	print "usage:   $0 <package> <version>\n";
	print "         $0 <text file with lines of <packet> <version>>\n";
	print "         $0 <gradle \"implementation\" format>\n";
	print "example: $0 core 1.2.0\n";
	print "         $0 list.txt\n";
	print "         $0 androidx.core:core:1.2.0\n";
	exit;
}

File::Path::make_path($PKG_OUTPUT);

# If there is more than one parameter, then this script was run with <package> <version>.
# In that case, call get_naive() directly and exit.
if (defined $ARGV[1]) {
	get_naive($ARGV[0], $ARGV[1]);
	exit;
}

my $source = $ARGV[0];

# If the parameter contains a colon, then it is either a URL or a gradle-style implementation string.
# Else the parameter must be a local file containing the list of packages to download.
if (index($source, ":") != -1) {
	parse_then_get($source);
} else {
	open(my $FILE, '<', $source);
	foreach my $line (<$FILE>) {
		my $src = $line =~ s/\r//r;
		$src =~ s/\n//;
		parse_then_get($src);
	}
	close($FILE);
}
