package WGwrangler::GuiPlugin::CommitMessageForm;
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


has screenOpts => sub {
    my $self = shift;
    my $opts = $self->SUPER::screenOpts;
    return {
        %$opts,
        # and settings accordingly
        container => {
            set => {
                # see https://www.qooxdoo.org/apps/apiviewer/#qx.ui.core.LayoutItem
                # for inspiration in properties to set
                maxWidth  => 400,
                maxHeight => 200,
                alignX    => 'left',
                alignY    => 'top',
                height    => 120
            },
            addProps => {
                edge => 'west',
            }
        }
    }
};

has formCfg => sub($self) {
    return [
        {
            key    => 'header_commit',
            label  => trm('Commit message'),
            widget => 'header'
        },
        {
            key    => 'commit_message',
            label  => trm('Commit Message'),
            widget => 'textArea',
            set    => {
                placeholder => 'Briefly describe your changes',
                required    => true
            }
        },
    ];
};

has actionCfg => sub {
    my $self = shift;

    my $handler = sub {
        my $self = shift;
        my $args = shift;

        my $commit_message = $args->{'commit_message'};
        my $user_string = $self->user->{userInfo}{cbuser_login};
        $self->app->wireguardModel->apply_config();
        eval {
            $self->app->versionManager->checkin_new_version($commit_message, $user_string, 'dummy@example.com');
        };
        if($@){
            my $error_id = int(rand(100000));
            $self->controller->log->error('error_id: ' . $error_id . ' ' . $@);
            die mkerror(9999, "Could not checkin new version. Error ID: $error_id");
        }
        return {
            action => 'dataSaved',
        };
    };

    return [
        {
            label         => trm('Apply Config'),
            action        => 'submit',
            key           => 'apply',
            actionHandler => $handler
        },
    ];
};

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    return [];
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
