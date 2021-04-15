package WGwrangler::Model::MailHandler;
use Email::Sender::Transport::SMTP;
use Mojo::Base 'WGwrangler::Model::Email';
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';
use SVG::Barcode::QRCode;
use MIME::Base64 qw(encode_base64);

has mailTransport => sub {
    Email::Sender::Transport::SMTP->new({
        host          => 'localhost',
        port           => '25'
    });
};

sub prepare_and_send($self, $mail_cfg) {
    my $qrcode = SVG::Barcode::QRCode->new();
    my @attachments = @{$mail_cfg->{attachments}};
    $mail_cfg->{qr} = encode_base64($qrcode->plot($attachments[0]->{body}));
    my $send_cfg = {
        from        => $mail_cfg->{sender_email},
        to          => $mail_cfg->{email},
        template    => 'send_config_by_email',
        args        => $mail_cfg,
        attachments => $mail_cfg->{attachments}
    };
    $self->sendMail($send_cfg);
}

1;