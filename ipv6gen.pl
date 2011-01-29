#!/usr/bin/perl
#
# IPv6 prefix generator
#   - generates list of prefixes of certain size from given prefix
#     with one of 3 methods for bit allocation (according to
#     RFC3531)
#
#
# Vladimir Kotal <vlada@devnull.cz>, 2005
#

use Getopt::Std;
use POSIX qw(ceil floor);
use strict;

$0 =~ s|^.*/||;        # cut the basename of the command

$|=1;

# variables
my $debug = 0;		# 1 - print debug messages
my $method = "r";	# strategy for generating prefixes, default : right
my $method_set = 0;	# indicate if strategy was set
my $step = 1;		# default step between generated prefixes
my $version = "0.8";

#
# print help and exit
#
sub help ()
{
  print "$0 (v$version) - generates IPv6 prefixes from given \n";
  print "                    IPv6 prefix pool using given strategy\n\n";
  print "usage: ipv6gen [switch|strategy] <pool> <prefix length>\n";
  print "\nstrategies:\n";
  print "-l\t\tleft to right\n";
  print "-r\t\tright to left\n";
  print "-m\t\tfrom the middle out\n";
  print "\nswitches:\n";
  print "-d\t\tdisplay debug messages\n";
  print "-s <num>\t\tstep between prefixes\n";
  print "\n";

  exit(1);
}

sub debug () {
  print @_ if ($debug > 0);

}

#
# pad string from left with zeroes
#
# arg1: string to be padded
# arg2: length of resulting string
# arg3: 1 - pad from left, 0 - pad from right
#
sub zero_pad () {
  my $str = shift;
  my $len = shift;
  my $left = shift;
  
  my $i;

  my $strlen = length($str);
  for ($i = 0; $i < $len - $strlen; $i++) {
    if ($left) {
      $str = "0" . $str;
    } else {
      $str = $str . "0"; 
    }
  }
  return $str;
}

# convert dec to bin 
# and output binary number w/out leading zeroes
sub dec2bin_old() { 
  my $arg = shift @_;
  my $str = unpack('B32', pack('C', $arg)) . "";

  # strip leading zeroes
  if ($str !~ /00000000/) {
    $str =~ s/^0+// 
  } else {
    $str = "0";
  }
  return $str;
}

sub dec2bin {
  my $str = unpack("B32", pack("N", shift));
  $str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
  return $str;
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

# convert one char from binary to hex
# input char must be 4 bits long
sub bin2hex_c {
  my $binary = shift;

  my $str = unpack("H", pack("B4", $binary));
  $str =~ tr/a-f/A-F/;
  return $str;
}

# convert binary representation of IPv6 address to colon format
#
# arg1: binary represenatation of IPv6 addr
# 
# NOTE: this function does not output valid IPv6 address
#
sub binaddr_to_dots {
  my $bin = shift;

  my $out = "";
  my $first = 1;
  my $converted = 0; # number of bits converted
  my $cbd = 0; # number of chars beyond :

  my $conv;
  my $lastconv;
  # &debug("bin : $bin\n");

  while (length($bin) > 0) {
    $conv = substr($bin, 0, 4);
    # print "conv : $conv\n";
    $lastconv = bin2hex_c($conv);
    $out = $out . $lastconv;
    $converted += length($conv);
    $cbd++;
    if ((!$first) && !($converted % 16) && (length($bin) != 4)) {
      # $binlen = length($bin);
      # &debug("adding ':' [$binlen]\n");
      $out = $out . ":";
      $cbd = 0;
    }
    $first = 0;
    $bin = substr($bin, 4, length($bin) - 4);
  }
  # print "converted = $converted\n";
  # pad with null till next : boundary
  if ($cbd > 0) {
    $out = $out . substr("0000", 0, 4 - $cbd);
  }
  return $out;
}

#
# convert IPv6 address to binary
# XXX prefixlen ?
#
# arg1: XXX
#
sub addr2bin {
  my $prefix = shift;

  my @sects = split(/:/, $prefix);
  my $s;
  my $tmp;
  my $addr_bin;

  for $s (@sects) {
      # pad to zeroes from the left according to RFC 3513, section 2.3
      # (Internet Protocol Version 6 (IPv6) Addressing Architecture)
      $s = &zero_pad($s, 4, 1);
      $tmp = &hex2bin($s);
      $addr_bin = $addr_bin . $tmp;
  }
  return $addr_bin;
}

#
# check prefix format and print it if it passes the check
#
# arg1: IPv6 prefix (with prefixlen)
#
sub print_pfx () {
  my $pfx = shift;

  if (&ipv6pfx_check($pfx)) {
    print "$pfx\n";
  } else {
    print "bad prefix format: $pfx\n";
    print "#### please report this bug\n";
    exit(1);
  }
}

#
# check if IPv6 address is valid
#
# idea and parts of the regexp by Glynn Beeken via regexlib.com
#
# arg1: prefix (in format addr/prefixlen)
# return: -1 on error, 1 otherwise
# 
sub ipv6pfx_check () {
  my $prefix = shift;

  my $addr; 
  my $pfx_len;

  ($addr, $pfx_len) = split(/\//, $prefix);
  &debug("checking $prefix = $addr / $pfx_len\n");
  return (-1) if ($pfx_len > 128);

  return (1) if ($addr =~ /([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){5}::[0-9A-Fa-f]{1,4}/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){4}::[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,1}/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){3}::[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,2}/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){2}::[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,3}/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,4})/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}::[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,5}/);
  return (1) if ($addr =~ /[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,6}::/);
  return (1) if ($addr =~ /::[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,6}/);
  return (1) if ($addr =~ /::/);

  return(-1);
}

