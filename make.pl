#!/bin/perl

# This script makes the following assumptions:
#  1) You have a local copy of the Android SDK
#  2) You have an installed copy of the Java Development Kit (JDK)
#  3) If you are using AAR libraries (such as the AndroidX suite), you have copied/downloaded them to the lib directory and have run export-libs.pl then link.pl
#  4) You have already created a KeyStore file using keytool (comes with the JRE/JDK)

use strict;
use warnings;
use File::Spec;
use File::Find;
use File::Path qw(rmtree);
use File::Copy qw(copy);

my $SDK_DIR;
my $ANDROID_VERSION;
my $MIN_SDK_VERSION;
my $PLATFORM_DIR;
my $TOOLS_DIR;
my $JAR_TOOLS;
my $CMD_JAVA;
my $CMD_JAVAC;
my $CMD_KOTLINC;
my $CMD_D8;
my $CMD_7Z;
my $KEYSTORE;
my $KS_PASS;

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

my $DEV_NULL = File::Spec->devnull;

my $SEP = ":";
if ($^O eq "MSWin32" or $^O eq "cygwin") {
	$SEP = ";";
}

if (not -d "build") {
	mkdir("build");
}

print "Cleaning build...\n";

# Deletes all folders and APK files inside the build folder

opendir my $dir, "build";
my @build_entries = readdir $dir;
closedir $dir;

foreach my $entry (@build_entries) {
	if ($entry eq "." or $entry eq "..") {
		next;
	}

	my $path = "build/" . $entry;
	if (substr($path, length($path) - 4) eq ".apk" or -d $path) {
		rmtree($path);
	}
}

my $package = "";
open(my $file, '<', "AndroidManifest.xml");
foreach my $line (<$file>) {
	if ($line =~ /package=[\'\"]([a-z0-9._]+)/) {
		$package = $1;
		last;
	}
}
close($file);

my $package_path = $package =~ s/\./\//gr;

if (not $package) {
	print "Could not find a suitable package name inside AndroidManifest.xml\n";
	exit;
}

print "Compiling project source...\n";

my $java_list = "";
my $kt_list = "";

sub find_cb {
	if (-f $_) {
		if (substr($_, length($_) - 5) eq ".java") {
			$java_list .= " ";
			$java_list .= $File::Find::name;
		}
		elsif (substr($_, length($_) - 3) eq ".kt") {
			$kt_list .= " ";
			$kt_list .= $File::Find::name;
		}
	}
}

my @find_dirs = ( "src" );
File::Find::find(\&find_cb, @find_dirs);

# If string length of java_list > 2 then we've got some Java source
# I picked '2' in case newlines bump it up from 0, though it's likely overkill
my $found_src = 0;
if ($java_list) {
	my $jars = "$PLATFORM_DIR/android.jar${SEP}";
	if (-f "build/R.jar") {
		$jars .= "build/R.jar${SEP}";
	}
	if (-f "build/libs.jar") {
		$jars .= "build/libs.jar${SEP}";
	}

	system("$CMD_JAVAC --release 8 -classpath $jars -d build $java_list") and exit;
} elsif ($kt_list) {
	system("$CMD_KOTLINC -d build -cp \"$PLATFORM_DIR/android.jar${SEP}build/R.jar${SEP}build/libs.jar\" -jvm-target 1.8 $kt_list") and exit;
} else {
	print "No project sources were found in the 'src' folder.\n";
	exit;
}

print "Compiling classes into DEX bytecode...\n";

my $dex_list = "";
if (-f "build/libs.dex") {
	$dex_list .= " build/libs.dex";
}
if (-f "build/libs_r.dex") {
	$dex_list .= " build/libs_r.dex";
}
if (-f "build/kotlin.dex") {
	$dex_list .= " build/kotlin.dex";
}

my $class_list = "";
if (-d "build/$package_path") {
	$class_list = "build/$package_path/*";
}

system("$CMD_D8 --classpath \"$PLATFORM_DIR/android.jar\" $dex_list $class_list --output build") and exit;

print "Creating APK...\n";

my $res = "";
if (-f "build/res.zip") {
	$res .= "build/res.zip";
}
if (-f "build/res_libs.zip") {
	$res .= " build/res_libs.zip";
}
system("$TOOLS_DIR/aapt2 link -o build/unaligned.apk --manifest AndroidManifest.xml -I $PLATFORM_DIR/android.jar --emit-ids ids.txt $res") and exit;

# Pack the DEX file into a new APK file
chdir "build";
system("$CMD_7Z a -tzip unaligned.apk classes.dex > $DEV_NULL");
chdir "..";

my @native_folders = ("arm64-v8a", "armeabi-v7a", "x86", "x86_64");

foreach my $arch (@native_folders) {
	if (-d $arch) {
		system("$CMD_7Z a -tzip build/unaligned.apk $arch > $DEV_NULL");
		system("$CMD_7Z rn -tzip build/unaligned.apk $arch lib/$arch > $DEV_NULL");
	}
}

# Align the APK
# I've seen the next step and this one be in the other order, but the Android reference site says it should be this way...
system("$TOOLS_DIR/zipalign -f 4 build/unaligned.apk build/aligned.apk") and exit;

print "Signing APK...\n";

# Sign the APK
system("$JAR_TOOLS/apksigner.jar sign --ks $KEYSTORE --ks-pass \"pass:$KS_PASS\" --min-sdk-version $MIN_SDK_VERSION --out app.apk build/aligned.apk");
