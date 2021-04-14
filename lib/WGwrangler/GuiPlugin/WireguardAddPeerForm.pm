package WGwrangler::GuiPlugin::WireguardAddPeerForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use WGwrangler::Model::MailHandler;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use experimental 'signatures';

use Wireguard::WGmeta::Validator;

=head1 NAME

WGwrangler::GuiPlugin::WireguardPeerForm - Peer Edit form

=head1 DESCRIPTION

Peer edit form

=cut

has 'mailHandler' => sub($self) {
    WGwrangler::Model::MailHandler->new(app => $self->app, log => $self->controller->log);
};

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the Wireguard Show form

=cut


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
        # interface fqdn:port (hidden)
        {
            key    => 'fqdn',
            label  => trm('FQDN'),
            widget => 'hiddenText',
            set    => {
                readOnly => true,
                required => true
            },
        },
        # peer name
        {
            key              => 'name',
            label            => trm('Name'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('name', $value);
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
                return $self->app->wireguardModel->validator('email', $value);
            },
            set              => {
                required    => true,
                placeholder => 'This should identify this peer'
            }
        },
        # Device name
        {
            key              => 'device',
            label            => trm('Device'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('device', $value);
            },
            set              => {
                required    => true,
                placeholder => 'A device name'
            },
        },
        # allowed ips
        {
            key              => 'allowed-ips',
            label            => trm('Allowed IPs'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('single-ip', $value);
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
                    return $self->app->wireguardModel->validator('address_override', $value, $formData->{interface}, $formData->{'public-key'});
                }
                return "" eq $value ? "" : "Please select an interface first";
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
            label            => trm('Client Interface Port'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('listen-port', $value);},
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
            validator        => sub($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('single-ip', $value);
            },
            set              => {
                visibility => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded',
                value      => $self->config->{'default-dns'}
            },
        },
        # # alias (advanced)
        # {
        #     key              => 'alias',
        #     label            => trm('Alias'),
        #     widget           => 'text',
        #     triggerFormReset => true,
        #     validator        => sub($value, $parameter, $formData) {
        #         if ($formData->{alias} && $formData->{interface} && $formData->{'public-key'}) {
        #             return $self->app->wireguardModel->validator('alias', $value, $formData->{interface}, $formData->{'public-key'});
        #         }
        #         return "" eq $value ? "" : "Please select an interface first";
        #     },
        #     set              => {
        #         placeholder => 'Unlike the name attribute, this must be unique',
        #         visibility  => $self->{args}{currentFormData}{show_advanced} ? 'visible' : 'excluded'
        #     }
        # },
        # persistent-keepalive (advanced)
        {
            key              => 'persistent-keepalive',
            label            => trm('Persistent-keepalive'),
            widget           => 'text',
            triggerFormReset => true,
            validator        => sub($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('persistent-keepalive', $value);

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
        my $fqdn = $args->{fqdn};
        my $device = $args->{device};
        my $send_by_email = $args->{'send_by_email'};
        my $config_contents = $args->{config_preview};
        my $vpn_name = $self->app->config->cfgHash->{BACKEND}{vpn_name};
        my $peer_added = undef;

        eval {
            $self->app->wireguardModel->add_peer($interface, $name, $ips, $pub_key, $alias, undef);
            $peer_added = 1;
            $self->app->wireguardModel->update_peer_data($interface, $pub_key, 'description', $desc) if defined($desc);
            $self->app->wireguardModel->update_peer_data($interface, $pub_key, 'email', $email);
            $self->app->wireguardModel->update_peer_data($interface, $pub_key, 'device', $device);

            if (defined $send_by_email && $send_by_email == 1) {
                my $email_cfg = {
                    'name'        => $name,
                    'endpoint'    => $fqdn,
                    'email'       => $email,
                    'device_name' => $device,
                    'attachments' => [ {
                        attributes => {
                            filename     => "$vpn_name.conf",
                            content_type => "text/plain",
                            charset      => "UTF-8",
                        },
                        body       => $config_contents
                    } ]
                };
                $self->mailHandler->prepare_and_send($email_cfg);
            }
            $self->app->wireguardModel->commit_changes({});
        };
        if ($@) {
            my $error_id = int(rand(100000));

            # if the peer is already created, lets delete it
            if (defined $peer_added) {
                delete $self->app->wireguardModel->wg_meta->{parsed_config}{$interface}{$pub_key};
            }
            $self->controller->log->error('error_id: ' . $error_id . ' ' . $@);
            die mkerror(9999, 'Could not create peer. Error ID: ' . $error_id);
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

sub generate_preview_config($self, $interface, $form_values, $client_private_key, $interface_public_key) {
    # for my $key (keys %{$formData}){
    #     if ($formData->{$key} && $self->validateData($key,$formData)){
    #         return 'There is invalid input in your form data';
    #     }
    # }
    my $pfx = '#+';
    my $out = "[Interface]\n"
        . $pfx . "Name = " . ($form_values->{name} ? $form_values->{name} . "\n" : "\n")
        . $pfx . "Email = " . ($form_values->{email} ? $form_values->{email} . "\n" : "\n")
        . $pfx . "Device = " . ($form_values->{device} ? $form_values->{device} . "\n" : "\n")
        . "Address = " . $form_values->{address} . "\n"
        . "PrivateKey = $client_private_key\n"
        . ($form_values->{DNS} ? "DNS = " . $form_values->{DNS} . "\n" : '')
        . ($form_values->{'listen-port'} ? "ListenPort = " . $form_values->{'listen-port'} . "\n" : '')
        . "\n"
        . "[Peer]\n"
        . "PublicKey = $interface_public_key\n"
        . "AllowedIPs = " . $form_values->{'allowed-ips'} . "\n"
        . "Endpoint = $form_values->{fqdn}\n"
        . ($form_values->{'persistent-keepalive' } ? "PersistentKeepalive = " . $form_values->{'persistent-keepalive'} . "\n" : '');

    return $out;
}

sub getAllFieldValues($self, $args, $formData, $locale) {
    my $data = {};
    my $may_interface = $formData->{currentFormData}{interface};

    if ($self->app->wireguardModel->validate_interface($may_interface)) {
        my %interface_data = %{$self->app->wireguardModel->get_section_data($may_interface, $may_interface)};
        $data->{fqdn} = $interface_data{fqdn} . ':' . $interface_data{'listen-port'};
        $formData->{currentFormData}{fqdn} = $data->{fqdn};
        my $interface_public_key = $self->app->wireguardModel->get_public_key($interface_data{'private-key'});
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

        $data->{'config_preview'} = $self->generate_preview_config($may_interface, $formData->{currentFormData}, $private_key, $interface_public_key);
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
