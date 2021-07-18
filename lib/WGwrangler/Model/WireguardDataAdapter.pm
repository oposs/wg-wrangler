=head1 NAME

WGwrangler::Model::WireguardDataAdapter - Interface to L<Wireguard::WGmeta>

=head1 DESCRIPTION

Provides various methods to interact with the Wireguard configuration files

=head1 METHODS

=cut

package WGwrangler::Model::WireguardDataAdapter;
use Mojo::Base -base, -signatures;
use Mojo::JSON qw(true false);
use File::Copy qw(move);
use Scalar::Util qw(looks_like_number);

use Wireguard::WGmeta::Utils;
use Wireguard::WGmeta::Wrapper::Show;
use Wireguard::WGmeta::Wrapper::ConfigT;
use Wireguard::WGmeta::Wrapper::Bridge;
use Wireguard::WGmeta::Validator;
use WGwrangler::Model::IPmanager;
use CallBackery::Translate qw(trm);

has app => sub {
    die 'app property must be set';
};

has log => sub ($self) {
    $self->app->log;
};

has 'wireguard_home' => sub {
    die 'This is a required attribute';
};

has 'backend_config' => sub ($self) {
    $self->app->config->cfgHash->{BACKEND}
};

has 'is_hot_config' => sub {
    return 1;
};

has 'not_applied_suffix' => sub {
    return '.not_applied';
};

has 'wg_not_installed' => sub {
    return defined $ENV{'WGwrangler_NO_WG'}
};

has 'wg_meta' => sub ($self) {
    my $custom_attr_config = {
        'email' => {
            'validator' => sub($value) {return $value =~ /^\S+@\S+\.\S+$/;}
        },
        device  => {
            'validator' => sub($value) {return 1}

        },
        created => {
            'validator' => sub($value) {return 1}
        },
        fqdn    => {
            'validator' => sub($value) {return 1}
        }
    };
    my $wg_metaT = Wireguard::WGmeta::Wrapper::ConfigT->new($self->wireguard_home, '#+', '#-', $self->not_applied_suffix, $custom_attr_config);
    $wg_metaT->register_on_reload_listener(\&_reload_callback, 'reload_callback', [ $self ]);
    return $wg_metaT;
};

has 'wg_show' => sub ($self) {
    Wireguard::WGmeta::Wrapper::Show->new($self->_get_wg_show_data());
};

has 'ip_manager' => sub ($self) {
    my $ip_manager = WGwrangler::Model::IPmanager->new();
    for my $interface (keys %{$self->wg_meta->{parsed_config}}) {
        _populate_ip_manager($interface, $self->wg_meta, $ip_manager);
    }
    return $ip_manager;
};

sub _get_wg_show_data ($self) {
    my (@output, undef) = run_external($self->backend_config->{wg_show_command});
    return join '', @output;
}

sub _reload_callback ($interface, $ref_list_args) {
    my ($self) = @{$ref_list_args};
    _populate_ip_manager($interface, $self->wg_meta, $self->ip_manager);
}

