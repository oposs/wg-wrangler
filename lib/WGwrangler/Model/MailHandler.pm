package WGwrangler::Model::MailHandler;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';

sub new($class) {

    my $self = {};
    bless $self, $class;
    return $self;
}


sub send_mail($self, $recipient, $wireguard_config_str) {
    my $res = `echo "$wireguard_config_str" | mail -s "Your wiregurd configuration" tobias`;
    print("Sent mail to {$recipient}");
}

1;