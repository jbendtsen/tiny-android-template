#!/bin/perl

use strict;
use warnings;

my $CMD_D8;
my $KOTLIN_LIB_DIR;
my $PLATFORM_DIR;

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

mkdir("build");

system("$CMD_D8 --intermediate \"$KOTLIN_LIB_DIR/kotlin-stdlib.jar\" --classpath $PLATFORM_DIR/android.jar --output build") or die;

rename("build/classes.dex", "build/kotlin.dex");
