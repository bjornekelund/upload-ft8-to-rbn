#!/usr/bin/perl

# For Red Pitaya 125-14 and 122.88-16 with Pavel Demin's FT8 receiver @
# https://pavel-demin.github.io/red-pitaya-notes/sdr-transceiver-ft8
# https://pavel-demin.github.io/stemlab-sdr-notes/sdr-transceiver-ft8

# Parses FT8 decode file /dev/shm/decodes-yymmdd-hhmm.txt from previous minute with format 
# 181216 014645  34.7   4 -0.98  7075924 SM7IUN          JO65

# Sends WSJT-X UDP packets per definition @ 
# https://sourceforge.net/p/wsjt/wsjt/HEAD/tree/branches/wsjtx/NetworkMessage.hpp
# However omits some information that is ignored by RBN Aggregator

# By Björn Ekelund SM7IUN 2019-03-08
# Elements copied from jtudp.pl perl script by Andy Zwirko K1RA

# Start by using following command line
# ./upload-to-rbn.pl YOURCALL YOURGRID HOSTIP UDPPORT
# ./upload-to-rbn.pl sm7iun jo65mr 192.168.1.9 2237

use strict;
use warnings;

use IO::Socket;

# Software descriptor and version info
my $ID = "STEMLab SDR";
my $VERSION = "1.0";
my $REVISION = "a";


# check CALL SIGN argument
if(! defined($ARGV[0]) || (! ($ARGV[0] =~ /\w\d+\w/)) ) { 
	die "Enter a valid call sign\n"; 
}
my $mycall = uc($ARGV[0]);

# check GRID SQUARE argument (6 digit)
if(! defined($ARGV[1]) || (! ($ARGV[1] =~ /^\w\w\d\d\w\w$/)) ) { 
	die "Enter a valid 6 digit grid\n";
} 
my $mygrid = uc($ARGV[1]);

# check HOST IP argument
if(! defined($ARGV[2]) || (! ($ARGV[2] =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)) ) { 
	die "Enter a valid IP address ex: 192.168.1.2\n";
} 
my $peerhost = $ARGV[2];

# check UDP PORT argument
if(! defined($ARGV[3]) || (! ($ARGV[3] =~ /^\d{2,5}$/)) ) { 
	die "Enter a valid UDP port number ex: 2237\n";
} 
my $peerport = $ARGV[3];

# WSJT-X UDP header
my $header = "ad bc cb da 00 00 00 02 ";
$header = join("", split(" ", $header));

# Message descriptors

my $msg1 = join("", split(" ", "00 00 00 01")); # Status datagram
my $msg2 = join("", split(" ","00 00 00 02")); # Decode datagram
#my $maxschema = join("", split(" ", "00 00 00 03")); # Maxschema

# FT8 decoder log fields
my $msg;
my $date;
my $gmt;
my $x;
my $dt;
my $snr;
my $freq;

my $ft8msg;

# Msg 1 Local station info fields
my $dxcall;
my $report;
my $rxdf = 1024;
my $txdf = 1024;
my $decall = $mycall;
my $degrid = $mygrid;
my $dxgrid;

my $filename;
my $yr;
my $mo;
my $dy;
my $hr;
my $mn;

# lookup table to determine base FT8 frequency used to calculate Hz offset
my %basefrq = (
	"184" => 1840000,
	"183" => 1840000,
	"357" => 3573000,
	"535" => 5357000,
	"707" => 7074000,
	"1013" => 10136000,
	"1407" => 14074000,
	"1810" => 18100000,
	"1809" => 18100000,
	"2107" => 21074000,
	"2491" => 24915000,
	"2807" => 28074000,
	"5031" => 50313000
);

# used for calculating signal in Hz from base band FT8 frequency
my $base;
my $hz;

# decode current and last times
#my $time;
my $ltime;
my $secs;

# client socket
my $sock;

$| = 1;

# derive time for previous minute to create decode TXT filename
($x, $mn, $hr, $dy, $mo, $yr, $x, $x, $x) = gmtime(time - 60);

