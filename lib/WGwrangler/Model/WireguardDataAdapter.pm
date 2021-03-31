package WGwrangler::Model::WireguardDataAdapter;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';
use Mojo::JSON qw(true false);

use Wireguard::WGmeta::Utils;
use Wireguard::WGmeta::Wrapper::Show;
use Wireguard::WGmeta::Wrapper::ConfigT;
use Wireguard::WGmeta::Wrapper::Bridge;
use WGwrangler::Model::IPmanager;


sub new($class, $wireguard_home) {

    my $wg_show_data = read_file('/home/tobias/Documents/wg-wrangler/dummy_wg_home/wg_show_dummy');
    my $wg_metaT = Wireguard::WGmeta::Wrapper::ConfigT->new($wireguard_home);
    my $wg_meta_show = Wireguard::WGmeta::Wrapper::Show->new($wg_show_data);
    my $ip_manager = WGwrangler::Model::IPmanager->new();
    my $initial_table_data = _generate_table_source($wg_metaT, $wg_meta_show);
    for my $interface (keys %{$wg_metaT->{parsed_config}}) {
        _populate_ip_manager($interface, $wg_metaT, $ip_manager);
    }
    my $self = {
        'wireguard_home' => $wireguard_home,
        'wg_metaT'       => $wg_metaT,
        'wg_show'        => $wg_meta_show,
        'ip_manager'     => $ip_manager,
        'table_data'     => $initial_table_data,
        'filterd_data'   => $initial_table_data
    };
    $wg_metaT->register_on_reload_listener(\&_reload_callback, 'reload_callback', [ $self ]);
    bless $self, $class;
    return $self;
}

sub _reload_callback($interface, $ref_list_args) {
    my ($self) = @{$ref_list_args};
    _populate_ip_manager($interface, $self->{wg_metaT}, $self->{ip_manager});
    $self->{table_data} = _generate_table_source($self->{wg_metaT}, $self->{wg_show});
}

sub _populate_ip_manager($interface, $wg_metaT, $ip_manager) {
    if (exists $wg_metaT->{parsed_config}{$interface}{$interface}{address}) {
        my $interface_networks = $wg_metaT->{parsed_config}{$interface}{$interface}{address};
        $ip_manager->populate_range($interface, $interface_networks);
    }
    for my $idenifier (@{$wg_metaT->{parsed_config}{$interface}{section_order}}) {
        unless ($idenifier eq $interface) {
            # Dummy loop, needed for later
            next;
        }
    }
}

# convinience methods to get IDE support for attr-completation and doc
#@returns Wireguard::WGmeta::Wrapper::ConfigT
sub wg_meta($self) {
    return $self->{wg_metaT};
}

#@returns Wireguard::WGmeta::Wrapper::Show
sub wg_show($self) {
    return $self->{wg_show};
}

#@returns WGwrangler::Model::IPmanager
sub ip_manager($self) {
    return $self->{ip_manager};
}

sub suggest_ip($self, $interface, $n) {
    # return join '/32, ', $self->ip_manager()->ipv4_suggest($interface, $n);
    return "not implemented yet";
}

sub validate_ips_for_interface($self, $interface, $ips) {
    return $self->ip_manager()->is_valid_for_interface($interface, $ips);
}

sub validate_alias_for_interface($self, $interface, $identifier, $alias) {
    # ToDo: This is just a workaround until wg-meta supports is_valid_alias()
    my $validated_name = $self->validate_name($alias);
    return $validated_name if $validated_name;
    $self->wg_meta()->_may_reload_from_disk();
    if (exists $self->wg_meta()->{parsed_config}{$interface}{alias_map}{$alias}) {
        if ($self->wg_meta()->try_translate_alias($interface, $alias) eq $identifier) {
            return "";
        }
        else {
            return "Alias is already defined for this interface";
        }
    }
    return "";
}

sub validate_name($self, $name) {
    return $name =~ /[^a-zA-Z0-9_\-]/g ? "Only a-Z, 0-9 and -/_ allowed" : "";
}

sub get_public_key($self, $private_key) {
    return get_pub_key($private_key);
}

sub gen_key_pair($self) {
    my @keypair = gen_keypair();
    return { 'private-key' => $keypair[0], 'public-key' => $keypair[1] }
}

sub get_peer_count($self, $filter) {
    $self->wg_meta()->_may_reload_from_disk();
    my $filtered_data = _apply_filter($self->{table_data}, $filter);
    return @{$filtered_data};
}

sub update_peer_data($self, $interface, $identfier, $attr, $value) {
    $self->wg_meta()->set($interface, $identfier, $attr, $value, 1);
}

