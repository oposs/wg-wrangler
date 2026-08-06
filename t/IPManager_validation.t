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

# Covers is_valid_for_interface() and looks_like_ip(), which are used by the
# peer form validators in WGwrangler::Model::WireguardDataAdapter but were not
# exercised by any test, and the error paths of acquire_single()/release_ip().

use constant IF4 => 'wg-test-v4';
use constant IF6 => 'wg-test-v6';

my $m = Net::IPManager->new();
$m->populate_range(IF4, '192.168.0.0/24');
$m->populate_range(IF6, 'fdc9:281f:4d7:9ee9::/64');

# --- is_valid_for_interface: the happy path returns an empty string ----------

is $m->is_valid_for_interface(IF4, '192.168.0.20/32'), '',
    'free ip inside the interface range is valid';
is $m->is_valid_for_interface(IF6, 'fdc9:281f:4d7:9ee9::20/128'), '',
    'free ipv6 inside the interface range is valid';
is $m->is_valid_for_interface(IF4, '192.168.0.20/32,192.168.0.21/32'), '',
    'comma separated list of free ips is valid';

# --- outside the range ------------------------------------------------------

isnt $m->is_valid_for_interface(IF4, '10.99.99.1/32'), '',
    'ip outside the interface range is rejected';
isnt $m->is_valid_for_interface(IF4, 'fdc9:281f:4d7:9ee9::20/128'), '',
    'ipv6 on a v4 interface is rejected';

# --- already acquired -------------------------------------------------------

$m->acquire_single(IF4, '192.168.0.30/32');
like $m->is_valid_for_interface(IF4, '192.168.0.30/32'), qr/already acquired/,
    'acquired ip is reported as acquired';

$m->acquire_single(IF4, '192.168.0.64/29');
# A range with the same base address as an acquired one hits the cheap exact
# match first, so use a wider range with a different base to reach the
# overlap check.
like $m->is_valid_for_interface(IF4, '192.168.0.0/25'), qr/overlaps/,
    'range containing an acquired network is reported as overlapping';

# --- current_peer_ips allows keeping the address you already own ------------

is $m->is_valid_for_interface(IF4, '192.168.0.30/32', '192.168.0.30/32'), '',
    'reassigning the peers own ip is allowed';

# --- unknown interface ------------------------------------------------------

like $m->is_valid_for_interface('no-such-interface', '192.168.0.20/32'),
    qr/Invalid interface/,
    'unknown interface is reported';

# --- invalid input reaches the Net::IP::XS error path -----------------------
# The exact wording comes from Net::IP::XS, so only assert that an error is
# returned rather than matching its text.

my $err = $m->is_valid_for_interface(IF4, 'definitely-not-an-ip');
ok defined $err && length $err, 'invalid ip string returns a non-empty error';
isnt $err, '', 'invalid ip string is not treated as valid';

# --- error paths of acquire_single()/release_ip() ---------------------------
# Both are documented to raise an exception on an unreadable address.

like
    do { eval { $m->acquire_single(IF4, 'not-an-ip') }; $@ },
    qr/Could not read ip/,
    'acquire_single dies on an unreadable address';

like
    do { eval { $m->release_ip(IF4, 'not-an-ip') }; $@ },
    qr/Could not read ip/,
    'release_ip dies on an unreadable address';

like
    do { eval { Net::IPManager->new()->populate_range(IF4, 'not-a-range') }; $@ },
    qr/Could not read ip-range/,
    'populate_range dies on an unreadable range';

# --- looks_like_ip ----------------------------------------------------------
# Feeds the 'single-ip' validator, which guards the 'allowed-ips' and 'DNS'
# fields of the add peer form. Those end up verbatim in the client
# configuration that is mailed to the peer, so both plain addresses and CIDR
# notation have to keep passing.

is $m->looks_like_ip('192.168.0.20/32'), 1, 'cidr address is accepted';
is $m->looks_like_ip('192.168.2.1'), 1, 'plain address without prefix is accepted';
is $m->looks_like_ip('0.0.0.0/0'), 1, 'ipv4 default route is accepted';
is $m->looks_like_ip('::/0'), 1, 'ipv6 default route is accepted';
is $m->looks_like_ip('fd00::1'), 1, 'plain ipv6 address is accepted';
is $m->looks_like_ip('0.0.0.0/0,::/0'), 1, 'comma separated list is accepted';
is $m->looks_like_ip('192.168.0.20/32, 192.168.0.21/32'), 1,
    'comma separated list with spaces is accepted';

is $m->looks_like_ip('not-an-ip'), 0, 'garbage is rejected';
is $m->looks_like_ip('999.1.1.1'), 0, 'out of range address is rejected';
is $m->looks_like_ip('192.168.0.0./24'), 0, 'malformed cidr is rejected';
is $m->looks_like_ip('192.168.0.20/32,not-an-ip'), 0,
    'a single bad entry rejects the whole list';

# Empty is rejected, which is what actually enforces required => true on the
# 'allowed-ips' field: CallBackery hands a required empty field to the
# validator and never reaches its own "field is required" branch when a
# validator exists. Optional fields such as DNS are unaffected, their
# validator is not called at all while they are empty.
is $m->looks_like_ip(''), 0, 'empty string is rejected';
is $m->looks_like_ip('  '), 0, 'whitespace only is rejected';
is $m->looks_like_ip('192.168.0.20/32,,192.168.0.21/32'), 0,
    'empty entry inside a list is rejected';
is $m->looks_like_ip('192.168.0.20/32,'), 1,
    'a single trailing comma is tolerated';

done_testing();
