#!/bin/perl

use strict;
use warnings;

my $ANDROID_VER = "android-29";
my $BUILD_VER   = "29.0.3";

my $SDK_DIR      = "../Sdk";
my $TOOLS_DIR    = "$SDK_DIR/build-tools/$BUILD_VER";
my $PLATFORM_DIR = "$SDK_DIR/platforms/$ANDROID_VER";

my $LIB_RES_DIR   = "lib/res";
my $LIB_CLASS_DIR = "lib/classes";

sub level_delta {
	my @chars = split('', shift);

	my $delta = 0;
	my $quotes = 0;
	my $tag = 0;
	my $prev = '';

	foreach (@chars) {
		if ($_ eq '"') {
			$quotes ^= 1;
		}
		if (!$quotes) {
			if ($_ eq '<') {
				$tag = 1;
				$delta += 1;
			}
			elsif ($_ eq '/' and $prev eq '<') {
				$delta -= 2;
			}
			elsif ($_ eq '>' and $prev eq '/') {
				$delta -= 1;
			}
		}
		$prev = $_;
	}

	return $delta;
}

if (!-d "lib") {
	print(
		"lib/ folder has not been created.\n",
		"Try running get-packages.sh to retrieve some library packages.\n"
	);
	exit;
}

if (-d "$LIB_RES_DIR") {
	print("Clearing old library resources...\n");
	exit if (system("rm -rf $LIB_RES_DIR") != 0);
	mkdir("$LIB_RES_DIR");
}

if (-d "$LIB_CLASS_DIR") {
	print("Clearing old library classes...\n");
	exit if (system("rm -rf $LIB_CLASS_DIR") != 0);
	mkdir("$LIB_CLASS_DIR");
}

print "Extracting library resources and classes...\n";

foreach (<lib/*.jar>) {
	system("7z x -y '$_' -o$LIB_CLASS_DIR > /dev/null");
}

foreach (<lib/*.aar>) {
	system("7z x -y '$_' -o$LIB_RES_DIR res classes.jar R.txt AndroidManifest.xml > /dev/null");

	system("7z x -y '$LIB_RES_DIR/classes.jar' -o$LIB_CLASS_DIR > /dev/null");
	unlink("$LIB_RES_DIR/classes.jar");

	my $name = substr($_, 4, -4);

	rename("$LIB_RES_DIR/R.txt", "$LIB_RES_DIR/${name}_R.txt") if (-f "$LIB_RES_DIR/R.txt");
	rename("$LIB_RES_DIR/AndroidManifest.xml", "$LIB_RES_DIR/${name}_mf.xml") if (-f "$LIB_RES_DIR/AndroidManifest.xml");
	rename("$LIB_RES_DIR/res", "$LIB_RES_DIR/res_$name") if (-d "$LIB_RES_DIR/res");
}

print "Merging library resources...\n";

mkdir("$LIB_RES_DIR/res");

my %xml_hash;
my %values_hash;

foreach my $pkg (<$LIB_RES_DIR/res_*>) {
	# 12 == length of "$LIB_RES_DIR/res_"
	my $pkg_name = substr($pkg, 12);

	foreach my $type_dir (<$pkg/*>) {
		# For non-"values" directories, just merge them into the new res folder
		if ($type_dir !~ /\/values/) {
			system("cp -r '$type_dir' $LIB_RES_DIR/res");
			next;
		}

		my $dir = substr($type_dir, length($pkg) + 1);
		my $out_dir = "$LIB_RES_DIR/res/$dir";
		mkdir $out_dir if (!-d $out_dir);

		foreach my $v_xml (<$type_dir/*>) {
			open(my $fh, '<', $v_xml);
			chomp(my @xml = <$fh>);
			close($fh);

			my $xml_name = substr($v_xml, length($type_dir) + 1);
			my $out_xml = "$out_dir/$xml_name";

			if (!exists($xml_hash{$out_xml})) {
				$xml_hash{$out_xml} = [];
			}

			my $line_no = 0;
			my $level = 0;

			my $seen_meta = 0;
			my $seen_resources_tag = 0;

			foreach (@xml) {
				$line_no += 1;

				my $line = $_;
				$line =~ s/^\s+|\s+$//g;

				# skip this line if it's a comment
				my $pref = substr($line, 0, 2);
				next if ($pref eq "<!");

				if ($pref eq "<?" or $line eq "</resources>") {
					$xml[$line_no - 1] = "";
					next;
				}
				if (substr($line, 0, 10) eq "<resources") {
					$xml[$line_no - 1] = "";
					$level++; # prime hackery daiquiri
					next;
				}

				my $new = 0;
				my $name = "";
				if ($level == 1 and $line =~ /<(\w+) .*name="([^"]+)/) {
					$name = "$2:$1:$dir";

					if (!exists($values_hash{$name})) {
						my $value = ($line =~ />([^<]+)</) ? " $1" : "";

						$values_hash{$name} = "$pkg_name:$line_no$value";
						$new = 1;
					}
				}

				if (!$new and $name) {
					print "Eliminating re-def in $pkg_name at line $line_no for $name = '${values_hash{$name}}'\n";
					$xml[$line_no - 1] = "";
				}

				$level += level_delta($line);
			}

			push(@{$xml_hash{$out_xml}}, @xml);
		}
	}
}

print "Writing values XMLs...\n";

foreach (keys %xml_hash) {
	unshift(@{$xml_hash{$_}}, '<resources xmlns:ns1="urn:oasis:names:tc:xliff:document:1.2">');
	unshift(@{$xml_hash{$_}}, '<?xml version="1.0" encoding="utf-8"?>');
	push(@{$xml_hash{$_}}, '</resources>');

	open(my $fh, '>', $_);
	print $fh join("\n", @{$xml_hash{$_}});
	close($fh);
}

print "Compiling library resources...\n";

mkdir("build") if (!-d "build");
system("$TOOLS_DIR/aapt2 compile -o build/res_libs.zip --dir lib/res/res");
