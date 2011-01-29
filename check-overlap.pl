#!/usr/bin/perl
#
# check if two IPv6 prefixes overlap correctly
#
# functions for conversions betweeen hex and binary are
# based on script hex2bin.pl by Stas Bekman <stas@stason.org>
#
# Vladimir Kotal <vlada@devnull.cz>, 2005
#

use Getopt::Std;
use strict;

$0 =~ s|^.*/||;        # cut the basename of the command

# opt vars
my $quiet = 0;
my $debug = 0;

# global variables
my $error = 0;

# Define the separation character between each binary number
my $char = " ";

# print help and exit
sub help () {
  print "usage: $0 <bigger_prefix> <smaller_prefix>\n";
  exit(1);
}

sub debug () {
  print @_ if ($debug > 0);

}

# convert one char in hex to binary
sub hex2bin_c {
    my ($digit) = shift;
    return unpack("B4", pack("H", $digit));
}


# convert string with hex representation to binary
sub hex2bin {
  my $in = shift;
  my $out;

  my @digits = split //, $in;
  for (@digits) {
    $out = $out . hex2bin_c($_);
  }
  return $out;
}


# XXX
sub addr2bin {
  my $prefix = shift;
  my @sects = split(/:/, $prefix);
  my $s;
  my $tmp;
  my $addr_bin = "";

  for $s (@sects) {
      $tmp = &hex2bin($s);
      $addr_bin = $addr_bin . $tmp;
  }
  return $addr_bin;
}


#
# print binary representation of prefix split to 2 sections
#
# arg1: binary representation of prefix
# arg2: length
#
sub print_split {
  my $bits = shift;
  my $len= shift;

  &debug("$bits\n");
  print   substr($bits, 0, $len) 
	. " " 
	. substr($bits, $len) 
	. "\n";
}

# XXX
sub print_boundary_mark () {
  my $idx = shift;
  my $len = shift;

  my $i;

  for ($i = 0; $i < $len - 3; $i++) {
    print " ";
  }
  print "\/$len";
  if ($idx > 0) {
    for ($i = 0; $i < $idx + 1; $i++) {
      print " ";
    }
    print "^";
  }
  print "\n";
}

#
# check for 1 bits behind prefix length limit
#
# arg1: binary representation of address
# arg2: length of prefix
#
sub check_pfx_bin () {
  my $bits = shift;
  my $len = shift;
  my $idx;

  my $beyond_pfxlen = substr($bits, $len);
  if ($beyond_pfxlen =~ /1/) {
    if ($quiet != 1) {
      print "\nerror in prefix : bit 1 found beyond prefixlen boundary\n";
      print "binary representation of the prefix:\n";
      &print_split($bits, $len);

      $idx = index($beyond_pfxlen, "1"); 
      &print_boundary_mark($idx, $len);
    }
    $error++;
    return(1);
  }
}


#
# check if smaller prefix fits into bigger prefix
# 
# arg1: bigger IPv6 prefix 
# arg2: smaller IPv6 prefix
#
sub check_overlap {
  my $prefix1 = shift;
  my $prefix2 = shift;

  my $big_pfx_part;
  my $big_pfx_len;
  my $small_pfx_part;
  my $small_pfx_len;

  ($big_pfx_part, $big_pfx_len) = split(/\//, $prefix1);
  ($small_pfx_part, $small_pfx_len) = split(/\//, $prefix2);

  my $big_bits = &addr2bin($big_pfx_part);
  my $small_bits = &addr2bin($small_pfx_part);

  # smaller prefixlen makes bigger prefix
  if ($big_pfx_len > $small_pfx_len) {
    print "bigger prefix should be specified first\n";
    return(1);
  }

  print "--- checking overlap" if ($quiet == 0); 

  my $f = substr($big_bits, 0, $big_pfx_len);
  my $s = substr($small_bits, 0, $big_pfx_len);
  if ($f cmp $s) {
    print " ... prefixes do NOT overlap\n" if ($quiet == 0);
    # print "$f\n$s\n";
    &debug("$prefix1\n");
    &print_split($big_bits, $big_pfx_len);
    &debug("$prefix2\n");
    &print_split($small_bits, $big_pfx_len);
    &print_boundary_mark(0, $big_pfx_len);
    $error++;
    return(1);
  }
  print " ... OK (overlapping)\n" if ($quiet == 0);
}


#
# check prefix
# this is really just a wrapper to check_pfx_bin()
#
# arg1: prefix
#
sub check_pfx () {
  my $prefix = shift;
  my $pfx_part;
  my $pfx_len;

  ($pfx_part, $pfx_len) = split(/\//, $prefix);

  my $pfx_bits = &addr2bin($pfx_part);
  
  print "--- checking $prefix" if ($quiet == 0); 
  if (!&check_pfx_bin($pfx_bits, $pfx_len)) {
    print " ... OK\n" if ($quiet == 0);
  }
}


#
# check format of prefix
# arg1: prefix
# XXX
# 
sub check_fmt() {
  my $prefix = shift;

  return(0);
}

# 
# MAIN
#
my $opts = {};
&getopts('qdh', $opts);
&help if exists $opts->{"h"};
$debug = 1 if exists $opts->{"d"};
$quiet = 1 if exists $opts->{"q"};

&help if (scalar(@ARGV) != 2);


# check IPv6 prefix format
# XXX check if IPv6 address has the right format
if (&check_fmt($ARGV[0]) || &check_fmt($ARGV[1])) {
  print "bad prefix format\n";
  exit(1);
}

# run the checks
print "----  doing prefix checks first\n" if ($quiet == 0); 
&check_pfx($ARGV[0]);
&check_pfx($ARGV[1]);

&check_overlap($ARGV[0], $ARGV[1]) if ($error == 0);

exit (1) if ($error);
