package WGwrangler::GuiPlugin::WireguardShow;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Wireguard::WGmeta::Utils;

=head1 NAME

WGwrangler::GuiPlugin::WireguardShow - Shows contents of WG configs

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub ($self) {

    return [
        {
            widget => 'header',
            label  => trm('*'),
        },
        {
            key    => 'wg_interface',
            widget => 'text',
            note   => 'Terms are case-insensitive',
            label  => 'Search',
            set    => {
                placeholder => 'name, interface, email, ip, public-key, device',
                enabled     => true
            },
        },
    ]
};

has tableCfg => sub ($self) {
    return [
        {
            label    => trm('Disabled'),
            type     => 'boolean',
            width    => '1*',
            key      => 'disabled',
            sortable => true,
        },
        {
            label    => trm('Interface'),
            type     => 'string',
            width    => '2*',
            key      => 'interface',
            sortable => true,
        },
        {
            label    => trm('Public Key'),
            type     => 'string',
            width    => '6*',
            key      => 'public-key',
            sortable => true,
            primary  => true
        },
        {
            label    => trm('Name'),
            type     => 'string',
            width    => '1*',
            key      => 'name',
            sortable => true,
        },
        {
            label    => trm('Email'),
            type     => 'string',
            width    => '2*',
            key      => 'email',
            sortable => true,
        },
        {
            label    => trm('Device'),
            type     => 'string',
            width    => '2*',
            key      => 'device',
            sortable => true,
        },
        {
            label    => trm('Allowed-IPs'),
            type     => 'string',
            width    => '3*',
            key      => 'allowed-ips',
            sortable => true,
        },
        {
            label    => trm('Transfer-RX'),
            type     => 'number',
            width    => '2*',
            key      => 'transfer-rx',
            sortable => true,
            # format   => {
            #     unitPrefix            => 'metric',
            #     maximumFractionDigits => 2,
            #     postfix               => 'Byte',
            #     locale                => 'en'
            # },
        },
        {
            label    => trm('Transfer-TX'),
            type     => 'number',
            width    => '1*',
            key      => 'transfer-tx',
            sortable => true,
            # format   => {
            #     unitPrefix            => 'metric',
            #     maximumFractionDigits => 2,
            #     postfix               => 'Byte',
            #     locale                => 'en'
            # },
        },
        #        {
        #            label => trm('Size'),
        #            type => 'number',
        #            format => {
        #                unitPrefix => 'metric',
        #                maximumFractionDigits => 2,
        #                postfix => 'Byte',
        #                locale => 'en'
        #            },
        #            width => '1*',
        #            key => 'song_size',
        #            sortable => true,
        #        },
        {
            label    => trm('Endpoint'),
            type     => 'string',
            width    => '3*',
            key      => 'endpoint',
            sortable => true,
        },
    ]
};

