#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use experimental 'signatures';
use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use Net::IPManager;
use Net::IPManager::Constants;

my $IPManager = Net::IPManager->new();
use constant TEST_INTERFACE => 'test-interface';

$IPManager->populate_range(TEST_INTERFACE, '2001:db8::/64');

# acquire single ip and check if the suggestions are updated accordingly
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '2001:0db8:0000:0000:0000:0000:0000:0001/128', "Single ip suggestion 1";
$IPManager->acquire_single(TEST_INTERFACE, '2001:db8::1/128');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '2001:0db8:0000:0000:0000:0000:0000:0002/128', "Single ip suggestion 2";

# Release ip again and check if suggestions are updated accordingly
$IPManager->release_ip(TEST_INTERFACE, '2001:db8::1/128');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '2001:0db8:0000:0000:0000:0000:0000:0001/128', "Single ip successfully released";

# acquire other (higher) ip and check if suggestions are still returning the lowest possible address
$IPManager->acquire_single(TEST_INTERFACE, '2001:db8::83/128');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '2001:0db8:0000:0000:0000:0000:0000:0001/128', "Acquire arbitrary and suggest";

# Checks
# Try to required already occupied address
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:db8::83/128') eq E_ALREADY_ACQUIRED, 'Already acquired';

# Try to acquire/release on unknown interface
ok $IPManager->acquire_single('DOES NOT EXIST', '2001:db8::a/128') eq E_UNKNOWN_INTERFACE, 'Unknown interface (acquire)';
ok $IPManager->release_ip('DOES NOT EXIST', '2001:0db8:0000:0000:0000:0000:0000:000a/128') eq E_UNKNOWN_INTERFACE, 'Unknown interface (acquire)';

# Wrong subnet
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:db9::a/128') eq E_SUBNET_NOT_MATCHING, 'Non matching subnet (acquire)';

# Entire networks (2001:db8:: - 2001:db8::7f)
$IPManager->acquire_single(TEST_INTERFACE, '2001:db8::2/128');
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:db8::/121') eq E_ALREADY_ACQUIRED, 'Try acquiring overlapping subnet';
# release ::2 and try again
$IPManager->release_ip(TEST_INTERFACE, '2001:db8::2/128');
$IPManager->acquire_single(TEST_INTERFACE, '2001:db8::/121');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '2001:0db8:0000:0000:0000:0000:0000:0080/128', 'IP suggestions after network acquire';
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:db8::6f') eq E_ALREADY_ACQUIRED, 'Try acquiring ip inside acquired subnet';

# Multi acquire
$IPManager->acquire_single(TEST_INTERFACE, '2001:0db8:0000:0000:0000:0000:0000:0080/128');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '2001:0db8:0000:0000:0000:0000:0000:0081/128', 'IP suggestion after multi-acquire';

# try release ip inside acquired subnet
$IPManager->release_ip(TEST_INTERFACE, '2001:db8::12/128');
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:db8::12/128') eq E_ALREADY_ACQUIRED, 'Try release ip inside subnet';

# try acquire first and last address of interface subnet
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:db8::/128') eq E_CANNOT_ACQUIRE_FIRST_OR_LAST, 'Try acquire first';
ok $IPManager->acquire_single(TEST_INTERFACE, '2001:0db8:0000:0000:ffff:ffff:ffff:ffff/128') eq E_CANNOT_ACQUIRE_FIRST_OR_LAST, 'Try acquire last';

done_testing();

