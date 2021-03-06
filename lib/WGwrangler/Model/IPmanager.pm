package WGwrangler::Model::IPmanager;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';

use Net::IP;

sub new($class) {
    my $self = {
        'ip_database'  => {},
        'ip_meta_info' => {}
    };
    bless $self, $class;
    return $self;
}

sub populate_range($self, $interface, $ips_string) {
    my @ranges;
    my $interface_ranges = {};
    my @ips = map {trm($_)} split /\,/, $ips_string;
    for my $ip_range (@ips) {
        my $may_ip = Net::IP->new($ip_range) or die "Could not read ip-range for `$interface`: ".Net::IP::Error();
        push @ranges, $may_ip;
    }
    $self->{ip_database}{$interface} = \@ranges;
    return 1;
}

sub is_valid_for_interface($self, $interface, $ips_string) {
    if (exists $self->{ip_database}{$interface}) {
        my @ips = map {trm($_)} split /\,/, $ips_string;
        my $found_matching_version = undef;

        for my $ip_range (@ips) {
            my $may_ip = Net::IP->new($ip_range) or return Net::IP::Error();

            for my $ip_object (@{$self->{ip_database}{$interface}}) {
                if ($ip_object->version() == $may_ip->version()) {
                    $found_matching_version = 1;
                    my $ip_result = $ip_object->overlaps($may_ip);
                    if ($ip_result && ($ip_result == $IP_IDENTICAL || $ip_result == $IP_B_IN_A_OVERLAP)) {
                        next;
                    }
                    else {
                        return "It seems that `$ip_range` does not belong to `$interface`";

                    }
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