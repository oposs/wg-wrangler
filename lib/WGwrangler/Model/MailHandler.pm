package WGwrangler::Model::MailHandler;
use Email::Sender::Transport::SMTP;
use Mojo::Base 'WGwrangler::Model::Email', -signatures;
use SVG::Barcode::QRCode;
use MIME::Base64 qw(encode_base64);

has mailTransport => sub {
    Email::Sender::Transport::SMTP->new({
        host => 'localhost',
        port => '25'
    });
};


=head3 prepare_and_send($mail_cfg)

Expects the following structure:

    {
        'name'         => Recipients name,
        'endpoint'     => Wireguard Endpoint,
        'email'        => Recipients email,
        'sender_email' => Senders email,
        'device_name'  => Device name,
        'attachment'  => {
            attributes => {
                filename     => filename.txt,
                content_type => "text/plain",
                charset      => "UTF-8",
                disposition  => 'attachment'
                ...
            },
            body       => body of attachment
        }
    }

The body of the attachment is converted into a base 64-encoded qr-code
=cut
sub prepare_and_send ($self, $mail_cfg) {
    my $qrcode = SVG::Barcode::QRCode->new();
    $mail_cfg->{qr} = encode_base64($qrcode->plot($mail_cfg->{attachment}->{body}));
    my $send_cfg = {
        from        => $mail_cfg->{sender_email},
        to          => $mail_cfg->{email},
        template    => 'send_config_by_email.ep',
        args        => $mail_cfg,
        attachments => [ $mail_cfg->{attachment} ]
    };
    $self->sendMail($send_cfg);
}

1;