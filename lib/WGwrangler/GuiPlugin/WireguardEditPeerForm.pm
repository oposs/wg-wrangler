package WGwrangler::GuiPlugin::WireguardEditPeerForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use experimental 'signatures';

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


has formCfg => sub($self) {

    return [
        # This does somehow not work $self->{args}{selection}{disabled} is a reference to JSON::PP true
        $self->{args}{selection}{disabled} ? {
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
            }
        },
        {
            key    => 'public-key',
            label  => trm('Public Key'),
            widget => 'text',
            set    => {
                readOnly => true,
            }
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
            key    => 'name',
            label  => trm('Name'),
            widget => 'text',
            validator => sub {
                my $value = shift;
                return $self->app->wireguardModel->validate_name($value);
            },
            set    => {
                required => true,
            },
        },
        {
            key       => 'allowed-ips',
            label     => trm('Allowed-IPs'),
            widget    => 'text',
            validator => sub {
                my $value = shift;
                my $parameter = shift;
                my $formData = shift;
                if ($formData->{interface}) {
                    return $self->app->wireguardModel->validate_ips_for_interface($formData->{interface}, $value);
                }
                return "";
            },
            set       => {
                required => true
            },
        },
        {
            key    => 'alias',
            label  => trm('Alias'),
            widget => 'text',
            validator => sub {
                my $value = shift;
                my $parameter = shift;
                my $formData = shift;
                if ($formData->{alias}) {
                    my $res = $self->app->wireguardModel->validate_alias_for_interface($formData->{interface}, $formData->{'public-key'}, $value);
                    return $self->app->wireguardModel->validate_alias_for_interface($formData->{interface}, $formData->{'public-key'}, $value);
                }
                return "";
            },
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
        my $identifier = $args->{'public-key'};

        for my $attr_key (keys %{$args}) {
            unless ($attr_key eq 'interface' || $attr_key eq 'public-key' || $attr_key eq 'integrity_hash') {
                $self->app->wireguardModel->update_peer_data($interface, $identifier, $attr_key, $args->{$attr_key});
            }
        }
        $self->app->wireguardModel->commit_changes({ $identifier => $args->{'integrity_hash'} });

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

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    return $self->app->wireguardModel->get_section_data($args->{selection}{interface}, $args->{selection}{'public-key'});
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