#
# print binary representation of prefix split to 2 sections
#
# arg1: binary representation of prefix
# arg2: length
# NOTE: taken from check-overlap.pl
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

# 
# print boundary mark
# arg1: index
# arg2: length
# NOTE: taken from check-overlap.pl
#
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
# NOTE: taken from check-overlap.pl
#
sub check_pfx_bin () {
  my $bits = shift;
  my $len = shift;
  my $idx;

  my $beyond_pfxlen = substr($bits, $len);
  if ($beyond_pfxlen =~ /1/) {
    print("\nerror in prefix : bit 1 found beyond prefixlen boundary\n");
    print("binary representation of the prefix:\n");
    &print_split($bits, $len);

    $idx = index($beyond_pfxlen, "1"); 
    &print_boundary_mark($idx, $len);
    exit(1);
  }
}


# convert binary representation of prefix and print it on STDOUT 
sub print_binpfx () {
  my $pfx = shift;
  my $append = shift;
  my $glen = shift;

  &debug("converting $pfx $append\n");
  my $addr = &binaddr_to_dots($pfx . $append);
  # do not append :: to prefixes with length bigger than 112
  # in order to be compliant with RFC 3513, section 2.2
  # NOTE: this would have to be changed with support of compressed format
  if ($glen <= 112) {
    $addr = $addr . "::";
  }
  &print_pfx("$addr/$glen");
}

#
# generate list of prefixes by allocating bits from the middle
# NOTE: this function actually prints prefixes to STDOUT
#
# arg1: binary representation of prefix pool addr
# arg2: length of prefix pool
# arg3: length of prefixes to be generared from pool
#
sub generate_m () {
  my $addr_bin_strip = shift;
  my $plen = shift;	
  my $glen = shift;

  my $i;
  my $rnd;
  my $str;
  my $addr;

  my $left = 0;

  my $delta = $glen - $plen;
  &debug("delta $delta\n");
  # number of rounds is equal to number of bits to be filled
  my $limit = $delta;
  my $rnd_limit = 0;

  # position of first bit with value 1
  my $central_bit = ceil($delta / 2);  

  # zero-filled str is speciall case
  $str = &zero_pad($str, $delta, 1);
  &debug("zero filled : $str\n");
  &print_binpfx($addr_bin_strip, $str, $glen);
  
  if (($delta % 2) == 0) {
    $left = 1;
  }
  
  for ($rnd = 0; $rnd < $limit; $rnd++) {
    $rnd_limit=2 ** $rnd; # number of passes in each round
    &debug("----- round \# $rnd\n");
    &debug("left: $left\n");
    &debug("central_bit: $central_bit\n");
    for ($i = 0; $i < $rnd_limit; $i++) {
      $str = &dec2bin($i);
      #&debug("dec2bin: $i = $str\n");
   
      my $tmp = "";
      # $str = &zero_pad($str, $central_bit, 1); 
      if ($left == 1) {
	$tmp = &zero_pad($tmp, $central_bit - 1, 1);
        $tmp = $tmp . "1";
        # &debug("tmp: $tmp\n");
        $str = reverse $str; 
	$str = $tmp . $str;
      } else {
        $str = $str . "1";
        $str = &zero_pad($str, $central_bit, 1);
      }
      $str = &zero_pad($str, $delta, 0);
      &debug("middle: $str\n");
      &print_binpfx($addr_bin_strip, $str, $glen);
    }
    $left = ($left + 1) % 2;
    if ($left) {
      $central_bit = $central_bit - $rnd -1;
    } else {
      $central_bit = $central_bit + $rnd +1;
    }
  }
}


