package WGwrangler::Model::WireguardDataAdapter;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';
use Mojo::JSON qw(true false);
use File::Copy qw(move);

use Wireguard::WGmeta::Utils;
use Wireguard::WGmeta::Wrapper::Show;
use Wireguard::WGmeta::Wrapper::ConfigT;
use Wireguard::WGmeta::Wrapper::Bridge;
use Wireguard::WGmeta::Validator;
use WGwrangler::Model::IPmanager;


sub new($class, $wireguard_home, $not_applied_prefix) {

    my $wg_show_data = read_file($wireguard_home . 'wg_show_dummy');
    my $custom_attr_config = {
        'email' => {
            'in_config_name' => 'Email',
            'validator'      => sub($value) {return $value =~ /^\S+@\S+\.\S+$/;}
        }
    };
    my $wg_metaT = Wireguard::WGmeta::Wrapper::ConfigT->new($wireguard_home, '#+', '#-', $not_applied_prefix, $custom_attr_config);
    my $wg_meta_show = Wireguard::WGmeta::Wrapper::Show->new($wg_show_data);
    my $ip_manager = WGwrangler::Model::IPmanager->new();
    my $initial_table_data = _generate_table_source($wg_metaT, $wg_meta_show);
    for my $interface (keys %{$wg_metaT->{parsed_config}}) {
        _populate_ip_manager($interface, $wg_metaT, $ip_manager);
    }
    my $self = {
        'wireguard_home'     => $wireguard_home,
        'not_applied_prefix' => $not_applied_prefix,
        'wg_metaT'           => $wg_metaT,
        'wg_show'            => $wg_meta_show,
        'ip_manager'         => $ip_manager,
        'table_data'         => $initial_table_data,
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
    for my $identifier (@{$wg_metaT->{parsed_config}{$interface}{section_order}}) {
        unless ($identifier eq $interface) {
            my $ips_string = $wg_metaT->{parsed_config}{$interface}{$identifier}{'allowed-ips'};
            $ip_manager->acquire_multiple($interface, $ips_string);
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

sub suggest_ip($self, $interface) {
    return $self->ip_manager()->suggest_ip($interface);
}

sub validate_ips_for_interface($self, $interface, $identifier, $ips) {
    my %peer_data = $self->wg_meta()->get_interface_section($interface, $identifier);

    return $self->ip_manager()->is_valid_for_interface($interface, $ips, $peer_data{'allowed-ips'});
}

sub looks_like_ip($self, $ips_string) {
    return $self->ip_manager()->looks_like_ip($ips_string);
}

sub validate_alias_for_interface($self, $interface, $identifier, $alias) {
    # ToDo: This is just a workaround until wg-meta supports is_valid_alias()
    my $validated_name = $self->validate_name($alias);
    return $validated_name if $validated_name;
    $self->wg_meta()->may_reload_from_disk($interface);
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

sub validate_interface($self, $interface) {
    return $self->wg_meta()->is_valid_interface($interface);
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
    my $filtered_data = _apply_filter(_generate_table_source($self->{wg_metaT}, $self->{wg_show}), $filter);
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
    $self->wg_meta()->commit(0, 0, $ref_integrity_hash);
}

sub commit_changes($self, $ref_integrity_hashes) {
    $self->wg_meta()->commit(0, 0, $ref_integrity_hashes);
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
    $self->wg_meta()->commit(0, 0, $integrity_hash);
}
sub enable_peer($self, $interface, $identifier, $integrity_hash) {
    $self->wg_meta()->enable($interface, $identifier);
    $self->wg_meta()->commit(0, 0, $integrity_hash);
}

sub apply_config($self) {
    for my $interface ($self->wg_meta()->get_interface_list()) {
        my $safe_path = $self->{wireguard_home} . $interface . $self->{not_applied_prefix};
        my $hot_path = $self->{wireguard_home} . $interface . '.conf';
        if (-e $safe_path) {
            move($hot_path, $hot_path . '.old') or die "Could not apply for `$interface`" . $!;
            move($safe_path, $hot_path) or die "Could not apply for `$interface`" . $!;
        }
    }
}

sub discard_changes($self) {
    for my $interface ($self->wg_meta()->get_interface_list()) {
        my $safe_path = $self->{wireguard_home} . $interface . $self->{not_applied_prefix};
        if (-e $safe_path) {
            unlink($safe_path);
        }
    }
}

sub has_not_applied_changes($self){
    for my $interface ($self->wg_meta()->get_interface_list()) {
        my $safe_path = $self->{wireguard_home} . $interface . $self->{not_applied_prefix};
        if (-e $safe_path) {
            return 1;
        }
    }
    return undef;
}

sub _generate_table_source($wg_meta, $wg_show) {
    my @table_data;
    for my $interface ($wg_meta->get_interface_list()) {
        my $row_data = {};
        for my $identifier ($wg_meta->get_section_list($interface)) {
            # skip interfaces
            unless ($identifier eq $interface) {
                # add wireguard data
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
            my $filter_string = join '', map {$row_hash->{$_} if defined $row_hash->{$_}} ('name', 'public-key', 'interface', 'allowed-ips', 'email');
            for my $filter_term (@filter_terms) {
                if ($filter_string =~ $filter_term) {
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
    # unfortunatly we have to apply the filter twice since get_n_rows() and get_table_data() are two separate calls
    my @table_data = @{_apply_filter(_generate_table_source($self->{wg_metaT}, $self->{wg_show}), $filter)};
    $last_row = $#table_data if ($last_row > $#table_data);
    return [ @table_data[$first_row .. $last_row] ];
}


1;