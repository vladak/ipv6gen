# ipv6gen
IPv6 prefix generator

ipv6gen is tool which generates list of IPv6 prefixes of given length from certain prefix 
according to [RFC 3531](http://www.ietf.org/rfc/rfc3531.txt). (A Flexible Method for Managing the Assignment of 
Bits of an IPv6 Address Block)

This is intended as a helper script for either constructing IPv6 addressing scheme or allocating prefixes automatically. 
ipv6gen is structured into functions, which can be used in proprietary scripts.

ipv6gen is written in Perl.

ipv6gen is used in the following publications:
  *IPv6 Address Planning* by Tom Coffeen, published by O'Reilly in 2014.
  *IPv6 Fundamentals: A Straightforward Approach to Understanding IPv6, 2nd Edition* by Rick Graziani, published by Cisco Press in 2017.

ipv6gen and other related scripts are GPL licensed. 
If you take some code out of ipv6gen and use it in your project, it would be nice if you mention that it comes from ipv6gen.

How does it work ?
  - input :
    - prefix from which we will be generating smaller prefixes
    - method of bit allocation (left, right, from the middle)
    - size of prefixes to be generated
  - output : list of prefixes according to input data

## Changelog

see `Changelog.txt`

## Examples ipv6gen

### Generating prefixes for subnets

Say we want to generate /64 prefixes for application servers from
2001:1508:1003::/48, each /64 prefix for servers of given type.
If method specifier is omited, allocation from the
right will be used:

```
$ ./ipv6gen.pl 2001:1508:1003::/48 64


2001:1508:1003:0000::/64
2001:1508:1003:0001::/64
2001:1508:1003:0002::/64
2001:1508:1003:0003::/64

...

2001:1508:1003:FFFA::/64
2001:1508:1003:FFFB::/64
2001:1508:1003:FFFC::/64
2001:1508:1003:FFFD::/64
2001:1508:1003:FFFE::/64
2001:1508:1003:FFFF::/64
```

### Splitting prefixes

Or we just need to split /48 prefix into two prefixes:

```
$ ./ipv6gen.pl 2001:1508:1003::/48 49
2001:1508:1003:0000::/49
2001:1508:1003:8000::/49
```

This is actually example of allocation which is prone to errors. First byte
after /48 boundary is 10000000 in binary which is 128 in decimal, which is 80
in hexa.

### Flexible bit allocation

Or we need to flexibly allocate prefixes which will be used for further
allocations by starting allocating bits in the middle. In this example,
debugging option `-d` will be used to see that the bits are really allocated
this way:

```
$ ./ipv6gen.pl -d -m 2001:1508:1003::/48 53
binary addr : 001000000000000100010101000010000001000000000011
binary addr : 001000000000000100010101000010000001000000000011(48) 
delta 5
zero filled : 00000
converting 001000000000000100010101000010000001000000000011 # 00000
2001:1508:1003:0000::/53
----- round # 0
left: 0
central_bit: 3
middle: 00100
converting 001000000000000100010101000010000001000000000011 # 00100
2001:1508:1003:2000::/53
----- round # 1
left: 1
central_bit: 2
middle: 01000
converting 001000000000000100010101000010000001000000000011 # 01000
2001:1508:1003:4000::/53
middle: 01100
converting 001000000000000100010101000010000001000000000011 # 01100
2001:1508:1003:6000::/53
----- round # 2
left: 0
central_bit: 4
middle: 00010
converting 001000000000000100010101000010000001000000000011 # 00010
2001:1508:1003:1000::/53
middle: 00110
converting 001000000000000100010101000010000001000000000011 # 00110
2001:1508:1003:3000::/53
middle: 01010
converting 001000000000000100010101000010000001000000000011 # 01010
2001:1508:1003:5000::/53
middle: 01110
converting 001000000000000100010101000010000001000000000011 # 01110
2001:1508:1003:7000::/53

...
```

### Leaving gaps between generated prefixes

ipv6gen can also leave out gaps between each two generated prefixes.
This is usefull when designing allocation schemes which should be
extendable. Such scheme is for example using RIPE. Currently it gives out
/32 prefixes to LIRs. For each LIR, it leaves out 7 subsequent prefixes,
which will be used in case LIR will need more address space. These
subsequent prefixes can be aggregated up to to /29 prefix.

For example, one of the prefixes allocated by IANA to RIPE NCC is
2001:1400::/23 prefix. From this prefix, RIPE NCC further
allocates /32 prefixes (in general) to LIRs. These prefixes are allocated
using rightmost allocation. For each prefix, 7 subsequent prefixes are
left out. So, RIPE could use ipv6gen for this task:

```
$ ./ipv6gen.pl -s 8 -r 2001:1400::/23 32
2001:1400::/32
2001:1408::/32
2001:1410::/32
2001:1418::/32
2001:1420::/32
2001:1428::/32
2001:1430::/32
2001:1438::/32

...
```

Compare this output with list of prefixes allocated by RIPE to LIRs to see that this is really the scheme
RIPE uses.

### check-overlap

This script checks if one prefix is allocated from second prefix.

But check-overlap script does more than that. It does 3 kinds of checks:

- IPv6 address format check
  It checks if IPv6 address format is correct (according to RFC3513, section 2.2.)
  XXX: implemented only in ipv6gen
- correctness of IPv6 prefix address
  Checks for bits with value 1 beyond prefixlen boundary.
  This check is also implemented in ipv6gen.
- check for overlapping prefixes
  Check if two prefixes overlap - i.e. second prefix was allocated from the first one.

If one of the checks fails, following checks are not made:

```
$ ./check-overlap.pl 2001:1508:1000:FFFF::/45 2001:1508:1000:FF00:/56
----  doing prefix checks first
--- checking 2001:1508:1000:FFFF::/45
error in prefix : bit 1 found beyond prefixlen boundary
binary representation of the prefix:
0010000000000001000101010000100000010000000000001111111111111111
001000000000000100010101000010000001000000000 0001111111111111111
                                          /45    ^
--- checking 2001:1508:1000:FF00:/56 ... OK
```

For some prefixes it is not visible on the first sight, if they are overlapping:

```
$ ./check-overlap.pl 2001:1508:FFD0:40::/50 2001:1508:FFB0:C0::/51
----  doing prefix checks first
--- checking 2001:1508:FFD0:40::/50 ... OK
--- checking 2001:1508:FFB0:C0::/51 ... OK
--- checking overlap ... prefixes do NOT overlap
00100000000000010001010100001000111111111101000001 000000
00100000000000010001010100001000111111111011000011 000000
                                               /50
```

... but these are not.

These are clear:

```
$ ./check-overlap.pl 2001:1508::/32 2001:1508:FFB0:C0::/52
----  doing prefix checks first
--- checking 2001:1508::/32 ... OK
--- checking 2001:1508:FFB0:C0::/52 ... OK
--- checking overlap ... OK (overlapping)
```

## Known bugs/TODO

- add support of compressed IPv6 address format according to RFC3513, section 2.2.
- make Perl code more clean
- make a Perl library for work with IPv6 prefixes (?)
- better man page
- make ipv6gen available as cgi script
