package WGwrangler::GuiPlugin::WireguardEditPeerForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
=head1 NAME

WGwrangler::GuiPlugin::WireguardPeerForm - Peer Edit form

=head1 DESCRIPTION

Peer edit form

=cut

has formCfg => sub ($self) {

    return [
        # This does somehow not work $self->{args}{selection}{disabled} is a reference to JSON::PP true
        1 ? {
            widget => 'header',
            label  => trm('<color="red">Warning</color>'),
            note   => trm('This Peer is disabled!'),
            set    => {
                rich => true,
            }
        } : (),
        {
            key    => 'interface',
            label  => trm('Interface'),
            widget => 'text',
            set    => {
                readOnly => true,
                required => true
            }
        },
        {
            key    => 'email',
            label  => trm('Email'),
            widget => 'text',
            set    => {
                readOnly => true,
            }
        },
        {
            key    => 'public-key',
            label  => trm('Public Key'),
            widget => 'text',
            set    => {
                readOnly => true,
                required => true
            }
        },
        {
            key       => 'device',
            label     => trm('Device'),
            widget    => 'text',
            validator => sub ($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('device', $value);
            },
            set       => {
                placeholder => trm('A device name')
            },
        },
        {
            key    => 'integrity_hash',
            label  => trm('Integrity Hash'),
            widget => 'hiddenText',
            set    => {
                readOnly => true,
                required => true,
            }
        },
        {
            key       => 'name',
            label     => trm('Name'),
            widget    => 'text',
            validator => sub ($value, $parameter, $formData) {
                return $self->app->wireguardModel->validator('name', $value);
            },
            set       => {
                required => true,
            },
        },
        {
            key       => 'allowed-ips',
            label     => trm('Allowed-IPs'),
            widget    => 'text',
            validator => sub ($value, $parameter, $formData) {
                if ($formData->{interface} && $formData->{'public-key'} && $formData->{'public-key'}) {
                    return $self->app->wireguardModel->validator('address_override', $value, $formData->{interface}, $formData->{'public-key'});
                }
            },
            set       => {
                required => true
            },
        },
        # {
        #     key       => 'alias',
        #     label     => trm('Alias'),
        #     widget    => 'text',
        #     validator => sub($value, $parameter, $formData) {
        #         if ($formData->{alias} && $formData->{interface} && $formData->{'public-key'}) {
        #             return $self->app->wireguardModel->validator('alias', $value, $formData->{interface}, $formData->{'public-key'});
        #         }
        #         return "";
        #     },
        #     set       => {
        #         placeholder => 'Unlike the name attribute, this must be unique'
        #     }
        # },
        {
            key    => 'description',
            label  => trm('Description'),
            widget => 'textArea',
            set    => {
                placeholder => trm('Some extra infos about this peer'),
            }
        },
    ];
};

has actionCfg => sub ($self) {

    my $handler = sub ($self, $args) {

        my $interface = $args->{interface};
        my $identifier = $args->{'public-key'};
        my $before_change = $self->app->wireguardModel->get_section_data($interface, $identifier);
        eval {
            for my $attr_key (keys %{$args}) {
                unless ($attr_key eq 'interface' || $attr_key eq 'public-key' || $attr_key eq 'integrity_hash') {
                    $self->app->wireguardModel->update_peer_data($interface, $identifier, $attr_key, $args->{$attr_key});

                }
            }
            # Commit changes
            $self->app->wireguardModel->commit_changes({ $identifier => $args->{'integrity_hash'} });

            # Check into VCS if enabled
            if ($self->config->{'no_apply'} && $self->config->{'enable_git'}) {
                my $commit_message = "Edited `$identifier` on device `$interface`";
                my $user_string = $self->user->{userInfo}{cbuser_login};
                $self->app->versionManager->checkin_new_version($commit_message, $user_string, 'dummy@example.com');
            }
        };
        if ($@) {
            my $error_id = int(rand(100000));
            $self->controller->log->error('error_id: ' . $error_id . ' ' . $@);
            $self->app->wireguardModel->restore_from_section_data($before_change);
            die mkerror(9999, trm('Could not edit peer. Error ID: ') . $error_id);
        }

        return {
            action => 'dataSaved'
        };
    };

    return [
        {
            label         => trm('Save Changes'),
            action        => 'submit',
            key           => 'save',
            actionHandler => $handler
        }
    ];
};

sub getAllFieldValues ($self, $args, $form_data, $qx_locale) {
    return $self->app->wireguardModel->get_section_data($args->{selection}{interface}, $args->{selection}{'public-key'});
}

has checkAccess => sub ($self) {
    return $self->user->may('write');
};

1;
__END__

=head1 AUTHOR

S<Tobias Bossert E<lt>bossert _at_ oetiker _this_is_a_dot_ chE<gt>>

=head1 HISTORY

 2021-01-12 tobias 0.0 first version

=cut
