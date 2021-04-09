package HinAgwCommon::Email;
=head1 NAME
HinAgwCommon::Email - sending emails
=head1 SYNOPSIS
=cut

use Mojo::Base -base, -signatures;
use Mojo::Template;
use Mojo::Util qw(dumper);

use Email::MIME;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Email::Sender::Transport::Test;

use CallBackery::Exception qw(mkerror);
use CallBackery::Translate qw(trm);

has app => sub {
    die "app property must be set";
};

has log => sub($self) {
    $self->app->log;
};

has mailTransport => sub($self) {
    $self->app->mailTransport
};

has template => sub($self) {
    Mojo::Template->new(
        vars => 1,
    );
};

sub getText($self, $template, $args) {
    my $tmpl = $self->template->render_file(
        $self->app->home->child('templates', "$template.ep"), $args
    );
    die "Error processing $template: " . $tmpl->message . "\n"
        if ref $tmpl eq 'Mojo::Exception';
    my ($head, $text, $html) = split /\n-{4}\s*\n/, $tmpl, 3;
    die "Template ${template}.ep does not contain 3 sections as expected."
        if not $html;
    my %headers;
    while ($head =~ m/(\S+):\s+(.+(:?\n\s.+)*)/g) {
        $headers{$1} = $2;
        $headers{$1} =~ s/\n\s+/ /g;
    }
    return {
        head => \%headers,
        text => $text . "\n",
        html => $html,
    };
}

=head2 sendMail($cfg)
    from     => x,
    to       => y,
    bcc      => q,
    template => z,
    args     => { ... }
=cut

sub sendMail($self, $cfg) {
    my $in = $self->getText($cfg->{template}, $cfg->{args});
    eval {
        my $msg = Email::MIME->create(
            header_str => [
                %{$in->{head}},
                From => $cfg->{from},
                To   => $cfg->{to},
            ],
            attributes => {
                content_type => "multipart/mixed",
            },
            parts      => [
                Email::MIME->create(
                    attributes => {
                        content_type => "text/plain",
                        disposition  => "inline",
                        encoding     => "quoted-printable",
                        charset      => "UTF-8",
                    },
                    body_str   => $in->{text},
                ),
                Email::MIME->create(
                    attributes => {
                        content_type => "text/html",
                        disposition  => "inline",
                        encoding     => "quoted-printable",
                        charset      => "UTF-8",
                    },
                    body_str   => $in->{html},
                ),
                Email::MIME->create(
                    attributes => {
                        filename     => "wireguard.conf",
                        content_type => "text/plain",
                        disposition  => "attachment",
                        encoding     => "quoted-printable",
                        charset      => "UTF-8",
                    },
                    body_str   => $cfg->{args}{config_contents}
                ),
            ]
        );
        my $to = [ $cfg->{to},
            ($cfg->{bcc} ? $cfg->{bcc} : ()) ];
        if ($ENV{HIN_SEND_MAIL_TO}) {
            $to = [ $ENV{HIN_SEND_MAIL_TO} ];
        }
        Email::Sender::Simple->send($msg, {
            transport => $self->mailTransport,
            to        => $to,
            from      => $cfg->{from}
        });
        if ($ENV{HIN_SEND_MAIL_TO}) {
            $self->log->debug("Mail sent from $cfg->{from} to $ENV{HIN_SEND_MAIL_TO} because of HIN_SEND_MAIL_TO override");
        }
        else {
            $self->log->debug("Mail sent from $cfg->{from} to $cfg->{to} ($in->{head}{Subject})");
            $self->log->debug("BCC Mail sent from $cfg->{from} to $cfg->{bcc} ($in->{head}{Subject})")
                if $cfg->{bcc};
        }
    };
    if ($@) {
        $self->log->warn($@);
        die mkerror(7474, trm("Failed to send mail to %1", $cfg->{to}));
    }
}

1;

=head1 COPYRIGHT
Copyright (c) 2020 by Oetiker+Partner AG. All rights reserved.
=head1 AUTHOR
S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>
S<Fritz Zaucker E<lt>fritz.zaucker@oetiker.chE<gt>>
=cut