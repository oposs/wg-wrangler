package WGwrangler::GuiPlugin::WireguardVersions;
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
        },
        {
            key    => 'revision',
            widget => 'text',
            note   => 'Terms are case-sensitive',
            label  => 'Search',
            set    => {
                placeholder => 'name, interface, email, ip, public-key',
                enabled     => true
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
            label    => trm('Version'),
            type     => 'string',
            width    => '1*',
            key      => 'hash',
            sortable => true,
        },
        {
            label    => trm('Date'),
            type     => 'dateTime',
            width    => '2*',
            key      => 'date',
            sortable => true,
            format   => {
                'dateFormat' => "dd.mm.yy"
            }
        }
    ];
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;
    return [] if $self->user and not $self->user->may('write');

    return [
        {
            label            => trm('Restore Version'),
            action           => 'submitVerify',
            question         => trm('Do you really want to go back to this revision?'),
            addToContextMenu => true,
            defaultAction    => true,
            key              => 'restore_version',
            buttonSet        => {
                enabled => false,
            },
            actionHandler    => sub {
                my $self = shift;
                my $args = shift;
                my $hash = $args->{selection}{'hash'};
                die mkerror(4992, "You have to select a peer first") if not $hash;

                $self->app->versionManager->go_back_to_revision($hash);

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

        },
    ];
};

sub _getFilter {
    my $self = shift;
    my $search = shift;
    my $filter = $search;
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
    my $filter = $self->_getFilter($args->{formData}{revision});
    my $data = $self->app->versionManager->get_history();
    # add action set to each row
    for my $row (@{$data}) {
        $row->{_actionSet} = {
            restore_version => {
                enabled => true,
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