#
# generate list of prefixes by allocating bits from the left/right
# NOTE: this function actually prints prefixes to STDOUT
#
# arg1: binary representation of prefix pool addr
# arg2: length of prefix pool
# arg3: length of prefixes to be generared from pool
# arg4: 1 - generate from left, 0 - right
#
sub generate_rl () {
  my $addr_bin_strip = shift;
  my $plen = shift;	
  my $glen = shift;
  my $reverse = shift;

  my $i;
  my $str;
  my $addr;

  my $delta = $glen - $plen;
  &debug("delta $delta\n");
  my $limit = 2 ** $delta;
  die "step bigger than limit ($step > $limit)" if ($step > $limit);

  &debug("will generate " . $limit/$step . " prefixes\n");
  for ($i = 0; $i < $limit; $i+=$step) {
    $str = &dec2bin($i);
    # my $debug_str = reverse $str if ($reverse);
    # &debug("generated bits: $debug_str\n");
    $str = &zero_pad($str, $delta, 1);
    $str = reverse $str if ($reverse);

    &print_binpfx($addr_bin_strip, $str, $glen);
  }
}

#
# generate IPv6 prefixes from IPv6 prefix pool using given strategy
# arg1: prefix to generate from
# arg2: length of prefixes to be generated
# arg3: method for
#
sub generate () {
  my $prefix = shift; 	# prefix pool
  my $plen = shift; 	# length of prefix pool
  my $glen = shift; 	# length of prefixes to be generated
  my $method = shift;

  my $addr_bin = &addr2bin($prefix);
  &check_pfx_bin($addr_bin, $plen);
  
  &debug("binary addr : $addr_bin (not padded/cropped)\n");
  # pad the prefix to $plen, otherwise we would get wrong results
  $addr_bin = &zero_pad($addr_bin, $plen, 0);
  my $addr_bin_strip = substr($addr_bin, 0, $plen);
  &debug("binary addr : " . $addr_bin_strip . "($plen) \n");

  # call proper generating function
  if ($method =~ /r/) {
    &generate_rl($addr_bin_strip, $plen, $glen, 0);
  } elsif ($method =~ /l/) {
    &generate_rl($addr_bin_strip, $plen, $glen, 1);
  } elsif ($method =~ /m/) {
    &generate_m($addr_bin_strip, $plen, $glen);
  }
}

#
# set strategy for generating prefixes
#
sub set_method () {
  $method = shift @_;

  die "only single step is possible for middle bit allocation" 
    if (($step > 1) and ($method =~ /^m$/));
  &debug("setting method $method\n");

  &help if ($method_set == 1);
}

# --------------------------------------------------------------------------
# MAIN
# --------------------------------------------------------------------------

my $opts = {};
&getopts('s:dhmlr', $opts);
&help if exists $opts->{"h"};
$debug = 1 if exists $opts->{"d"};
$step = $opts->{"s"} if exists $opts->{"s"};

&help if (scalar(@ARGV) != 2);

&set_method("l") if exists $opts->{"l"};
&set_method("r") if exists $opts->{"r"};
&set_method("m") if exists $opts->{"m"};

if (&ipv6pfx_check($ARGV[0]) < 0) {
  print "bad prefix $ARGV[0]\n";
  exit(1);
}

my $addr;
my $pfx_len;

($addr, $pfx_len) = split(/\//, $ARGV[0]);

my $genlen = $ARGV[1];
if ($genlen !~ /^[0-9]+$/) {
  print "length of prefix to be generated is not number: $genlen\n";
  exit(1);
} 

if ($genlen < $pfx_len) {
 print "cannot generate \/$genlen prefixes from \/$pfx_len prefix\n";
 exit(1);
}

&generate($addr, $pfx_len, $genlen, $method);

# EOF
