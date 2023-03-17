package Net::IPManager;
use strict;
use warnings FATAL => 'all';
use Net::IP;
use experimental 'signatures';
use Net::IPManager::Constants;

=head1 NAME

WGwrangler::Model::IPmanager - Manages IPs and Interface-ranges

=head1 DESCRIPTION

Keeps track of acquired and released ips

=head1 METHODS

=cut



sub new($class) {
    my $self = {
        'interface_ranges' => {},
        'acquired_ips'     => {},
        'ip_meta_info'     => {}
    };
    bless $self, $class;
    return $self;
}


=head3 populate_range($interface, $ip_ranges_str)

Sets the possible ranges for an interface. Throws an exception if C<$ip_ranges_str> contain invalid values.
C<$ip_ranges_str> is expected to be a comma-separated list of ip-ranges in CIDR notation

=cut
sub populate_range($self, $interface, $ip_ranges_str) {
    my @ranges;
    my @ips = map {_trm($_)} split /\,/, $ip_ranges_str;
    for my $ip_range (@ips) {
        my $may_ip = Net::IP->new($ip_range) or die "Could not read ip-range for `$interface`: " . Net::IP::Error();
        # prepare acquired ip storage
        $self->{acquired_ips}->{$interface}{$may_ip->ip()} = {};
        push @ranges, $may_ip;
    }
    $self->{interface_ranges}->{$interface} = \@ranges;
    $self->{ip_meta_info}->{$interface}{n_ips} = 0;
    return 1;
}

=head3 acquire_multiple($interface, $ips_string, $force=0)

Takes a string of comma-separated ip(-ranges) in CIDR notation. Returns 1 if all ips have been acquired successfully

=cut
sub acquire_multiple($self, $interface, $ips_string, $force = 0) {
    my @ips = map {_trm($_)} split /\,/, $ips_string;
    for my $ip (@ips) {
        unless ($self->acquire_single($interface, $ip, $force)) {
            # die "Could not acquire IP `$ip` for interface `$interface`";
        }
    }
    return 1;
}

=head3 acquire_single($interface, $ip_string)

Takes an ip string (one single ip) in CIDR notation and tries to acquire it respecting the already acquired ones for
this interface.

Returns undef on success.

Raises exception if C<$ip_string> is invalid.

=cut
sub acquire_single($self, $interface, $ip_string, $force = 0) {
    my $may_ip = Net::IP->new($ip_string) or die "Could not read ip for `$ip_string`: " . Net::IP::Error();
    for my $interface_range (@{$self->{interface_ranges}->{$interface}}) {
        # Check if $may_ip is the first or last ip of an interface range (and only check if want to acquire a single ip)
        if ($may_ip->size() == 1 && ($interface_range->ip() eq $may_ip->ip() || $interface_range->last_ip() eq $may_ip->last_ip())) {
            return E_CANNOT_ACQUIRE_FIRST_OR_LAST;
        }
        if ($self->_is_in($may_ip, $interface_range)) {
            # cheap check
            if ($force == 0) {
                if (exists $self->{acquired_ips}->{$interface}{$interface_range->ip()}{$may_ip->ip()}) {
                    return E_ALREADY_ACQUIRED;
                }
                # expensive check
                for my $acquired_ip (keys %{$self->{acquired_ips}->{$interface}{$interface_range->ip()}}) {
                    if ($self->_is_in($may_ip, $self->{acquired_ips}->{$interface}{$interface_range->ip()}{$acquired_ip})) {
                        return E_ALREADY_ACQUIRED;
                    }
                }
            }
            $self->{acquired_ips}->{$interface}{$interface_range->ip()}{$may_ip->ip()} = $may_ip;
            $self->{ip_meta_info}->{$interface}{n_ips}++;
            return undef;
        }
        else {
            return E_SUBNET_NOT_MATCHING;
        }
    }
    return E_UNKNOWN_INTERFACE;
}

=head3 release_ip($interface, $ip_string)

Releases a specific ip from an interface. For performance reasons, we do not check if the address has been acquired before

Returns undef on success.

Raises exception if C<$ip_string> is invalid.

=cut
sub release_ip($self, $interface, $ip_string) {
    my $may_ip = Net::IP->new($ip_string) or die "Could not read ip for `$ip_string`: " . Net::IP::Error();
    for my $interface_range (@{$self->{interface_ranges}->{$interface}}) {
        if ($self->_is_in($may_ip, $interface_range)) {
            delete $self->{acquired_ips}->{$interface}{$interface_range->ip()}{$may_ip->ip()};
            $self->{ip_meta_info}->{$interface}{n_ips}--;
            return undef;
        }
    }
    return E_UNKNOWN_INTERFACE;
}

sub _is_in($self, $ip, $range) {
    if ($range->version() == $ip->version()) {
        # Just for debugging
        # my $s = $ip->ip();
        # my $t = $range->ip();
        my $ip_result = $ip->overlaps($range);
        return $ip_result != 0;
    }
    return undef;
}

=head3 looks_like_ip($ips_string)

Checks whether C<$ips_string> looks like a valid ip in CIDR notation

=cut
sub looks_like_ip($self, $ips_string) {
    my @ips = map {_trm($_)} split /\,/, $ips_string;
    for my $ip (@ips) {
        my $may_ip = Net::IP->new($ip) or undef;
    }
    return 1;
}

=head3 get_next_ip($interface_range [, $offset = 1])

Takes a subnet (larger than /32 or /128) and returns the IP with $offset away from the network address.

