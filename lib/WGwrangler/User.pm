package WGwrangler::User;
use strict;
use warnings FATAL => 'all';

use Mojo::Base 'CallBackery::User';

sub login {
    my $self = shift;
    my $login = shift;
    my $password = shift;
    my $cfg = $self->app->config->cfgHash;
    my $remoteAddress = eval { $self->controller->tx->remote_address } // 'UNKNOWN_IP';
    my $db = $self->app->database;
    my $userData = $db->fetchRow('cbuser',{login=>'tobi'});
    $self->userId($userData->{cbuser_id});
        $self->log->info("Login bypassed for user 'tobi'");
    return 1;
}

1;