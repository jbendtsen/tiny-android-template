#!/bin/perl

use strict;
use warnings;

my $ANDROID_VERSION;

my $SDK_DIR;
my $TOOLS_DIR;
my $PLATFORM_DIR;

my $CMD_DELETE;
my $CMD_JAR;
my $CMD_JAVAC;
my $CMD_JAVA;
my $CMD_D8;

my $LIB_RES_DIR;
my $LIB_CLASS_DIR;

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

# Every library/package that uses resources needs a list that maps resource variables to IDs in code form.
# It starts with a simple text file that gets translated into a .java, which is in turn compiled into the package.
# All that's needed is a simple re-formatting for each line, with a few Java keywords and curly braces in-between.

sub gen_rjava {
	my $pkg = shift;
	my $r_txt = shift;

	my @out = (
		"// Auto-generated by an unofficial tool",
		"",
		"package $pkg;",
		"",
		"public final class R {"
	);

	my $class = "";

	foreach my $line (@$r_txt) {
		my @info = split(/ /, $line, 4);
		$info[1] =~ s/[^0-9a-zA-Z]/_/;

		my $colon = rindex($info[2], ':');
		if ($colon >= 0) {
			$info[2] = substr($info[2], $colon + 1);
		}

		if ($info[1] ne $class) {
			push(@out, "\t}") if (length($class) > 0);

			$class = $info[1];
			push(@out, "\tpublic static final class $class {");
		}

		push(@out, "\t\tpublic static final ${info[0]} ${info[2]}=${info[3]};");
	}

	push(@out, ("\t}", "}", ""));
	return \@out;
}

# The only reason this script cares about the AndroidManifest.xml file (found inside every APK and AAR)
#  is so that it can consistently find the name of the package, which is what this function does

