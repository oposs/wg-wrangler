package WGwrangler::GuiPlugin::WireguardVersions;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Wireguard::WGmeta::Utils;


=head1 NAME

WGwrangler::GuiPlugin::WireguardVersions - Lists config versions

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

has formCfg => sub ($self) {

    return [
        {
            widget => 'header',
            label  => trm('*'),
        },
        {
            key    => 'version_filter',
            widget => 'text',
            note   => 'Terms are case-sensitive',
            label  => 'Search',
            set    => {
                placeholder => 'name, interface, email, ip, public-key',
                enabled     => false
            },
        },
    ]
};

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label    => trm('Version'),
            type     => 'string',
            width    => '1*',
            key      => 'hash',
            sortable => false,
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
        },
        {
            label    => trm('User'),
            type     => 'string',
            width    => '2*',
            key      => 'user',
            sortable => true,
        },
        {
            label    => trm('Comment'),
            type     => 'text',
            width    => '2*',
            key      => 'message',
            sortable => false,
        }
    ];
};

has actionCfg => sub ($self) {
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
            actionHandler    => sub ($self, $args) {
                my $hash = $args->{selection}{'hash'};
                die mkerror(4992, "You have to select an entry first") if not $hash;

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
                return {
                    action => 'reload',
                };
            }

        },
    ];
};

sub getTableRowCount ($self, $args, $qx_locale) {
    return $self->app->versionManager->get_n_entries($args->{formData}{version_filter});
}

sub getTableData ($self, $args, $qx_locale) {
    my ($data, $count) = $self->app->versionManager->get_history($args->{formData}{version_filter});
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
