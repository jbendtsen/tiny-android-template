#!/bin/perl

use strict;
use warnings;

use File::Spec;

my $ANDROID_VERSION;
my $SDK_DIR;
my $TOOLS_DIR;
my $CMD_JAVA;
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

my $SEP = ":";
if ($^O eq "MSWin32" or $^O eq "cygwin") {
	$SEP = ";";
}

# Java compiler for Windows is dumb and doesn't allow you to enter more than one classpath that starts with a drive letter (e.g. C:\)
my $platform_dir_relative = File::Spec->abs2rel($PLATFORM_DIR);
my $kotlin_lib_dir_relative = File::Spec->abs2rel($KOTLIN_LIB_DIR);
print "$platform_dir_relative $kotlin_lib_dir_relative\n";

mkdir("build");

print "Compiling kotlin-stdlib...\n";
system("$CMD_D8 --intermediate \"$kotlin_lib_dir_relative/kotlin-stdlib.jar\" --classpath \"$platform_dir_relative/android.jar\" --output build") and exit;
rename("build/classes.dex", "build/kotlin-stdlib.dex");

print "Compiling kotlinx-coroutines-core-jvm...\n";
system("$CMD_D8 --intermediate \"$kotlin_lib_dir_relative/kotlinx-coroutines-core-jvm.jar\" --classpath $kotlin_lib_dir_relative/kotlin-stdlib.jar${SEP}$platform_dir_relative/android.jar --output build") and exit;
rename("build/classes.dex", "build/kotlinx-coroutines-core-jvm.dex");