sub get_package_from_manifest {
	my $path = shift;

	if (!-f $path) {
		print("Could not find manifest file $path");
		return undef;
	}

	open(my $fh, '<', $path);
	read($fh, my $manifest, -s $fh);
	close($fh);

	if ($manifest =~ /package=["']([^"']+)/g) {
		return $1;
	}
	else {
		print("Could not find a suitable package name inside AndroidManifest.xml\n");
	}

	return undef;
}

# This function creates an R.txt file based on the resources in the 'res' folder of the main project,
#  which is later turned into R.java and finally R.jar.
# Essentially, each values XML is scanned for strings or other values defined on a particular line,
#  and everything else is just scanned for its file name.
# The ID that each resource is given here is unimportant other than that it needs to be unique merely within this generated document.
# All resource IDs (including these ones) get overwritten later.

sub gen_proj_rtxt {
	# UPDATE 12/09/22: 'resources' and 'layout_id_defs' are now hashmaps, to allow for multiple versions of the same resource to be deduplicated.
	# All that matters is that one version is written to R.txt, since this is ultimately how resources are accessed from code.
	my %resources = ();
	my $type_idx = 0;

	# The meaning of "id" here is a type, not a number that is used to identify a resource
	# We create a separate hashmap and push it to the main r_txt at the end to work around the limitations of our gen_rjava() implementation.
	my %layout_id_defs = ();

	foreach my $dir (<res/*>) {
		my $sub_idx = 0;

		# If this type-folder is a values folder
		if ($dir =~ /values/) {
			foreach my $f (<$dir/*.xml>) {
				open(my $fh, '<', $f);
				foreach (<$fh>) {
					if ($_ =~ /<([^ ]+).+name="([^"]+)"/) {
						$resources{"$1 $2"} = sprintf('0x7f%02x%04x', $type_idx, $sub_idx);
						$sub_idx++;
					}
				}
				close($fh);
			}
		}
		else {
			# 4 == length("res/")
			my $type = substr($dir, 4);
			my $len = length($dir) + 1;

			foreach my $f (<$dir/*>) {
				# Some XML files (especially layout files) contain resource definitions under the type "id"
				if (substr($f, -4) eq ".xml") {
					open(my $fh, '<', $f);
					foreach (<$fh>) {
						if ($_ =~ /@\+id\/([^"]+)/) {
							$layout_id_defs{$1} = sprintf('0x7f%02x%04x', $type_idx, $sub_idx);
							$sub_idx++;
						}
					}
					close($fh);
				}

				my $dot_idx = index($f, ".", $len);
				my $name = ($dot_idx < 0) ? substr($f, $len) : substr($f, $len, $dot_idx - $len);

				$resources{"$type $name"} = sprintf('0x7f%02x%04x', $type_idx, $sub_idx);
				$sub_idx++;
			}
		}

		$type_idx++;
	}

	my @r_txt = ();
	
	my @resource_keys = sort(keys(%resources));
	foreach (@resource_keys) {
		push(@r_txt, "int " . $_ . " " . $resources{$_});
	}

	my @layout_keys = sort(keys(%layout_id_defs));
	foreach (@layout_keys) {
		push(@r_txt, "int id " . $_ . " " . $layout_id_defs{$_});
	}

	open(my $fh, '>', "build/R.txt");
	print $fh join("\n", @r_txt);
	close($fh);
}

# This is the big one. This is where all resource IDs get overwritten.
# When AAPT2 links all resources from all the libraries (and the main project) together, it reallocates all IDs so that they are unique.
# We take the new list of IDs and apply it to each package's resource listing, which AAPT2 doesn't do for us.
# After this, there should be no resource collisions at app runtime.

sub update_res_ids {
	my $ids = shift;
	my $r_list = shift;

	my @table = (); # list of offsets to the provided files inside 'blob'
	my $fmt = "";   # format string to pack the list of files into a single blob
	my @files = ();

	# Load each R.txt
	my $size = 0;
	foreach (@$r_list) {
		open(my $fh, '<:raw', $_);
		my $s = -s $fh;
		read($fh, my $r, $s);
		close($fh);

		push(@table, $size);
		$fmt .= "a$s ";
		push(@files, $r);
		$size += $s;
	}
	push(@table, $size);

	# Make a copy of each R.txt and embed it into one homogeneous string. This is likely faster than scanning each file individually.
	my $blob = pack($fmt, @files);

	# Make an index of replacements to happen later. This means there (shouldn't) be any search-replace ordering issues.
	my @repl_list = ();

	# For each line in the AAPT2 'ids.txt' output
	foreach (@$ids) {
		# Hard-coded 10 == length("0xnnnnnnnn"), the 32-bit hex number scheme that IDs use in text form
		my $new_id = substr($_, -10);

		my $nm_start = index($_, ':') + 1;
		my $nm_end = index($_, ' ') + 1;

		# 'name' will look like "type variable "
		my $name = substr($_, $nm_start, $nm_end - $nm_start);
		$name =~ s/\// /;

		# For each instance where 'name' gets defined as a single ID:
		my $name_reg = qr/$name(0x[0-9a-fA-F]+)/;
		while ($blob =~ /$name_reg/g) {
			my $match_len = length($1);
			my $off = (pos $blob) - $match_len;
			next if ($off < 0);

			# If the ID is not a complete ID (likely 0x0), just mark a single replacement
			if ($match_len != 10) {
				push(@repl_list, {"off" => $off, "len" => $match_len, "new" => $new_id});
				next;
			}

			# Find the current file
			my $file_idx = 0;
			$file_idx++ while ($table[$file_idx] < $off);
			$file_idx--;

			# Find all instances of the old ID for this new ID so we can replace them all
			my $id_reg = qr/$1/;
			while ($files[$file_idx] =~ /$id_reg/g) {
				my $pos = (pos $files[$file_idx]) - $match_len;
				next if ($pos < 0);

				push(@repl_list, {"off" => $pos + $table[$file_idx], "len" => 10, "new" => $new_id});
			}
		}
	}

	# Since @ids (from ids.txt by AAPT2 link) is not sorted in a convenient order, we sort the replacement list here
	#  so that for each offset, the necessary displacement can be calculated linearly
	my @replacements = sort { $a->{"off"} <=> $b->{"off"} } @repl_list;

	my $n_repl = @replacements;
	my $file_idx = 0;
	my $disp = 0;

	# This assumes that at least one replacement is needed in each file
	for (my $i = 0; $i < $n_repl; $i++) {
		my $repl = $replacements[$i];
		my $off = $repl->{"off"};
		my $len = $repl->{"len"};

		# We need to update the table of file offsets so that we can write the correct range of bytes to the intended file later
		while ($off > $table[$file_idx + 1]) {
			$file_idx++;
			$table[$file_idx] += $disp;
		}

		# Actually replace the old ID with the new one.
		# The key here is that the new ID may not necessarily be the same length as the old one,
		#  so everything after this replacement may get shifted up/down.
		# A displacement is calculated as we go so that the current offset is always up to date.

		substr($blob, $off + $disp, $len) = $repl->{"new"};
		$disp += 10 - $len; # disp += length($repl->{"new"}) - $len
	}

	# Make sure the last file has its size corrected as well
	$table[-1] += $disp;

	# Overwrite all the R.txts
	my $idx = 0;
	foreach (@$r_list) {
		open(my $fh, '>', $_);
		my $len = $table[$idx+1] - $table[$idx];
		print $fh substr($blob, $table[$idx], $len);
		close($fh);
		$idx++;
	}
}

# This function iterates over every AAR, finds its R.txt, generates R.java and compiles it,
#  placing the resulting .class files inside the already extracted classes folder for the current package.
# This means when the library is properly compiled into a JAR later, it knows how to access its own resources.

sub gen_libs_rjava {
	my $dir = "$LIB_RES_DIR/r_java";
	my @rjava_list = ();

	foreach (<lib/*.aar>) {
		my $name = substr($_, 4, -4);

		my $in_path = "$LIB_RES_DIR/${name}_R.txt";

		if (!-f $in_path) {
			print("No resources file for $name, skipping...\n");
			next;
		}

		open(my $fh, '<', $in_path);
		chomp(my @r_txt = <$fh>);
		close($fh);

		# skip this library if the resources index is empty
		if (@r_txt <= 0) {
			print("R.txt for $name is missing, skipping...\n");
			next;
		}

		my $package = get_package_from_manifest("$LIB_RES_DIR/${name}_mf.xml");
		if (!defined($package)) { # a bit harsh ;)
			print("Could not find package name inside ${name}/AndroidManifest.xml, skipping...\n");
			next;
		}

		my $out_path = "$dir/$name";
		mkdir($out_path) if (!-d $out_path);

		my $r_java = gen_rjava($package, \@r_txt);

		$out_path .= "/R.java";
		push(@rjava_list, $out_path);

		open($fh, '>', $out_path);
		print $fh join("\n", @$r_java);
		close($fh);
	}

	return \@rjava_list;
}

# Entry-point

if (-d "lib" && not (-d $LIB_RES_DIR && -d $LIB_CLASS_DIR)) {
	print(
		"This stage depends on library resources already being compiled.\n",
		"Run export-libs.pl first.\n"
	);
	exit;
}

mkdir("build") if (!-d "build");

my $aapt2_res = "build/res.zip";

if (-d "lib") {
	print("Compiling library resources...\n");

	system("$TOOLS_DIR/aapt2 compile -o \"build/res_libs.zip\" --dir \"lib/res/res\"");
	exit if ($? != 0);

	$aapt2_res = "build/res_libs.zip " . $aapt2_res;
}

print("Compiling project resources...\n");

system("$TOOLS_DIR/aapt2 compile -o \"build/res.zip\" --dir \"res\"");
exit if ($? != 0);

print("Linking resources...\n");

# This is what gives us the actual set of properly unique IDs
system("$TOOLS_DIR/aapt2 link -o \"build/unaligned.apk\" --manifest \"AndroidManifest.xml\" -I \"$PLATFORM_DIR/android.jar\" --emit-ids ids.txt $aapt2_res");
exit if ($? != 0);

# Load those unique IDs
open(my $fh, '<', "ids.txt");
chomp(my @ids = <$fh>);
close($fh);

system("$CMD_DELETE ids.txt");

print("Generating project R.txt...\n");

gen_proj_rtxt();

print("Updating resource IDs...\n");

my @r_list = ("build/R.txt");
push(@r_list, <$LIB_RES_DIR/*_R.txt>);

update_res_ids(\@ids, \@r_list);

if (-d $LIB_RES_DIR && -d $LIB_CLASS_DIR) {
	print("Generating library resource maps...\n");
	mkdir("$LIB_RES_DIR/r_java") if (!-d "$LIB_RES_DIR/r_java");
	my $rjava_list = gen_libs_rjava();

	open(my $fh, '>', "rjava_list.txt");
	print $fh join("\n", @$rjava_list);
	close($fh);

	print("Compiling resource maps...\n");
	mkdir("$LIB_RES_DIR/R") if (!-d "$LIB_RES_DIR/R");

	system("$CMD_JAVAC -source 8 -target 8 -bootclasspath $PLATFORM_DIR/android.jar -d \"$LIB_RES_DIR/R\" \@rjava_list.txt");
	exit if ($? != 0);
	unlink("rjava_list.txt");

	system("$CMD_JAR --create --file \"build/libs_r.jar\" -C \"$LIB_RES_DIR/R\" .");
	exit if ($? != 0);

	print("Compiling resource maps into DEX bytecode...\n");
	system("$CMD_D8 --intermediate \"build/libs_r.jar\" --classpath \"$PLATFORM_DIR/android.jar\" --output \"build\"");
	exit if ($? != 0);
	rename("build/classes.dex", "build/libs_r.dex");

	print("Fusing library classes into a .JAR...\n");
	system("$CMD_JAR --create --file \"build/libs.jar\" -C \"$LIB_CLASS_DIR\" .");
	exit if ($? != 0);

	print("Compiling library .JAR into DEX bytecode...\n");
	system("$CMD_D8 --intermediate \"build/libs.jar\" --classpath \"$PLATFORM_DIR/android.jar\" --output \"build\"");
	exit if ($? != 0);
	rename("build/classes.dex", "build/libs.dex");
}

print("Generating project R.java...\n");

my $pkg = get_package_from_manifest("AndroidManifest.xml");
exit if (!defined($pkg));

open($fh, '<', "build/R.txt");
chomp(my @r_txt = <$fh>);
close($fh);

my $r_java = gen_rjava($pkg, \@r_txt);

open($fh, '>', "build/R.java");
print $fh join("\n", @$r_java);
close($fh);

print("Compiling project R.java...\n");

mkdir("build/R") if (!-d "build/R");

system("$CMD_JAVAC -source 8 -target 8 -bootclasspath $PLATFORM_DIR/android.jar build/R.java -d build/R");
exit if ($? != 0);

system("$CMD_JAR --create --file build/R.jar -C build/R .");

