package Net::IPManager::Constants;
use strict;
use warnings FATAL => 'all';

use constant {
    E_ALREADY_ACQUIRED             => 'IP already acquired',
    E_NO_INTERFACES_CONFIGURED     => 'No interfaces configured',
    E_UNKNOWN_INTERFACE            => 'Unknown interface',
    E_SUBNET_NOT_MATCHING          => 'Subnet not matching',
    E_CANNOT_ACQUIRE_FIRST_OR_LAST => 'Cannot acquire first or last address of subnet',
};

use base 'Exporter';
our @EXPORT = qw(
    E_ALREADY_ACQUIRED
    E_NO_INTERFACES_CONFIGURED
    E_UNKNOWN_INTERFACE
    E_SUBNET_NOT_MATCHING
    E_CANNOT_ACQUIRE_FIRST_OR_LAST
);

1;