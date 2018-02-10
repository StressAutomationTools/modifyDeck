###############################################################################
#
# Deck modification script
#
# created by Jens M Hebisch
#
# Version 0.1
#
# This script is intended to apply modifications to bulk data files
# Note: only bulk data entries have been tested. Case control and PARAM may
# not work properly.
# this script supports short form, long form and free form formats
#
# The script has several modes:
# use: perl ModifyDeck.pl parameters fileWithModifications file/find
# parameters:
# c to comment cards
# sc to substitude cards, commenting the existing cards
# sd to substitude cards, deleting the existing cards
# d to delete the existing cards
# fileWithModifications:
# a file containing the bulk data cards to be substituted/commented/deleted
# ensure that this only contains cards that are to be modified.
# Properties, materials etc might be associated with cards to modified but
# may not require modification themselves.
# file/find:
# list one or more files (space separated) or use find to operate on all bdf
# files in the directory (will not modify the file that is supplied as 
# fileWithModifications
#
# All files that have been modified will be output as MOD_originalFileName
# Existing files that match this pattern will cause the program to terminate
# to protect existing files.
# A log file will be generated showing which cards were found in which files
# and any cards that were not found in any of the files.
#
###############################################################################
use warnings;
use strict;

my ($parameters, $modfile, @files) = @ARGV;

if($files[0] eq "find"){
	@files = <*.bdf>;
}

my $comment = 0;
my $substitude = 0;

if($parameters eq "c"){
	$comment = 1;
}
elsif($parameters eq "sc"){
	$comment = 1;
	$substitude = 1;
}
elsif($parameters eq "sd"){
	$substitude = 1;
}
elsif($parameters eq "d"){
	#nothing
}
else{
	print "no valid parameters supplied. Exiting\n";
	exit;
}

sub safelyOpen{
	#prevents files from getting overwritten by checking first if a file with the 
	#same name already exists. If it does, a warning will be printed and the 
	#program will exit.
	my $file = $_[0];
	if(-e $file){
		print $file." already exists.\n";
		print "To protect the file from being overwritten, the program will now exit.\n";
		exit;
	}
	elsif(not $file){
		print "No filename was provided.\n";
		print "As no file could be created, the program will now exit\n";
		exit;
	}
	else{
		open(my $filehandle, ">", $file) or print "File could not be opened.\n" and die;
		return $filehandle;
	}
}

sub getIdentifier{
	#works for all card formats
	my $line = $_[0];
	my $card;
	my $ID;
	if(m/\*/){
		#long form
		my @fields = unpack('(A8)(A16)*',$line);
		$card = $fields[0];
		$card =~ m/(.*)\*/;
		$card = $1;
		$ID = $fields[1];
	}
	elsif(m/,/){
		#free form
		my @fields = split(",",$line);
		$card = $fields[0];
		$ID = $fields[1];
	}
	else{
		#short form
		my @fields = unpack('(A8)*',$line);
		$card = $fields[0];
		$fields[1] =~ m/(\d+)/;
		$ID = $1;
	}
	return $card.(" "x(8-length($card))).$ID;
}

sub printNew{
	my($filehandle,$arrayref) = @_;
	my @lines = @{$arrayref};
	foreach my $line (@lines){
		print $filehandle $line."\n";
	}
}

#read modifications
open(MOD, "<", $modfile) or die "Could not open file with modifications\n";
my %modifications;
my $ID;
while(<MOD>){
	my $line = $_;
	chomp($line);
	if($line =~ m/^\$/){
		#ignore
	}
	elsif($line =~ m/^\w/){
		$ID = getIdentifier($line);
		$modifications{$ID} = []; #overwrite if duplicates
		push(@{$modifications{$ID}},$line);
	}
	elsif($line){
		if($ID){
			push(@{$modifications{$ID}},$line);
		}
	}
}
close(MOD);

my %found;
open(LOG, ">", "ModifyDeck.log");
foreach my $file (@files){
	unless($file eq $modfile){
		print LOG "Cards found in $file:\n";
		my $modifications = 0;
		open(IPT, "<", $file) or die "Could not open $file";
		my $fh = safelyOpen("MOD_".$file);
		$ID = 0;
		while(<IPT>){
			my $line = $_;
			chomp($line);
			if($line =~ m/^\$/){
				if($ID and $substitude){
					#close off current card
					printNew($fh,$modifications{$ID});
				}
				$ID = 0;
				print $fh $line."\n";
			}
			elsif($line =~ m/^\w/){
				if($ID and $substitude){
					#close off current card
					printNew($fh,$modifications{$ID});
				}
				$ID = getIdentifier($line);
				if($modifications{$ID}){
					print LOG $ID."\n";
					$found{$ID} = 1;
					$modifications = 1;
					if($comment){
						print $fh "\$".$line."\n";
					}
				}
				else{
					$ID = 0;
					print $fh $line."\n";
				}
			}
			elsif($ID){
				if($comment){
					print $fh "\$".$line."\n";
				}
			}
			else{
				print $fh $line."\n";
			}
		}
		if($ID and $substitude){
			#close off current card
			printNew($fh,$modifications{$ID});
		}
		close(IPT);
		close($fh);
		if($modifications){
			print LOG "Modified file is MOD_$file\n";
		}
		else{
			unlink("MOD_".$file);
			print LOG "No Modifications to this file\n";
		}
	}
}
print LOG "***The following cards have not been found in any of the files:\n";
foreach my $mod (keys(%modifications)){
	unless($found{$mod}){
		print LOG $mod."\n";
	}
}
close(LOG);
