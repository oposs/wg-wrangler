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

$IPManager->populate_range(TEST_INTERFACE, '192.168.0.0/24');

# acquire single ip and check if the suggestions are updated accordingly
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '192.168.0.1/32', "Single ip suggestion 1";
$IPManager->acquire_single(TEST_INTERFACE, '192.168.0.1/32');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '192.168.0.2/32', "Single ip suggestion 2";

# Release ip again and check if suggestions are updated accordingly
$IPManager->release_ip(TEST_INTERFACE, '192.168.0.1/32');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '192.168.0.1/32', "Single ip successfully released";

# acquire other (higher) ip and check if suggestions are still returning the lowest possible address
$IPManager->acquire_single(TEST_INTERFACE, '192.168.0.10/32');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '192.168.0.1/32', "Acquire arbitrary and suggest";

# Checks
# Try to required already occupied address
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.10/32') eq E_ALREADY_ACQUIRED, 'Already acquired';

# Try to acquire/release on unknown interface
ok $IPManager->acquire_single('DOES NOT EXIST', '192.168.0.10/32') eq E_UNKNOWN_INTERFACE, 'Unknown interface (acquire)';
ok $IPManager->release_ip('DOES NOT EXIST', '192.168.0.10/32') eq E_UNKNOWN_INTERFACE, 'Unknown interface (acquire)';

# Wrong subnet
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.2.10/32') eq E_SUBNET_NOT_MATCHING, 'Non matching subnet (acquire)';

# Entire networks (192.168.0.0 - 192.168.0.7)
$IPManager->acquire_single(TEST_INTERFACE, '192.168.0.0/29');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '192.168.0.8/32', 'IP suggestions after network acquire';
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.6/32') eq E_ALREADY_ACQUIRED, 'Try acquiring ip inside acquired subnet';
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.8/29') eq E_ALREADY_ACQUIRED, 'Try acquiring with overlapping subnet';

# Multi acquire
$IPManager->acquire_multiple(TEST_INTERFACE, '192.168.0.8/32,192.168.0.9/32');
ok $IPManager->suggest_ip(TEST_INTERFACE) eq '192.168.0.11/32', 'IP suggestion after multi-acquire';

# try release ip inside acquired subnet
$IPManager->release_ip(TEST_INTERFACE, '192.168.0.4/32');
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.4/32') eq E_ALREADY_ACQUIRED, 'Try release ip inside subnet';

# try acquire with overlapping subnet
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.8/29') eq E_ALREADY_ACQUIRED, 'Try acquire with overlapping address';

# try acquire first and last address of interface subnet
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.0/32') eq E_CANNOT_ACQUIRE_FIRST_OR_LAST, 'Try acquire first';
ok $IPManager->acquire_single(TEST_INTERFACE, '192.168.0.255/32') eq E_CANNOT_ACQUIRE_FIRST_OR_LAST, 'Try acquire last';

done_testing();

