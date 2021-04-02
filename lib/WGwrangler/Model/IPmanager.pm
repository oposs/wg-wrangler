package WGwrangler::Model::IPmanager;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';
use Data::Dumper;

use Net::IP;

sub new($class) {
    my $self = {
        'interface_ranges' => {},
        'ip_meta_info'     => {},
        'acquired_ips'     => {},
    };
    bless $self, $class;
    return $self;
}

sub populate_range($self, $interface, $ip_ranges_str) {
    my @ranges;
    my @ips = map {trm($_)} split /\,/, $ip_ranges_str;
    for my $ip_range (@ips) {
        my $may_ip = Net::IP->new($ip_range) or die "Could not read ip-range for `$interface`: " . Net::IP::Error();
        # prepare acquired ip storage
        $self->{acquired_ips}{$interface}{$may_ip->ip()} = {};
        push @ranges, $may_ip;
    }
    $self->{interface_ranges}{$interface} = \@ranges;
    $self->{ip_meta_info}{$interface}{n_ips} = 0;
    return 1;
}

sub acquire_multiple($self, $interface, $ips_string) {
    my @ips = map {trm($_)} split /\,/, $ips_string;
    for my $ip (@ips) {
        unless ($self->acquire_single($interface, $ip)) {
            # die "Could not acquire IP `$ip` for interface `$interface`";
        }
    }
}

sub acquire_single($self, $interface, $ip_string) {
    my $may_ip = Net::IP->new($ip_string) or die "Could not read ip for `$ip_string`: " . Net::IP::Error();
    for my $interface_range (@{$self->{interface_ranges}{$interface}}) {
        if ($self->_is_in($may_ip, $interface_range)) {
            # cheap check
            if (exists $self->{acquired_ips}{$interface}{$interface_range->ip()}{$may_ip->ip()}) {
                return undef;
            }
            # expensive check
            for my $acquired_key (keys %{$self->{acquired_ips}{$interface}{$interface_range->ip()}}) {
                if ($self->_is_in($may_ip, $self->{acquired_ips}{$interface}{$interface_range->ip()}{$acquired_key})) {
                    return undef;
                }
            }
            $self->{acquired_ips}{$interface}{$interface_range->ip()}{$may_ip->ip()} = $may_ip;
            $self->{ip_meta_info}{$interface}{n_ips}++;
            return 1;
        }
    }
    return undef;
}

sub release_ip($self, $interface, $ip_string) {
    my $may_ip = Net::IP->new($ip_string) or die "Could not read ip for `$ip_string`: " . Net::IP::Error();
    for my $interface_range (@{$self->{interface_ranges}{$interface}}) {
        if ($self->_is_in($may_ip, $interface_range)) {
            delete $self->{acquired_ips}{$interface}{$interface_range->ip()}{$may_ip->ip()};
            $self->{ip_meta_info}{$interface}{n_ips}--;
            return 1;
        }
    }
    return undef;
}

sub _is_in($self, $ip, $range) {
    if ($range->version() == $ip->version()) {
        my $ip_result = $ip->overlaps($range);

        return $ip_result && ($ip_result == $IP_IDENTICAL || $ip_result == $IP_A_IN_B_OVERLAP || $range->intip() == $ip->intip());
    }
    return undef;
}

sub looks_like_ip($self, $ips_string) {
    my @ips = map {trm($_)} split /\,/, $ips_string;
    for my $ip (@ips) {
        my $may_ip = Net::IP->new($ip) or return Net::IP::Error();
    }
    return "";
}

sub external_is_in($self, $ips_string, $ranges_string) {
    my @ips = map {trm($_)} split /\,/, $ips_string;
    my @ranges = map {trm($_)} split /\,/, $ranges_string;
    for my $ip_str (@ips) {
        my $may_ip = Net::IP->new($ip_str) or return Net::IP::Error();
        for my $range_str (@ranges) {
            my $may_range = Net::IP->new($range_str) or return Net::IP::Error();
            unless ($self->_is_in($may_ip, $may_range)) {
                return undef
            }
        }
    }
    return 1;
}


sub suggest_ip($self, $interface) {
    my @suggested_ips;
    for my $ip_range (@{$self->{interface_ranges}{$interface}}) {
        # get a list of all acquired ip/ranges for this interface and sort them lowest to highest
        my $ip_range_string = $ip_range->ip();
        my @acquired_ip_list = map {$self->{acquired_ips}{$interface}{$ip_range_string}{$_}} keys(%{$self->{acquired_ips}{$interface}{$ip_range_string}});
        my @acquired_ips_sorted = sort {$a->intip() <=> $b->intip()} @acquired_ip_list;

        # prepare suggestion
        my $ip_suggestion = $ip_range->ip_add_num(1);

        for my $acquired_ip (@acquired_ips_sorted) {
            if ($self->_is_in($ip_suggestion, $acquired_ip)) {

                $ip_suggestion = $ip_suggestion->ip_add_num($acquired_ip->size());
                if (!$ip_suggestion) {
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

sub is_valid_for_interface($self, $interface, $ips_string) {
    if (exists $self->{interface_ranges}{$interface}) {
        my @ips = map {trm($_)} split /\,/, $ips_string;
        my $found_matching_version = undef;

        for my $ip_string_tt (@ips) {
            my $may_ip = Net::IP->new($ip_string_tt) or return Net::IP::Error();

            for my $interface_range (@{$self->{interface_ranges}{$interface}}) {
                if ($self->_is_in($may_ip, $interface_range)) {
                    $found_matching_version = 1;
                    # Cheap check
                    if (exists $self->{acquired_ips}{$interface}{$interface_range->ip()}{$may_ip->ip()}) {
                        return "IP/range `" . $may_ip->ip() . "` is already acquired";
                    }
                    # expensive check
                    for my $acquired_key (keys %{$self->{acquired_ips}{$interface}{$interface_range->ip()}}) {
                        if ($self->_is_in($may_ip, $self->{acquired_ips}{$interface}{$interface_range->ip()}{$acquired_key})) {
                            return "IP/range `" . $may_ip->ip() . "` is within an already acquired network";
                        }
                    }
                    last;
                }
                else {
                    return "It seems that `$ip_string_tt` does not belong to `$interface`";
                }
            }
        }
        return $found_matching_version ? "" : "It seems that `$ips_string` does not belong to `$interface`";
    }
    else {
        return "Invalid interface `$interface` - Did you call populate_range() before?";
    }

}
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

sub trm($str) {
    $str =~ s/^\s+|\s+$//g;
    return $str;
}
1;