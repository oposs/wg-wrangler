package WGwrangler::GuiPlugin::WireguardAddPeerForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use experimental 'signatures';
use Scalar::Util qw(looks_like_number);

use Wireguard::WGmeta::Validator;

=head1 NAME

WGwrangler::GuiPlugin::WireguardPeerForm - Peer Edit form

=head1 DESCRIPTION

Peer edit form

=cut

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the Song Entry Form.

=cut


has screenOpts => sub {
    my $self = shift;
    my $opts = $self->SUPER::screenOpts;
    return {
        %$opts,
        # an alternate layout for this screen
        # and settings accordingly
        container => {
            set      => {
                # see https://www.qooxdoo.org/apps/apiviewer/#qx.ui.core.LayoutItem
                # for inspiration in properties to set
                # maxWidth => 700,
                # maxHeight => 500,
                alignX => 'left',
                alignY => 'top',
            },
            addProps => {
                edge => 'west'
            }
        }
    }
};

has formCfg => sub($self) {
    return [
        # interface selection
        {
            key              => 'interface',
            label            => trm('Interface'),
            widget           => 'selectBox',
            triggerFormReset => true,
            # interestingly the required property is not enough here...
            validator        => sub($value, $parameter, $formData) {
                unless ($value) {
                    return "No interface selected";
                }
                else {
                    return "";
                }
            },
            set              => {
                required => true
            },
            cfg              => {
                structure => $self->app->wireguardModel->get_interface_selection()
            }
        },
        # config preview
        {
            key               => 'config_preview',
            label             => trm('Config Preview'),
            widget            => 'textArea',
            reloadOnFormReset => true,
            set               => {
                readOnly => true,
                height   => 200,
            }
        },
        # public key (hidden)
        {
            key    => 'public-key',
            label  => trm('Peer Public Key'),
            widget => 'hiddenText',
            set    => {
                required => true,
                readOnly => true
            },
        },
        # private key (hidden)
        {
            key    => 'private-key',
            label  => trm('Peer Private Key'),
            widget => 'hiddenText',
            set    => {
                required => true,
                readOnly => true
            },
        },
        # peer name
        {
            key              => 'name',
            label            => trm('Name'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub {
                my $value = shift;
                return $self->app->wireguardModel->validate_name($value);
            },
            set              => {
                required    => true,
                placeholder => 'A name to identify this peer (by humans)'
            },
        },
        # User email
        {
            key              => 'email',
            label            => trm('User email'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                $value =~ /^\S+@\S+\.\S+$/ ? return '' : return 'Does not look like an email address';
            },
            set              => {
                required    => true,
                placeholder => 'This should identify this peer'
            }
        },
        # allowed ips
        {
            key              => 'allowed-ips',
            label            => trm('Allowed IPs'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub {
                my $value = shift;
                return $self->app->wireguardModel->looks_like_ip($value);
            },
            set              => {
                required => true,
                value    => $self->config->{'default-allowed-ips'}
            },
        },
        # peer Address override
        {
            key              => 'address_override',
            label            => trm('Address Override'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                if ($formData->{interface} && $formData->{'public-key'}) {
                    return $self->app->wireguardModel->validate_ips_for_interface($formData->{interface}, $formData->{'public-key'}, $value);
                }
                return "";
            },
            set              => {
                required    => false,
                placeholder => 'List of ip addresses, separated by comma and in CDIR notation'
            },
        },
        # actual address (read-only)
        {
            key    => 'address',
            label  => trm('Actual Address'),
            widget => 'hiddenText',
            set    => {
                required => true,
                readOnly => true
            },
        },
        # advanced options
        {
            key              => 'show_advanced',
            label            => trm('Advanced Options'),
            widget           => 'checkBox',
            triggerFormReset => true,
        },
        # Header
        {
            key    => 'header_client',
            widget => 'header',
            label  => trm('Client specific configuration'),
            set    => {
                visibility => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded',
            }
        },
        # interface listen port (advanced)
        {
            key              => 'listen-port',
            label            => trm('Interface Port'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                (looks_like_number($value) && $value > 1024 && $value <= 65535) ? return '' : return 'Has to be in range 1025-65535 and a number';
            },
            set              => {
                visibility  => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded',
                placeholder => 'The listen port on the peer'
            }

        },
        # DNS (advanced)
        {
            key              => 'DNS',
            label            => trm('DNS'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub {
                my $value = shift;
                return $self->app->wireguardModel->looks_like_ip($value);
            },
            set              => {
                visibility => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded',
                value      => $self->config->{'default-dns'}
            },
        },
        # alias (advanced)
        {
            key              => 'alias',
            label            => trm('Alias'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                if ($formData->{alias}) {
                    return $self->app->wireguardModel->validate_alias_for_interface($formData->{interface}, $formData->{'public-key'}, $value);
                }
                return "";
            },
            set              => {
                placeholder => 'Unlike the name attribute, this must be unique',
                visibility  => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded'
            }
        },
        # persistent-keepalive (advanced)
        {
            key              => 'persistent-keepalive',
            label            => trm('Persistent-keepalive'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                (looks_like_number($value) && $value > 0) ? return '' : return 'Has to be larger than 0 and a number';
            },
            set              => {
                visibility  => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded',
                placeholder => 'Send keep-alive pings every N seconds'
            }
        },
        # description (advanced)
        {
            key    => 'description',
            label  => trm('Description'),
            widget => 'textArea',
            set    => {
                placeholder => 'Some extra infos about this peer (Not visible in config preview)',
                visibility  => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded'
            }
        },
        # Send by email
        {
            key    => 'send_by_email',
            label  => => trm('Send by Email'),
            widget => 'checkBox'
        },
    ];
};

has actionCfg => sub($self) {

    my $handler = sub($self, $args) {
        my $interface = $args->{interface};
        my $pub_key = $args->{'public-key'};
        my $name = $args->{'name'};
        my $email = $args->{email};
        my $desc = $args->{'description'};
        my $ips = $args->{'address'};
        my $alias = $args->{'alias'};
        my $send_by_email = $args->{'send_by_email'};
        my $config_contents = $args->{config_preview};

        eval {
            $self->app->wireguardModel->add_peer($interface, $name, $ips, $pub_key, $alias, undef);
            $self->app->wireguardModel->update_peer_data($interface, $pub_key, 'description', $desc) if defined($desc);
            $self->app->wireguardModel->update_peer_data($interface, $pub_key, 'email', $email);
            $self->app->wireguardModel->commit_changes({});
        };
        # ToDo: Make pretty
        die mkerror(9999, $@) if $@;

        if (defined $send_by_email) {
            $self->app->mailHandler->send_mail($email, $config_contents);
        }
        return {
            action => 'dataSaved'
        };
    };

    return [
        {
            label         => trm('Add Peer'),
            action        => 'submit',
            key           => 'save',
            actionHandler => $handler
        }
    ];
};

has grammar => sub {
    my $self = shift;
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _doc  => "Tree Node Configuration",
            _vars => [ qw(type) ],
            type  => {
                _doc => 'type of form to show: edit, add',
                _re  => '(edit|add)'
            },
        },
    );
};

sub generate_interface_label($self, $interface) {
    my %interface_data = %{$self->app->wireguardModel->get_section_data($interface, $interface)};
    if (%interface_data) {
        my $iface_public_key = $self->app->wireguardModel->get_public_key($interface_data{'private-key'});
        my $label = "Interface: $interface \n"
            . "Public-Key: $iface_public_key\n"
            . "Address: $interface_data{'address'}\n"
            . "FQDN: $interface_data{fqdn}:$interface_data{'listen-port'}\n";
        return $label;
    }
    else {
        return "";
    }

}

sub generate_preview_config($self, $interface, $formData, $private_key) {
    # for my $key (keys %{$formData}){
    #     if ($formData->{$key} && $self->validateData($key,$formData)){
    #         return 'There is invalid input in your form data';
    #     }
    # }
    my %interface_data = %{$self->app->wireguardModel->get_section_data($interface, $interface)};
    if (%interface_data) {
        my $iface_public_key = $self->app->wireguardModel->get_public_key($interface_data{'private-key'});
        my $out = "[Interface]\n"
            . "#+Name = " . ($formData->{currentFormData}{name} ? $formData->{currentFormData}{name} . "\n" : "\n")
            . "#+Email = " . ($formData->{currentFormData}{email} ? $formData->{currentFormData}{email} . "\n" : "\n")
            . "Address = " . $formData->{currentFormData}{address} . "\n"
            . "PrivateKey = $private_key\n"
            . ($formData->{currentFormData}{DNS} ? "DNS = " . $formData->{currentFormData}{DNS} . "\n" : '')
            . ($formData->{currentFormData}{'listen-port'} ? "ListenPort = " . $formData->{currentFormData}{'listen-port'} . "\n" : '')
            . "\n"
            . "[Peer]\n"
            . "PublicKey = $iface_public_key\n"
            . "AllowedIPs = " . $formData->{currentFormData}{'allowed-ips'} . "\n"
            . "Endpoint = $interface_data{fqdn}:$interface_data{'listen-port'}\n"
            . ($formData->{currentFormData}{'persistent-keepalive'} ? "PersistentKeepalive = " . $formData->{currentFormData}{'persistent-keepalive'} . "\n" : '');
        return $out;
    }

}

sub getAllFieldValues($self, $args, $formData, $locale) {

    my $data = {};
    my $may_interface = $formData->{currentFormData}{interface};

    if ($self->app->wireguardModel->validate_interface($may_interface)) {
        # check if an address override is present, otherwise suggest some
        if ($formData->{currentFormData}{address_override}) {
            $data->{'address'} = $formData->{currentFormData}{address_override};
            $formData->{currentFormData}{address} = $formData->{currentFormData}{address_override};
        }
        else {
            my $suggested_ips = $self->app->wireguardModel->suggest_ip($may_interface);
            $data->{'address'} = $suggested_ips;
            $formData->{currentFormData}{address} = $suggested_ips;

        }
        # generate key-pair unless we already have one
        my $private_key = "";
        unless ($formData->{currentFormData}{'private-key'}) {
            my $key_pair = $self->app->wireguardModel->gen_key_pair();
            $private_key = $key_pair->{'private-key'};
            $data->{'private-key'} = $key_pair->{'private-key'};
            $data->{'public-key'} = $key_pair->{'public-key'};
        }
        else {
            $private_key = $formData->{currentFormData}{'private-key'};
        }

        $data->{'config_preview'} = $self->generate_preview_config($may_interface, $formData, $private_key);
    }
    else {
        $data->{'config_preview'} = 'Select an interface first';
    }

    return $data;
}

has checkAccess => sub {
    my $self = shift;
    return $self->user->may('write');
};

1;
__END__

=head1 AUTHOR

S<Tobias Bossert E<lt>tobias.bossert@fastpath.chE<gt>>

=head1 HISTORY

 2021-01-12 tobias 0.0 first version

=cut
