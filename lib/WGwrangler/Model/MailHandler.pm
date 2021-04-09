package WGwrangler::Model::MailHandler;
use Mojo::Base 'HinAgwCommon::Email';
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';
use SVG::Barcode::QRCode;
use MIME::Base64 qw(encode_base64);

has mailTransport => sub {
    Email::Sender::Transport::SMTP->new({
        host => 'localhost',
        port => 25,
    });
};

sub prepare_and_send($self, $mail_cfg) {
    my $qrcode = SVG::Barcode::QRCode->new();
    $mail_cfg->{qr} = encode_base64($qrcode->plot($mail_cfg->{config_contents}));
    my $send_cfg = {
        from     => 'rt@oetiker.ch',
        to       => $mail_cfg->{email},
        template => 'send_config_by_email',
        args     => $mail_cfg
    };
    $self->sendMail($send_cfg);
}

1;