package WGwrangler;
use Mojo::Base 'CallBackery';
use CallBackery::Model::ConfigJsonSchema;
use WGwrangler::User;
use WGwrangler::Model::WireguardDataAdapter;
use WGwrangler::Model::MailHandler;
use WGwrangler::Model::VersionManager;

=head1 NAME

WGwrangler - the application class

=head1 SYNOPSIS

 use Mojolicious::Commands;
 Mojolicious::Commands->start_app('WGwrangler');

=head1 DESCRIPTION

Configure the mojolicious engine to run our application logic

=cut

=head1 ATTRIBUTES

WGwrangler has all the attributes of L<CallBackery> plus:

=cut

=head2 config

use our own plugin directory and our own configuration file:

=cut

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

has database => sub {
    my $self = shift;
    my $database = $self->SUPER::database(@_);
    $database->sql->migrations
        ->name('WGwranglerBaseDB')
        ->from_data(__PACKAGE__, 'appdb.sql')
        ->migrate;
    return $database;
};

has 'userObject' => sub {
    WGwrangler::User->new();
};

has 'wireguardModel' => sub {
    my $self = shift;
    my $wireguard_home = $self->config->cfgHash->{BACKEND}{wireguard_home};
    my $not_applied_suffix = $self->config->cfgHash->{BACKEND}{'not_applied_suffix'};
    my $no_apply = $self->config->cfgHash->{BACKEND}{'no_apply'};
    WGwrangler::Model::WireguardDataAdapter->new(wireguard_home => $wireguard_home, is_hot_config => $no_apply, app => $self);
};

has 'versionManager' => sub {
    my $self = shift;
    my $wireguard_home = $self->config->cfgHash->{BACKEND}{wireguard_home};
    my $not_applied_suffix = $self->config->cfgHash->{BACKEND}{'not_applied_suffix'};
    my $git_enabled = $self->config->cfgHash->{BACKEND}{'enable_git'};
    WGwrangler::Model::VersionManager->new($wireguard_home, $not_applied_suffix, $git_enabled);
};

1;

=head1 COPYRIGHT

Copyright (c) 2021 by Tobias Bossert. All rights reserved.

=head1 AUTHOR

S<Tobias Bossert E<lt>tobias.bossert@fastpath.chE<gt>>

=cut

__DATA__

@@ appdb.sql

-- 1 up

CREATE TABLE song (
    song_id    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    song_title TEXT NOT NULL,
    song_voices TEXT,
    song_composer TEXT,
    song_page INTEGER,
    song_note TEXT
);

-- add an extra right for people who can edit

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('write','Editor');

-- 1 down

DROP TABLE song;
