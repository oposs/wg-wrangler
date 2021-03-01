package WGwrangler::GuiPlugin::WireguardAddPeerForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
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
        {
            key              => 'interface',
            label            => trm('Interface'),
            widget           => 'selectBox',
            triggerFormReset => true,
            # interestingly the required property is not enough here...
            validator        => sub {
                my $value = shift;
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
        {
            key               => 'interface_info',
            label             => trm('Interface Info'),
            widget            => 'textArea',
            reloadOnFormReset => true,
            set               => {
                readOnly => true,
                height   => 115,
            }
        },
        {
            key    => 'public-key',
            label  => trm('Peer Public Key'),
            widget => 'text',
            set    => {
                required => true,
                readOnly => true
            },
        },
        {
            key    => 'private-key',
            label  => trm('Peer Private Key'),
            widget => 'text',
            set    => {
                required => true,
                readOnly => true
            },
        },
        {
            key    => 'name',
            label  => trm('Name'),
            widget => 'text',
            set    => {
                required    => true,
                placeholder => 'A name to identfiy this peer (by humans)'
            },
        },
        {
            key    => 'allowed-ips',
            label  => trm('Allowed-IPs'),
            widget => 'text',
            # validator => sub {
            #     my $value = shift;
            #     unless (looks_like_ip_in_cidr($value)){
            #         return "Your input does not look like an ip address";
            #     }
            #     return "";
            # },
            set    => {
                required    => true,
                placeholder => 'List of ip addresses, seperarated by comma and in CDIR notation'
            },
        },
        {
            key    => 'alias',
            label  => trm('Alias'),
            widget => 'text',
            set    => {
                placeholder => 'Unlike the name attribute, this must be unique'
            }
        },
        {
            key    => 'description',
            label  => trm('Description'),
            widget => 'textArea',
            set    => {
                placeholder => 'Some extra infos about this peer',
            }
        },
    ];
};

has actionCfg => sub {
    my $self = shift;

    my $handler = sub {
        my $self = shift;
        my $args = shift;

        my $interface = $args->{interface};
        my $pub_key = $args->{'public-key'};
        my $name = $args->{'name'};
        my $desc = $args->{'description'};
        my $ips = $args->{'allowed-ips'};
        my $alias = $args->{'alias'};
        $self->app->wireguardModel->add_peer($interface, $name, $ips, $pub_key, $alias, undef);
        $self->app->wireguardModel->update_peer_data($interface, $pub_key, 'description', $desc);
        $self->app->wireguardModel->commit_changes({});

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
    my $iface_public_key = $self->app->wireguardModel->get_public_key($interface_data{'private-key'});
    my $suggested_ips = $self->app->wireguardModel->suggest_ip($interface, 5);
    my $label = "Interface: $interface \n"
        . "Public-Key: $iface_public_key\n"
        . "Address: $interface_data{'address'}\n"
        . "FQDN: $interface_data{fqdn}:$interface_data{'listen-port'}\n"
        . "Suggested-IPs: $suggested_ips";
    return $label;
}

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    my $formData = shift;

    my $data = $self->app->wireguardModel->gen_key_pair();

    if ($formData->{currentFormData}{interface}) {
        $data->{'interface_info'} = $self->generate_interface_label($formData->{currentFormData}{interface});
    }
    else {
        $data->{'interface_info'} = 'Select an interface first';
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
