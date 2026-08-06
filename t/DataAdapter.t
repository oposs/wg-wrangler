#!/usr/bin/perl
use strict;
use warnings;

# Keep the wg* commands out of this test. Has to happen before the app is
# built, since the model reads it when it is constructed.
BEGIN { $ENV{WGwrangler_NO_WG} = 1 }

use experimental 'signatures';
use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';

use Test::More;
use Test::Mojo;

# Exercises WGwrangler::Model::WireguardDataAdapter against the dummy wireguard
# home in t/dummy_home. Read only and validation calls, nothing here writes to
# the configuration files.

my $t = Test::Mojo->new('WGwrangler');
my $m = $t->app->wireguardModel;
ok $m, 'wireguard model is available';

# Validators return CallBackery::Translate objects on failure, which do not
# overload string comparison, so force stringification before comparing.
sub check ($attribute, $value, @rest) {
    return '' . $m->validator($attribute, $value, @rest);
}

# --- validator dispatch -----------------------------------------------------
# Every validator returns an empty string when the value is acceptable and a
# message otherwise.

is check('device', 'my_device-1'), '', 'device accepts letters, digits, - and _';
isnt check('device', 'bad device!'), '', 'device rejects other characters';

is check('interface', 'wg0'), '', 'interface accepts a plain name';
isnt check('interface', 'wg 0/x'), '', 'interface rejects other characters';

is check('email', 'someone@example.com'), '', 'email accepts an address';
isnt check('email', 'not-an-email'), '', 'email rejects a non address';

is check('name', 'Some Name'), '', 'name accepts one space';
isnt check('name', 'Some$Name'), '', 'name rejects special characters';

is check('listen-port', '51820'), '', 'listen-port accepts a port above 1024';
isnt check('listen-port', '80'), '', 'listen-port rejects a privileged port';
isnt check('listen-port', '70000'), '', 'listen-port rejects a port above 65535';
isnt check('listen-port', 'abc'), '', 'listen-port rejects a non number';

isnt check('single-ip', undef), '', 'an undefined value is always rejected';

# --- single-ip, the validator behind allowed-ips and DNS --------------------
# These two values are copied verbatim into the client configuration that is
# mailed to the peer, so they have to hold real addresses.

is check('single-ip', '192.168.0.1'), '', 'single-ip accepts a plain address';
is check('single-ip', '0.0.0.0/0'), '', 'single-ip accepts a default route';
is check('single-ip', '0.0.0.0/0,::/0'), '', 'single-ip accepts a list';
isnt check('single-ip', 'not-an-ip'), '', 'single-ip rejects garbage';
isnt check('single-ip', ''), '', 'single-ip rejects an empty value';

# --- interface validation ---------------------------------------------------

ok $m->validate_interface('wg0'), 'wg0 from the dummy home is a known interface';
ok !$m->validate_interface('does-not-exist'), 'an unknown interface is rejected';

# --- read only queries ------------------------------------------------------

my $selection = $m->get_interface_selection();
is ref $selection, 'ARRAY', 'get_interface_selection returns a list';
ok scalar @$selection > 1, 'the dummy home contributes interfaces beyond the empty entry';
ok scalar(grep { $_->{key} eq 'wg0' } @$selection), 'wg0 is offered for selection';

ok $m->get_peer_count('') > 0, 'the dummy home has peers';

# --- key handling -----------------------------------------------------------
# With WGwrangler_NO_WG set these must return placeholders instead of shelling
# out to wg, which is what lets the suite run without wireguard installed.

my $pair = $m->gen_key_pair();
is ref $pair, 'HASH', 'gen_key_pair returns a hash';
ok defined $pair->{'private-key'} && defined $pair->{'public-key'},
    'gen_key_pair returns both keys';

my $pub = $m->get_public_key($pair->{'private-key'});
ok defined $pub && length $pub, 'a public key is derived from a private key';

# --- suggest_ip -------------------------------------------------------------

my $suggestion = $m->suggest_ip('wg0');
ok defined $suggestion && length $suggestion, 'an ip is suggested for wg0';
is check('single-ip', $suggestion), '',
    'the suggested ip passes the single-ip validator';

# 10.0.10.0/29 is listed under reserved_ranges in t/etc/wgwrangler.yaml, so
# the first eight addresses must never be suggested.
unlike $suggestion, qr{^10\.0\.10\.[0-7]/}, 'the suggestion avoids the reserved range';

done_testing();
