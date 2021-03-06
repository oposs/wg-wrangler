package WGwrangler::GuiPlugin::WireguardShow;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Wireguard::WGmeta::Utils;
use experimental 'signatures';


=head1 NAME

WGwrangler::GuiPlugin::Song - Song Table

=head1 SYNOPSIS

 use WGwrangler::GuiPlugin::Song;

=head1 DESCRIPTION

The Song Table Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut


# has screenOpts => sub {
#     my $self = shift;
#     my $opts = $self->SUPER::screenOpts;
#     return {
#         %$opts,
#         # an alternate layout for this screen
#         layout => {
#             class => 'qx.ui.layout.Dock',
#             set => {},
#         },
#         # and settings accordingly
#         container => {
#             set => {
#                 # see https://www.qooxdoo.org/apps/apiviewer/#qx.ui.core.LayoutItem
#                 # for inspiration in properties to set
#                 # maxWidth => 700,
#                 # maxHeight => 500,
#                 alignX => 'left',
#                 alignY => 'top',
#             },
#             addProps => {
#                 edge => 'west'
#             }
#         }
#     }
# };

has formCfg => sub($self) {

    return [
        {
            widget => 'header',
            label  => trm('*'),
            note   => trm('Nice Start')
        },
        {
            key    => 'wg_interface',
            widget => 'text',
            note   => 'Wireguard interface',
            label  => 'Search',
            set    => {
                placeholder => 'WG interface',
                enabled     => false
            },
        },
    ]
};

=head2 tableCfg


=cut

has tableCfg => sub {
    my $self = shift;
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
            format   => {
                unitPrefix            => 'metric',
                maximumFractionDigits => 2,
                postfix               => 'Byte',
                locale                => 'en'
            },
        },
        {
            label    => trm('Transfer-TX'),
            type     => 'number',
            width    => '1*',
            key      => 'transfer-tx',
            sortable => true,
            format   => {
                unitPrefix            => 'metric',
                maximumFractionDigits => 2,
                postfix               => 'Byte',
                locale                => 'en'
            },
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

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;
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
                    type => 'add'
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
                    type => 'edit'
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
            actionHandler    => sub {
                my $self = shift;
                my $args = shift;
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
            question         => trm('Do you realy want to delete this peer - This cannot be undone!'),
            key              => 'delete',
            buttonSet        => {
                enabled => false,
            },
            actionHandler    => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{'public-key'};
                die mkerror(4992, "You have to select a peer first") if not $id;

                # get most recent section data
                my $interface = $args->{selection}{interface};
                my $identifier = $args->{selection}{'public-key'};
                my $section_data = $self->app->wireguardModel->get_section_data($interface, $identifier);

                $self->app->wireguardModel->remove_peer($interface, $identifier, { $identifier => $section_data->{integrity_hash} });
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
                my $self = shift;
                my $args = shift;
                return {
                    action => 'reload',
                };
            }
        }
    ];
};

sub db {
    shift->user->mojoSqlDb;
};

sub _getFilter {
    my $self = shift;
    my $search = shift;
    my $filter = '';
    # if ($search) {
    #     $filter = "WHERE song_title LIKE " . $self->db->dbh->quote('%' . $search);
    # }
    return $filter;
}

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $filter = $self->_getFilter($args->{formData}{wg_interface});
    return $self->app->wireguardModel->get_peer_count($filter);
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $filter = $self->_getFilter($args->{formData}{wg_interface});
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
