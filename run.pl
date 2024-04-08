#!/bin/perl

my $SDK_DIR;
my $CMD_ADB;

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

my $package = "";
my $activity = "";

open(my $file, '<', "AndroidManifest.xml");
foreach my $line (<$file>) {
	if ($line =~ /package=[\'\"]([a-z0-9._]+)/) {
		$package = $1;
	}
	if ($line =~ /<activity([^>]+)/) {
		my $tag = $1;
		if ($tag =~ /[\'\"]([^\'\"]+)/) {
			$activity = $1;
		}
	}
	if ($package and $activity) {
		last;
	}
}
close($file);

if (not $package or not $activity) {
	print "Could not find a suitable package name inside AndroidManifest.xml\n";
	exit;
}

if (not system("$CMD_ADB install -r -t app.apk")) {
	system("$CMD_ADB shell am start -n $package/$activity");
}