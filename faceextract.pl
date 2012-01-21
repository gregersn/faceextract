#!/bin/perl -w
#
use strict;
use utf8;
use XML::Simple qw(:strict);
use Data::Dumper;
use Image::ExifTool qw(:Public);

if(scalar(@ARGV) == 1)
{
	chdir($ARGV[0]);
}

# Location of contact file
my $contactsfile = "/cygdrive/c/Users/greger/AppData/Local/Google/Picasa2/contacts/contacts.xml"; 

# Picasa-file-filename
my $filename = ".picasa.ini";

my $xml = new XML::Simple ( ForceArray => 1);
my $xmpinfo;

# Parse the contacts file, and make a contact map
my $contacts = $xml->XMLin($contactsfile, ForceArray=>1, KeyAttr =>{}, );
my %contactmap = ();
my $conts = $contacts->{contact};
foreach my $contact (@$conts)
{
	$contactmap{$contact->{id}} = $contact->{name};
}


# Open and read the picasa file into an array
open(PICASAFILE, $filename) || die("Could noe open picasafile");
my @picasadata = <PICASAFILE>;
close(PICASAFILE);

# Remove all carriage returns.
foreach my $line (@picasadata)
{
	$line =~ s/\r\n/\n/;
}

# Go through the picasa file
for(my $i = 0; $i < scalar(@picasadata); $i++)
{
	if($picasadata[$i] =~ /^\[(.*)\]/)
	{
		my $exifTool = new Image::ExifTool();
		print $1."\n";
		my $xmpfile = $1;
		if($xmpfile =~ m/NEF/i)
		{
			$xmpfile =~ s/NEF/xmp/gi;
		}
		print "Using $xmpfile for info.\n";
		$exifTool->Options(List => 1);
		$xmpinfo = $exifTool->ImageInfo($xmpfile);
		
		my $Subjects = $exifTool->GetValue('Subject');
		my $Hierarchical = $exifTool->GetValue('HierarchicalSubject');
		
		$i++;
		my $changes = 0;
		if($picasadata[$i] =~ /^faces=(.*)/)
		{
			my @faces = split(/;/, $1);
			print "\tFound ".scalar(@faces)." faces\n";
			foreach my $face (@faces)
			{
				my ($region, $id) = split(/,/, $face);
				my $new_subject = $contactmap{$id};
				print "\t\tFound: ".$new_subject."\n";
				my $old = 0;
				if(ref($Subjects) eq "ARRAY")
				{
					for my $subject (@$Subjects)
					{
						if($subject eq $new_subject)
						{
							$old = 1;
						}
					}
				}
				elsif(ref($Subjects) eq "SCALAR")
				{
					if($$Subjects eq $new_subject)
					{
						$old = 1;
					}

				}
				if(!$old)
				{
					$exifTool->SetNewValue(Subject => $new_subject, AddValue=>1);
					print "Added to keywords.\n";
					$changes++;
				}

				$old = 0;
				#print Dumper($Hierarchical);
				if(ref($Hierarchical) eq "ARRAY")
				{				
					for my $subject (@$Hierarchical)
					{
						if($subject eq ("People|Persons|".$new_subject))
						{
							$old = 1;
						}
					}
				}
				elsif(ref($Hierarchical) eq "SCALAR")
				{
					if($$Hierarchical eq ("People|Persons|".$new_subject))
					{
						$old = 1;
					}
				}
				
				if(!$old)
				{
					$exifTool->SetNewValue(HierarchicalSubject => ("People|Persons|".$new_subject), AddValue=>1);
					print "Added to hierarchical keywords.\n";
					$changes++;
				}

			}
		}
#		$changes = 0;
		if($changes > 0)
		{
			my $ret = $exifTool->WriteInfo($xmpfile);
			if($ret == 1) { print "\tFile written ok.\n"; }
			if($ret == 2) { print "\tFile written, no changes.\n"; } #Should not happen
			if($ret == 0) { print "\t *** File write error on file: ".$xmpfile." ***\n"; }
		}
		else
		{
			print "\tNo changes to file.\n";
		}
	}
	print "\n";

}