sub _populate_ip_manager ($interface, $wg_metaT, $ip_manager) {
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

=head3 suggest_ip($interface)

Suggests the next free ip(s) for a given interface

=cut
sub suggest_ip ($self, $interface) {
    return $self->ip_manager->suggest_ip($interface);
}

=head3 validator($attribute, $value [, $interface, $identifier])

Collection of all validator functions. Each validation function takes 3 arguments and must return
an empty string on success and an error message on failure

=cut
sub validator ($self, $attribute, $value, $interface = undef, $identifier = undef) {
    unless (defined $value) {
        return 'Value must be defined';
    }
    my $validator_mapping = {
        'device'               => sub ($device_name, $int, $ident) {return $device_name =~ /[^a-zA-Z0-9_\-]/g ? trm('Only a-Z, 0-9 and -/_ allowed') : ''},
        'interface'            => sub ($interface_name, $int, $ident) {return $interface_name =~ /[^a-zA-Z0-9_\-]/g ? trm('Only a-Z, 0-9 and -/_ allowed') : ''},
        'email'                => sub ($email, $int, $ident) {return $email =~ /^\S+@\S+\.\S+$/ ? '' : trm('Does not look like an email address')},
        'name'                 => sub ($name, $int, $ident) {return $name =~ /[^a-zA-Z0-9_\-\s{1}]/g ? trm('Only a-Z, 0-9, -/_ and one space are allowed') : ''},
        'single-ip'            => sub ($ip_address, $int, $ident) {$self->ip_manager->looks_like_ip($ip_address) == 1 ? '' : trm('Does not look like an ip address')},
        'address_override'     => sub ($ips, $int, $ident) {
            unless (defined $ident && defined $int) {
                return trm('Not enough arguments for validator `address_override`');
            }
            my %peer_data = $self->wg_meta->get_interface_section($int, $ident);
            return $self->ip_manager->is_valid_for_interface($int, $ips, $peer_data{'allowed-ips'});

        },
        'listen-port'          => sub ($port, $int, $ident) {
            (looks_like_number($port) && $port > 1024 && $port <= 65535) ? return '' : return trm('Has to be in range 1025-65535 and a number')
        },
        'alias'                => sub ($alias, $int, $ident) {
            unless (defined $int) {
                return trm('Not enough arguments for validator `alias`');
            }
            return $self->wg_meta->is_valid_alias($int, $alias) ? trm('Alias is already defined for this interface') : '';
        },
        'persistent-keepalive' => sub ($val, $int, $ident) {return (looks_like_number($val) && $val > 0) ? '' : trm('Has to be larger than 0 and a number')}
    };
    if (exists $validator_mapping->{$attribute}) {
        return &{$validator_mapping->{$attribute}}($value, $interface, $identifier);
    }
    else {
        return "unrecognized attribute name: `$attribute`";
    }
}

=head3 validate_interface($interface)

Simply returns true if the interface is valid

=cut
sub validate_interface ($self, $interface) {
    return $self->wg_meta->is_valid_interface($interface);
}

=head3 get_public_key($private_key)

Takes a private key and returns the derived public key. Throws an exception on command failure

=cut
sub get_public_key ($self, $private_key) {
    return $self->wg_not_installed ? 'dummy_pub_key' : get_pub_key($private_key);
}

=head3 gen_key_pair()

Generates a key pair and returns them embedded in a hash reference

=cut
sub gen_key_pair ($self) {
    my @keypair = $self->wg_not_installed ? ('dummy_priv_key', 'dummy_pub_key') : gen_keypair();
    return { 'private-key' => $keypair[0], 'public-key' => $keypair[1] }
}

=head3 get_peer_count($filter)

Returns the number of peers with respect to the current filter string

=cut
sub get_peer_count ($self, $filter) {
    my $filtered_data = _apply_filter($self->_generate_table_source(), $filter);
    return scalar @{$filtered_data};
}

=head3 update_peer_data($interface, $identifier, $attr, $value)

Updates a specific attribute of a peer identified by its associated interface and public-key.
To allow for batch processing, you have to call L</commit_changes($ref_integrity_hashes)> by your self as soon
as you finished updating attributes.

=cut
sub update_peer_data ($self, $interface, $identifier, $attr, $value) {
    $self->wg_meta->set($interface, $identifier, $attr, $value, 1);
}

=head3 add_peer($interface, $name, $ip_address, $public_key, $alias, $pre_shared_key)

Adds a minimal peer. Similar to L</update_peer_data($interface, $identifier, $attr, $value)> you have to call
L</commit_changes($ref_integrity_hashes)> manually to allow setting additional attributes before writing the changes
to disk.

=cut
sub add_peer ($self, $interface, $ip_address, $public_key, $alias, $pre_shared_key) {
    $self->wg_meta->add_peer($interface, $ip_address, $public_key, $alias, $pre_shared_key);
}

=head3 remove_peer($interface, $identifier, $ref_integrity_hash)

Removes a peer identified by its interface and public-key followed by an automatic commit()

=cut
sub remove_peer ($self, $interface, $identifier, $ref_integrity_hash) {
    $self->wg_meta->remove_peer($interface, $identifier);
    $self->commit_changes($ref_integrity_hash);
}


=head3 commit_changes($ref_integrity_hashes)

Writes current local config to disk. If the property C<is_hot_config> is set to True, followed by
a call to L</apply_config()>

=cut
sub commit_changes ($self, $ref_integrity_hashes) {
    $self->wg_meta->commit($self->is_hot_config, 0, $ref_integrity_hashes);
    # Apply directly when is_hot_config
    $self->apply_config() if $self->is_hot_config;
}

sub sort_table_data ($self, $data, $key, $order) {
    my @keys_to_sort = map {$_->{$key}} @{$data};
    my @sorted_indexes;
    if (defined $order) {
        @sorted_indexes = sort {($keys_to_sort[$b] // '') cmp ($keys_to_sort[$a] // '')} 0 .. $#keys_to_sort;
    }
    else {
        @sorted_indexes = sort {($keys_to_sort[$a] // '') cmp ($keys_to_sort[$b] // '')} 0 .. $#keys_to_sort;
    }
    return [ @{$data}[ @sorted_indexes ] ];
}

sub get_section_data ($self, $interface, $identifier) {
    my %d = $self->wg_meta->get_interface_section($interface, $identifier);
    $d{interface} = $interface;
    $d{integrity_hash} = $self->wg_meta->calculate_sha_from_internal($interface, $identifier);
    return \%d;
}

sub restore_from_section_data ($self, $section_data) {
    for my $key (keys %{$section_data}) {
        unless ($key eq 'interface' || $key eq 'integrity_hash' || $key eq 'order' || $key eq 'type') {
            $self->wg_meta->set($section_data->{interface}, $section_data->{'public-key'}, $key, $section_data->{$key}, 1);
        }
    }
    $self->apply_config();
}
sub get_interface_selection ($self) {
    return [ { title => '', key => '0' }, map {{ title => $_, key => $_ }} $self->wg_meta->get_interface_list() ];
}

sub disable_peer ($self, $interface, $identifier, $integrity_hash) {
    $self->wg_meta->disable($interface, $identifier);
    $self->commit_changes($integrity_hash);
}
sub enable_peer ($self, $interface, $identifier, $integrity_hash) {
    $self->wg_meta->enable($interface, $identifier);
    $self->commit_changes($integrity_hash);
}

=head3 apply_config()

Runs the external I<wireguard apply command>

=cut
sub apply_config ($self) {
    my $apply_command = $self->backend_config->{wg_apply_command};

    for my $interface ($self->wg_meta->get_interface_list()) {
        my $safe_path = $self->{wireguard_home} . $interface . $self->not_applied_suffix;
        my $hot_path = $self->{wireguard_home} . $interface . '.conf';
        if (-e $safe_path && not $self->is_hot_config) {
            move($hot_path, $hot_path . '.old') or die "Could not apply for `$interface`" . $!;
            move($safe_path, $hot_path) or die "Could not apply for `$interface`" . $!;
        }
        $apply_command =~ s/%interface%/$interface/g;
        run_external($apply_command);
    }
}

=head3 discard_changes()

If there is a I<.not_applied> config delete it

=cut
sub discard_changes ($self) {
    for my $interface ($self->wg_meta->get_interface_list()) {
        my $safe_path = $self->{wireguard_home} . $interface . $self->{not_applied_prefix};
        if (-e $safe_path) {
            unlink($safe_path);
        }
    }
}

sub _generate_table_source ($self) {
    $self->wg_show->reload($self->_get_wg_show_data());
    my @table_data;
    for my $interface ($self->wg_meta->get_interface_list()) {
        my $row_data = {};
        for my $identifier ($self->wg_meta->get_section_list($interface)) {
            # skip interfaces
            unless ($identifier eq $interface) {
                # add wireguard data
                my %wg_section_data = $self->wg_meta->get_interface_section($interface, $identifier);
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
                if ($self->wg_show->iface_exists($interface)) {
                    my %show_section_data = $self->wg_show->get_interface_section($interface, $identifier);
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


sub _apply_filter ($ref_data, $filter) {
    if ($filter) {
        my @filtered_data;
        my @filter_terms = map {s/^\s+|\s+$//g;
            $_} split /\s+/, $filter;
        for my $row_hash (@{$ref_data}) {
            my $filter_string = join '', map {lc $row_hash->{$_} if defined $row_hash->{$_}} ('name', 'public-key', 'interface', 'allowed-ips', 'email', 'device');
            for my $filter_term (@filter_terms) {
                if ($filter_string =~ lc $filter_term) {
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

sub get_peer_table_data ($self, $first_row, $last_row, $filter) {
    # unfortunately we have to apply the filter twice since get_n_rows() and get_table_data() are two separate calls
    my @table_data = @{_apply_filter($self->_generate_table_source(), $filter)};
    $last_row = $#table_data if ($last_row > $#table_data);
    return [ @table_data[$first_row .. $last_row] ];
}


1;