# create filename to read based on latest date/time stamp
$filename = "/dev/shm/" . sprintf("decodes_%02d%02d%02d_%02d%02d.txt", 
	$yr - 100, $mo + 1, $dy, $hr, $mn);
#$filename = "/dev/shm/" . sprintf("decodes_%02d%02d%02d_%02d%02d.txt",19,3,8,15,24); 

# printf("Adjusted date/time: Y:%02d M:%02d D:%02d H:%02d M:%02d\n", $yr - 100, $mo + 1, $dy, $hr, $mn);
# print "Decode file name: $filename\n";

# open TXT file for the corresponding date/time
open(TXT, '<:encoding(UTF-8)', $filename) 
	or die "Could not open '$filename' $!";

# open UDP socket
$sock = IO::Socket::INET->new(
	Proto => 'udp',
	PeerPort => $peerport,
	PeerAddr => $peerhost,
) or die "Could not create socket: $!\n";

MSG:

# loop thru all decodes

while($msg = <TXT>) {
	chomp $msg;

	# check if this is a valid FT8 decode line beginning with 6 digit time stamp
	# 181216 014645  34.7   4 -0.98  7075924 SM7IUN    JO65
	if(! ($msg =~ /^\d{6}\s\d{6}/) ) {
#		print "rbn-udp.pl: Invalid date/time - Ignored: \n$msg\n";
		next MSG;
	}

	# looks like a valid line split into variable fields
	($date, $gmt, $x, $report, $dt, $freq, $dxcall, $dxgrid)= split(" ", $msg);

	# skip if no valid call
	if(($dxcall eq "") || (! ($dxcall =~ /\d/))) { 
#		print "rbn-udp.pl: Invalid call - Ignored: \n$msg\n";
		next MSG; 
	}
		
	# extract HHMM
	$gmt =~ /^(\d\d\d\d)\d\d/;
	$gmt = $1;

	# determine base frequency for this FT8 band decode
	$base = int($freq / 10000);

	# make freq an integer
	$freq += 0;

	$ft8msg = "CQ " . $dxcall . " " . $dxgrid;
	
#	print "$ft8msg\n";

	$hz = int($freq - $basefrq{ $base});

	# Msg 1 - Location station info
	print $sock (
		pack("H*", $header) .
		pack("H*", $msg1) . 
		pack("N*", length($ID)) . 
		pack("A*", $ID) .
		pack("N*", 0) . # Lower 4 bytes of base frequency = 0
		pack("N*", $basefrq{ $base}) . 
#		pack("N*", $freq) . send standard FT8 freq for RBN/Aggregator
		pack("N*", length("FT8")) . 
		pack("A*", "FT8") .
		pack("N*", length($dxcall)) . 
		pack("A*", $dxcall) .
		pack("N*", length($report)) . 
		pack("A*", $report) .
		pack("N*", length("FT8")) . 
		pack("A*", "FT8") .
		pack("h", 0) . # TX enabled = False
		pack("h", 0) . # Transmitting = False
		pack("h*", 0) . # Decoding = False
		pack("N*", $rxdf) .
		pack("N*", $txdf) .
		pack("N*", length($decall)) . 
		pack("A*", $decall) .
		pack("N*", length($degrid)) . 
		pack("A*", $degrid) .
		pack("N*", length($dxgrid)) . 
		pack("A*", $dxgrid) .
		pack("h", 0) . # TX Watchdog = False
		pack("N*", length("")) . # Submode = ""
		pack("A*", "") . # Submode = ""
		pack("h", 0) # Fast mode = False
	);

	print $sock (
		pack("H*", $header) .
		pack("H*", $msg2) . 
		pack("N*", length($ID)) . 
		pack("A*", $ID) .
		pack("h", 1) . 
#		pack("N*", $secs) .
		pack("N*", 0) .
		pack("N*", $report) .
		pack("d>", $dt) .
		pack("N*", $hz) .
		pack("N*", length("FT8")) . 
		pack("A*", "FT8") .
		pack("N*", length($ft8msg)) . 
		pack("A*", $ft8msg) .
		pack("h", 0) .
		pack("h", 0)
	);
	
} # end while there are lines left in file

# close socket
$sock->close();