=cut
sub get_next_ip($interface_range, $offset = 1) {
    my $prefix = $interface_range->version() == 4 ? '/32' : '/128';
    my $next_ip = $interface_range->ip_add_num($offset);
    # This is unfortunately necessary since ip_add_num() keeps the subnet size
    return defined $next_ip ? Net::IP->new($next_ip->ip() . $prefix) : undef;
}

=head3 suggest_ip($interface)

Returns a comma separated string of the next free ip(s) for C<$interface>. If no ips are left, an empty string is returned

=cut
sub suggest_ip($self, $interface) {
    my @suggested_ips;
    for my $interface_range (@{$self->{interface_ranges}->{$interface}}) {
        # get a list of all acquired ip/ranges for this interface and sort them lowest to highest
        my $ip_range_string = $interface_range->ip();
        my @acquired_ip_list = map {$self->{acquired_ips}->{$interface}{$ip_range_string}{$_}} keys(%{$self->{acquired_ips}->{$interface}{$ip_range_string}});
        my @acquired_ips_sorted = sort {$a->intip() <=> $b->intip()} @acquired_ip_list;

        # prepare suggestion (first possible address of interface)
        my $ip_suggestion = get_next_ip($interface_range);
        my $offset = 1;

        for my $acquired_ip (@acquired_ips_sorted) {
            if ($self->_is_in($ip_suggestion, $acquired_ip)) {

                # Calculate subnet jump size
                my $subnet_size = $acquired_ip->size();
                $offset += $subnet_size > 1 ? $subnet_size - 1 : $subnet_size;
                $ip_suggestion = get_next_ip($interface_range, $offset);
                if (!defined $ip_suggestion) {
                    # return "No IPs left for`". $ip_range->ip() ."`";
                    last;
                }
            }
            else {
                last;
            }
        }
        if ($ip_suggestion->version() == 4) {
            push @suggested_ips, $ip_suggestion->ip() . "/32";
        }
        else {
            push @suggested_ips, $ip_suggestion->ip() . "/128";
        }

    }
    return join ',', @suggested_ips;
}

=head3 is_valid_for_interface($interface, $ips_string [, $current_peer_ips])

Takes a string of ip(s), and checks whether they are a) not yes acquired and b) valid for the specified interface.
By providing C<$current_peer_ips>, reassigning the same ip as before is allowed.

Returns empty string on success and an error string on failure

=cut
sub is_valid_for_interface($self, $interface, $ips_string, $current_peer_ips = undef) {
    # First check if the requested interface is indeed valid
    if (exists $self->{interface_ranges}->{$interface}) {
        my @ips_string_to_test = map {_trm($_)} split /\,/, $ips_string;
        my @current_peer_ips = map {_trm($_)} split /\,/, $current_peer_ips if defined $current_peer_ips;
        my $found_matching_version = 0;

        for my $ip_string_to_test (@ips_string_to_test) {
            my $ip_is_within_on_disk_version = undef;
            my $ip_object_to_test = Net::IP->new($ip_string_to_test) or return Net::IP::Error();

            # First lets test if within on disk range (for this peer)
            if (defined $current_peer_ips) {
                for my $current_range_string (@current_peer_ips) {
                    my $current_range_object = Net::IP->new($current_range_string) or return Net::IP::Error();
                    if ($self->_is_in($ip_object_to_test, $current_range_object)) {
                        $ip_is_within_on_disk_version = 1;
                        $found_matching_version++;
                        last; # No further checks for this ip needed
                    }
                }
            }
            if (not defined $ip_is_within_on_disk_version) {
                for my $interface_range (@{$self->{interface_ranges}->{$interface}}) {
                    # my $s = $interface_range->ip();
                    # my $t = $self->_is_in($ip_object_to_test, $interface_range);
                    if ($self->_is_in($ip_object_to_test, $interface_range)) {
                        $found_matching_version++;
                        # Cheap check
                        if (exists $self->{acquired_ips}->{$interface}{$interface_range->ip()}{$ip_object_to_test->ip()}) {
                            return "IP/range `" . $ip_object_to_test->ip() . "` " . 'is already acquired';
                        }
                        # expensive check
                        for my $acquired_key (keys %{$self->{acquired_ips}->{$interface}{$interface_range->ip()}}) {
                            # my $t = $self->_is_in($self->{acquired_ips}->{$interface}{$interface_range->ip()}{$acquired_key}, $ip_object_to_test);
                            if ($self->_is_in($self->{acquired_ips}->{$interface}{$interface_range->ip()}{$acquired_key}, $ip_object_to_test)) {
                                return "IP/range `" . $ip_object_to_test->ip() . "`" . 'overlaps with an already acquired network';
                            }
                        }
                        last;
                    }
                }
            }

        }
        return $found_matching_version == @ips_string_to_test ? "" : 'It seems that some parts of' . "`" . $ips_string . "`" . 'do not belong to' . "`$interface`";
    }
    else {
        return "Invalid interface `$interface` - Did you call populate_range() before?";
    }

}

=head3 extract_ips($ip_string)

Utility method to parse the individual ip-string from a comma separated list

=cut
sub extract_ips($ip_string) {
    my @ips = split /\,/, $ip_string;
    chomp(@ips);
    my @results;
    for my $possible_ip (@ips) {
        my @v4 = $possible_ip =~ /(^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})/g;
        my @v6 = $possible_ip =~ /([a-f0-9:]+:+[a-f0-9]+)\/(\d{1,3})/g;
        push @results, [ $v4[0], $v4[1] ] if @v4;
        push @results, [ $v6[0], $v6[1] ] if @v6;
    }
    return \@results
}

sub _trm($str) {
    $str =~ s/^\s+|\s+$//g;
    return $str;
}
1;

1;