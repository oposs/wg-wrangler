=head1 NAME

WGwrangler - Main application class

=head1 SYNOPSIS

 use Mojolicious::Commands;
 Mojolicious::Commands->start_app('WGwrangler');

=head1 DESCRIPTION

Configure the mojolicious engine to run our application logic

=cut

=head1 ATTRIBUTES

WGwrangler has all the attributes of L<CallBackery> plus:

=cut

=head3 config

use our own plugin directory and our own configuration file:

=cut

package WGwrangler;
use Mojo::Base 'CallBackery';
use CallBackery::Model::ConfigJsonSchema;
use WGwrangler::User;
use WGwrangler::Model::WireguardDataAdapter;
use WGwrangler::Model::MailHandler;
use WGwrangler::Model::VersionManager;

our $VERSION = "0.0.0";

has config => sub {
    my $self = shift;
    my $config = CallBackery::Model::ConfigJsonSchema->new(
        app  => $self,
        file => $ENV{WGwrangler_CONFIG} || $self->home->rel_file('etc/wgwrangler.yaml')
    );

    my $be = $config->schema->{properties}{BACKEND};
    $be->{properties} = {
        %{$be->{properties}},
        vpn_name           => { type => 'string' },
        enable_git         => { type => 'boolean' },
        not_applied_suffix => { type => 'string' },
        wireguard_home     => { type => 'string' },
        no_apply           => { type => 'boolean' },
        wg_apply_command   => { type => 'string' },
        wg_show_command    => { type => 'string' }
    };

    push @{$config->schema->{properties}{BACKEND}{required}}, 'wireguard_home';

    unshift @{$config->pluginPath}, 'WGwrangler::GuiPlugin';
    return $config;
};

=head3 database

Database instance (currently only for user management)

=cut
has database => sub {
    my $self = shift;
    my $database = $self->SUPER::database(@_);
    $database->sql->migrations
        ->name('WGwranglerBaseDB')
        ->from_data(__PACKAGE__, 'appdb.sql')
        ->migrate;
    return $database;
};

# has 'userObject' => sub {
#     WGwrangler::User->new();
# };


=head3 bgc

Shortcut to $self->config->cfgHash->{BACKEND}.

=cut

has 'bgc' => sub {
    my $self = shift;
    $self->config->cfgHash->{BACKEND};
};


=head3 wireguardModel

An instance of L<WGwrangler::Model::WireguardDataAdapter>

=cut
has 'wireguardModel' => sub {
    my $self = shift;
    WGwrangler::Model::WireguardDataAdapter->new(
        wireguard_home     => $self->bgc->{wireguard_home},
        is_hot_config      => $self->bgc->{no_apply},
        app                => $self,
        not_applied_suffix => $self->bgc->{not_applied_suffix}
    );
};

=head3 versionManager

An instance of L<WGwrangler::Model::VersionManager>

=cut
has 'versionManager' => sub {
    my $self = shift;
    WGwrangler::Model::VersionManager->new(
        $self->bgc->{wireguard_home},
        $self->bgc->{not_applied_suffix},
        $self->bgc->{enable_git});
};

1;

=head1 COPYRIGHT

Copyright (c) 2021 by Tobias Bossert. All rights reserved.

=head1 AUTHOR

S<Tobias Bossert E<lt>bossert _at_ oetiker _this_is_a_dot_ chE<gt>>

=cut

__DATA__

@@ appdb.sql

-- 1 up

-- add an extra right for people who can edit

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('write','Editor');

-- 1 down

DROP TABLE song;
