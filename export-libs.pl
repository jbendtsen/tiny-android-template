#!/bin/perl

use strict;
use warnings;

my @DELETE_LIST = (
	qr/app:layout_behavior="[^"^`]*"/
);

my $ANDROID_VERSION;
my $LIB_RES_DIR;
my $LIB_CLASS_DIR;
my $CMD_DELETE;
my $CMD_COPY;
my $CMD_7Z;

# get variables from includes.sh
{
	open(my $FILE, '<', "includes.sh");

	foreach my $line (<$FILE>) {
		if (length($line) < 2 or substr($line, 0, 1) eq '#') {
			next;
		}
		my $decl = substr($line, 0, -1);
		$decl =~ s/="/ = "/;
		$decl =~ s/='/ = '/;
		$decl = "\$" . $decl . ";\n";
		eval($decl);
	}

	close($FILE);
}

# I make the assumption that all tags that don't directly belong to the <resources> tag can be ignored when looking for merge conflicts.
# This is a helper function that keeps track of how many tag levels deep the interpreter is.
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

# The purpose of this function is self-explanatory, but I'm not sure if this is a particularly good way of going about it.
# The reason I converted this into a hash tree instead of a single hash was to potentially reduce lookup times,
#  but it seems to only be about 15% faster...
sub value_exists {
	my $root = shift;
	my $dir  = shift;
	my $type = shift;
	my $name = shift;

	if (exists($root->{$dir})) {
		my $dir_hash = $root->{$dir};
		if (exists($dir_hash->{$type})) {
			my $type_hash = $dir_hash->{$type};
			if (exists($type_hash->{$name})) {
				return 1;
			}
			else {
				$type_hash->{$name} = 1;
				# $values_hash{$name} = "$pkg_name:$line_no$value";
			}
		}
		else {
			$dir_hash->{$type} = {};
		}
	}
	else {
		$root->{$dir} = {};
	}

	return 0;
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
	exit if (system("$CMD_DELETE $LIB_RES_DIR") != 0);
	mkdir("$LIB_RES_DIR");
}

if (-d "$LIB_CLASS_DIR") {
	print("Clearing old library classes...\n");
	exit if (system("$CMD_DELETE $LIB_CLASS_DIR") != 0);
	mkdir("$LIB_CLASS_DIR");
}

print("Extracting library resources and classes...\n");

# A JAR is basically just a ZIP file packed with classes in a certain folder structure, so we just extract everything.
foreach (<lib/*.jar>) {
	system("$CMD_7Z x -y '$_' -o$LIB_CLASS_DIR > /dev/null");
}

# AAR is the Android library format. It's essentially a ZIP containing a JAR and some resources.
foreach (<lib/*.aar>) {
	system("$CMD_7Z x -y '$_' -o$LIB_RES_DIR res classes.jar R.txt AndroidManifest.xml > /dev/null");

	system("$CMD_7Z x -y '$LIB_RES_DIR/classes.jar' -o$LIB_CLASS_DIR > /dev/null");
	unlink("$LIB_RES_DIR/classes.jar");

	my $name = substr($_, 4, -4);

	rename("$LIB_RES_DIR/R.txt", "$LIB_RES_DIR/${name}_R.txt") if (-f "$LIB_RES_DIR/R.txt");
	rename("$LIB_RES_DIR/AndroidManifest.xml", "$LIB_RES_DIR/${name}_mf.xml") if (-f "$LIB_RES_DIR/AndroidManifest.xml");
	rename("$LIB_RES_DIR/res", "$LIB_RES_DIR/res_$name") if (-d "$LIB_RES_DIR/res");
}

print("Merging library resources...\n");

# This is the interesting part.
# In order for the libraries to be loaded and work during run-time, all resources have to co-exist in the same space.
# AAPT2 handles ID allocation to consistently map a single number to a single resource each, but in order for it to work,
#  there must not be any resources across all packages/libraries (including your project) that share the same name.
# The purpose of this part of the script is to remove resources with conflicting names, for better or worse.

mkdir("$LIB_RES_DIR/res");

my %xml_hash;
my %values_hash;

my $n_delete_items = scalar @DELETE_LIST;

# For each package (=library)
foreach my $pkg (<$LIB_RES_DIR/res_*>) {
	# 12 == length of "$LIB_RES_DIR/res_"
	my $pkg_name = substr($pkg, 12);

	# The resources' sub-folders represent resource "types". The ones we'll focus on here are the "values*" types.
	foreach my $type_dir (<$pkg/*>) {
		# Get the name of the current folder
		my $dir = substr($type_dir, length($pkg) + 1);
		# Mirror this folder name in the output
		my $out_dir = "$LIB_RES_DIR/res/$dir";

		# Non-"values" directories
		if ($type_dir !~ /\/values/) {
			if ($n_delete_items > 0) {
				mkdir $out_dir if (!-d $out_dir);

				foreach my $fname (<$type_dir/*>) {
					open(my $fh, '<', $fname);
					read($fh, my $content, -s $fh);
					close($fh);

					foreach my $r (@DELETE_LIST) {
						$content =~ s/$r//g;
					}

					my $xml_name = substr($fname, length($type_dir) + 1);
					my $out_xml = "$out_dir/$xml_name";

					open($fh, '>', $out_xml);
					print $fh $content;
					close($fh);
				}
			}
			else {
				system("$CMD_COPY -r '$type_dir' $LIB_RES_DIR/res");
			}
			next;
		}

		mkdir $out_dir if (!-d $out_dir);

		# For each xml
		foreach my $v_xml (<$type_dir/*>) {
			open(my $fh, '<', $v_xml);
			chomp(my @xml = <$fh>);
			close($fh);

			my $xml_name = substr($v_xml, length($type_dir) + 1);
			my $out_xml = "$out_dir/$xml_name";

			# Treat the name of this file has being a key in a hash.
			# When the same file is encountered in a different library package,
			#  it will be checked for any duplicates before being appended to the existing text for that file.

			if (!exists($xml_hash{$out_xml})) {
				$xml_hash{$out_xml} = [];
			}

			my $line_no = 0;
			my $level = 0;

			# For each line in the new XML
			foreach (@xml) {
				$line_no += 1;

				my $line = $_;
				$line =~ s/^\s+|\s+$//g;

				# Skip this line if it's a comment
				my $pref = substr($line, 0, 2);
				next if ($pref eq "<!");

				# Delete all meta-tags and the resource tags, so that multiple XMLs can be stitched together and still be parsed all the way through
				# Note that we delete the contents of the line rather than the line itself, since we're iterating forwards over the same array
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

				# If this tag has a 'name' attribute and we're only one level down from the root
				if ($level == 1 and $line =~ /<(\w+) .*name="([^"]+)/) {
					# Check this name for this resource type under this type sub-folder
					if (value_exists(\%values_hash, $dir, $1, $2)) {
						print("Eliminating re-def in $pkg_name at line $line_no for $dir/$1/$2\n");
						$xml[$line_no - 1] = "";
					}
				}

				$level += level_delta($line);
			}

			# Now that the headers and conflicting lines have been deleted, we append all the lines left to its kind of XML
			push(@{$xml_hash{$out_xml}}, @xml);
		}
	}
}

print("Writing values XMLs...\n");

foreach (keys %xml_hash) {
	# We make sure to add a single set of headers/footer at the end.
	# Note that unshift() makes the new element come first on the list.
	unshift(@{$xml_hash{$_}}, '<resources xmlns:ns1="urn:oasis:names:tc:xliff:document:1.2" xmlns:ns2="http://schemas.android.com/tools">');
	unshift(@{$xml_hash{$_}}, '<?xml version="1.0" encoding="utf-8"?>');
	push(@{$xml_hash{$_}}, '</resources>');

	my $content = join("\n", @{$xml_hash{$_}});
	foreach my $r (@DELETE_LIST) {
		$content =~ s/$r//g;
	}

	open(my $fh, '>', $_);
	print $fh $content;
	close($fh);
}