has actionCfg => sub ($self) {
    my $bg_config = $self->app->config->cfgHash->{BACKEND};
    return [] if $self->user and not $self->user->may('write');

    return [
        {
            label            => trm('Add Peer'),
            action           => 'popup',
            addToContextMenu => false,
            name             => 'wireguardGui',
            key              => 'add',
            popupTitle       => trm('New Wireguard Peer'),
            set              => {
                minHeight => 600,
                minWidth  => 500
            },
            backend          => {
                plugin => 'WireguardAddPeerForm',
                config => {
                    'default-allowed-ips' => $self->config->{'default-allowed-ips'},
                    'default-dns'         => $self->config->{'default-dns'},
                    'sender-email'        => $self->config->{'sender-email'},
                    'vpn_name'            => $bg_config->{vpn_name},
                    'no_apply'            => $bg_config->{no_apply},
                    'enable_git'          => $bg_config->{enable_git}
                }
            }
        },
        {
            action => 'separator'
        },
        {
            label            => trm('Edit Peer'),
            action           => 'popup',
            addToContextMenu => true,
            defaultAction    => true,
            key              => 'edit',
            name             => 'wireguardGui1',
            buttonSet        => {
                enabled => false,
            },
            popupTitle       => trm('Edit Peer'),
            backend          => {
                plugin => 'WireguardEditPeerForm',
                config => {
                    'no_apply'   => $bg_config->{no_apply},
                    'enable_git' => $bg_config->{enable_git}
                }
            }
        },
        {
            label            => trm('Enable/Disable'),
            action           => 'submit',
            addToContextMenu => true,
            key              => 'toggle',
            buttonSet        => {
                enabled => false,
            },
            actionHandler    => sub ($self, $args) {
                my $id = $args->{selection}{'public-key'};
                die mkerror(4992, "You have to select a peer first") if not $id;

                # get most recent section data
                my $interface = $args->{selection}{interface};
                my $identifier = $args->{selection}{'public-key'};
                my $section_data = $self->app->wireguardModel->get_section_data($interface, $identifier);
                if ($section_data->{'disabled'}) {
                    $self->app->wireguardModel->enable_peer($interface, $identifier, { $identifier => $section_data->{integrity_hash} });
                }
                else {
                    $self->app->wireguardModel->disable_peer($interface, $identifier, { $identifier => $section_data->{integrity_hash} });
                }
                return {
                    action => 'reload',
                };
            }
        },
        {
            label            => trm('Delete Peer'),
            action           => 'submitVerify',
            addToContextMenu => true,
            question         => trm('Do you really want to delete this peer - This cannot be undone!'),
            key              => 'delete',
            buttonSet        => {
                enabled => false,
            },
            actionHandler    => sub ($self, $args,) {
                my $id = $args->{selection}{'public-key'};
                die mkerror(4992, trm('You have to select a peer first')) if not $id;

                # get most recent section data
                my $interface = $args->{selection}{interface};
                my $identifier = $args->{selection}{'public-key'};
                my $section_data = $self->app->wireguardModel->get_section_data($interface, $identifier);
                eval {
                    $self->app->wireguardModel->remove_peer($interface, $identifier, { $identifier => $section_data->{integrity_hash} });

                    # Check into VCS if enabled
                    if ($bg_config->{'no_apply'} && $bg_config->{'enable_git'}) {
                        my $commit_message = "Deleted `$identifier` on device `$interface`";
                        my $user_string = $self->user->{userInfo}{cbuser_login};
                        $self->app->versionManager->checkin_new_version($commit_message, $user_string, 'dummy@example.com');
                    }
                };
                if ($@) {
                    my $error_id = int(rand(100000));
                    $self->controller->log->error('error_id: ' . $error_id . ' ' . $@);
                    # ToDo: Restore peer
                    die mkerror(9999, trm('Something went wrong while trying to delete this peer. Error ID: ') . $error_id);
                }
                return {
                    action => 'reload',
                };

            }
        },
        {
            label            => trm('Reload Data'),
            action           => 'submit',
            addToContextMenu => true,
            key              => 'reload',
            buttonSet        => {
                enabled => true,
            },
            actionHandler    => sub {
                return {
                    action => 'reload',
                };
            }
        },

        {
            action => 'separator'
        },
        !$bg_config->{no_apply} ? {
            label            => trm('Apply configuration'),
            action           => 'popup',
            addToContextMenu => false,
            name             => 'apply_confirm',
            key              => 'apply',
            popupTitle       => trm('Apply configuration'),
            set              => {
                Height => 250,
                Width  => 500
            },
            backend          => {
                plugin => 'CommitMessageForm',
            }
        } : (),
        !$bg_config->{'no_apply'} ? {
            label            => trm('Discard Changes'),
            action           => 'submitVerify',
            question         => trm('Do you really want to discard all changes?'),
            addToContextMenu => true,
            key              => 'discard',
            buttonSet        => {
                enabled => true,
            },
            actionHandler    => sub ($self, $args) {
                $self->app->wireguardModel->discard_changes();
                return {
                    action => 'reload',
                };
            }
        } : (),
        {
            action => 'separator'
        },
    ];
};

has grammar => sub ($self) {
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _doc                  => "Wireguard plugin config",
            _vars                 => [ qw(default-dns default-allowed-ips sender-email) ],
            'default-dns'         => {
                _doc => 'Default DNS server to be filled in the DNS field',
            },
            'default-allowed-ips' => {
                _doc => 'Default allowed-ips for new peers'
            },
            'sender-email'        => {
                _doc  => 'Value to set in the From: email header',
                _type => 'string'
            }
        },
    );
};

sub getTableRowCount ($self, $args, $qx_locale) {
    my $filter = $args->{formData}{wg_interface};
    return scalar $self->app->wireguardModel->get_peer_count($filter);
}

sub getTableData ($self, $args, $qx_locale) {
    my $filter = $args->{formData}{wg_interface};
    my $data = $self->app->wireguardModel->get_peer_table_data($args->{firstRow}, $args->{lastRow}, $filter);
    if ($args->{sortColumn}) {
        $data = $self->app->wireguardModel->sort_table_data($data, $args->{sortColumn}, $args->{sortDesc});
    }
    # add action set to each row
    for my $row (@{$data}) {
        $row->{_actionSet} = {
            edit   => {
                enabled => true,
            },
            delete => {
                enabled => true,
            },
            toggle => {
                enabled => true,
                label   => ($row->{'disabled'}) ? trm('Enable Peer') : trm('Disable Peer')

            }
        }
    }
    return $data;
}

1;
__END__

=head1 COPYRIGHT

Copyright (c) 2021 by Tobias Bossert. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2021-01-12 tobias 0.0 first version

=cut