sub add_peer($self, $interface, $name, $ip_address, $public_key, $alias, $pre_shared_key) {
    # my $peer_networks = extract_ipv4($ip_address);
    # for my $peer_network (@{$peer_networks}) {
    #     my ($network, $sub_netsize) = @{$peer_network};
    #     if (defined $network) {
    #         for my $ipv4_address (@{get_ip_list($network, $sub_netsize)}) {
    #             $self->ip_manager()->ipv4_acquire($ipv4_address, $interface);
    #         }
    #     }
    # }
    $self->wg_meta()->add_peer($interface, $name, $ip_address, $public_key, $alias, $pre_shared_key);
}

sub remove_peer($self, $interface, $identifier, $ref_integrity_hash) {
    $self->wg_meta()->remove_peer($interface, $identifier);
    $self->wg_meta()->commit(1, 0, $ref_integrity_hash);
}

sub commit_changes($self, $ref_integrity_hashes) {
    $self->wg_meta()->commit(1, 0, $ref_integrity_hashes);
}
sub sort_table_data($self, $data, $key, $order) {
    my @keys_to_sort = map {$_->{$key}} @{$data};
    my @sorted_indexes;
    if (defined $order) {
        @sorted_indexes = sort {$keys_to_sort[$b] cmp $keys_to_sort[$a]} 0 .. $#keys_to_sort;
    }
    else {
        @sorted_indexes = sort {$keys_to_sort[$a] cmp $keys_to_sort[$b]} 0 .. $#keys_to_sort;
    }
    return [ @{$data}[ @sorted_indexes ] ];
}

sub get_section_data($self, $interface, $identifier) {
    my %d = $self->wg_meta()->get_interface_section($interface, $identifier);
    $d{interface} = $interface;
    $d{integrity_hash} = $self->wg_meta()->calculate_sha_from_internal($interface, $identifier);
    return \%d;
}

sub get_interface_selection($self) {
    return [ { title => '', key => '0' }, map {{ title => $_, key => $_ }} $self->wg_meta()->get_interface_list() ];
}

sub disable_peer($self, $interface, $identifier, $integrity_hash) {
    $self->wg_meta()->disable($interface, $identifier);
    $self->wg_meta()->commit(1, 0, $integrity_hash);
}
sub enable_peer($self, $interface, $identifier, $integrity_hash) {
    $self->wg_meta()->enable($interface, $identifier);
    $self->wg_meta()->commit(1, 0, $integrity_hash);
}

sub _generate_table_source($wg_meta, $wg_show) {
    my @table_data;
    for my $interface ($wg_meta->get_interface_list()) {
        my $row_data = {};
        for my $identifier ($wg_meta->get_section_list($interface)) {
            # skip interfaces
            unless ($identifier eq $interface) {
                # add wirguard data
                my %wg_section_data = $wg_meta->get_interface_section($interface, $identifier);
                $wg_section_data{interface} = $interface;

                # handling of disabled attr
                if (exists($wg_section_data{disabled})) {
                    $wg_section_data{disabled} = true if $wg_section_data{disabled} == 1;
                }
                else {
                    $wg_section_data{disabled} = false;
                }
                $row_data = \%wg_section_data;

                # add wg-show data
                if ($wg_show->iface_exists($interface)) {
                    my %show_section_data = $wg_show->get_interface_section($interface, $identifier);
                    for my $attr_name (keys %show_section_data) {
                        $row_data->{$attr_name} = $show_section_data{$attr_name};
                    }
                }
                push @table_data, $row_data;
            }
        }
    }
    return \@table_data;
}


sub _apply_filter($ref_data, $filter) {
    if ($filter) {
        my @filtered_data;
        my @filter_terms = map {s/^\s+|\s+$//g;
            $_} split /\s+/, $filter;
        for my $row_hash (@{$ref_data}) {
            for my $filter_term (@filter_terms) {
                if (index(lc $row_hash->{name}, lc $filter_term) != -1
                    || $row_hash->{'public-key'} eq $filter_term
                    || $row_hash->{'interface'} eq $filter_term
                    || $row_hash->{'allowed-ips'} =~ /$filter_term/) {
                    push @filtered_data, $row_hash;
                }
            }
        }
        return \@filtered_data;
    }
    else {
        return $ref_data;
    }
}

sub get_peer_table_data($self, $first_row, $last_row, $filter) {
    my @table_data = @{$self->{table_data}};
    $last_row = $#table_data if ($last_row > $#table_data);
    return _apply_filter([ @table_data[$first_row .. $last_row] ], $filter);
}


1;