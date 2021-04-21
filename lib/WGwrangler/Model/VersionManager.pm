=head1 NAME

WGwrangler::Model::VersionManager - Manages different config versions

=head1 DESCRIPTION

Manages configuration version either by maintaining a git repository or by relieving on I<.old> files

=head1 METHODS

=cut

package WGwrangler::Model::VersionManager;
use Mojo::Base -base, -signatures;
use File::Copy qw(move copy);
use Wireguard::WGmeta::Wrapper::Bridge;
use Wireguard::WGmeta::Utils;

use constant FALSE => 0;
use constant TRUE => 1;


=head3 versions_dir

Usually set to /etc/wireguard

=cut
has 'versions_dir' => sub ($self) {
    die 'Must not be empty';
};

=head3 git_support

Should we use git as versioning system. Default:No (-> Fallback to simple I<.old> files)

=cut
has 'git_support' => sub ($self) {
    FALSE;
};

=head3 not_applied_suffix

customize not applied suffix

=cut
has 'not_applied_suffix' => sub ($self) {
    return '.not_applied'
};
sub new {
    my $self = shift->SUPER::new(@_);
    # init git
    if ($self->git_support) {
        if (-e $self->versions_dir) {
            run_external("git init " . $self->versions_dir);
            unless (-e $self->versions_dir . '.gitignore') {
                run_external("echo '*." . $self->not_applied_suffix . "' > " . $self->versions_dir . ".gitignore");
            }

        }
        else {
            die "`." . $self->versions_dir . "` does not exist";
        }
    }
    return $self;
}

=head3 get_history($filter)

Runs the external I<git log> command and returns the obtained data in a Callbackery-compatible way. If git support is
disabled, the list of I<.old> files is returned instead.

=cut
sub get_history ($self, $filter) {
    my @result;
    if ($self->git_support) {
        my (@output, undef) = run_external("cd " . $self->versions_dir . " && git log --pretty=format:'%h,%an,%s,%ad' --date=unix -n 20");
        chomp(@output);
        for my $revision (@output) {
            my ($hash, $user, $message, $date) = split /,/, $revision;
            $date =~ s/\)//g;
            my $date_string = localtime($date);
            push @result, { hash => $hash, date_unix => $date, user => $user, date => "$date_string", message => $message };
        }

    }
    else {
        my @files = read_dir($self->versions_dir, qr/\.old$/);
        chomp(@files);
        for my $old_version (@files) {
            my $date = get_mtime($old_version);
            my $date_string = localtime($date);
            push @result, { 'hash' => $old_version, 'date_unix' => $date, date => "$date_string", 'message' => 'git not activated or not supported' };
        }
    }
    return \@result, scalar @result;
}

=head3 get_n_entries($filter)

Returns how many entries are present

=cut
sub get_n_entries ($self, $filter) {
    my (undef, $count) = $self->get_history($filter);
    return $count;
}

=head3 checkin_new_version($commit_message, $user, $user_email)

Checks in a new version. If git support is disabled, this method is a No-op.

=cut
sub checkin_new_version ($self, $commit_message, $user, $user_email) {
    if ($self->git_support) {
        run_external("cd " . $self->versions_dir . " && git add .");
        run_external("cd " . $self->versions_dir . " && git -c user.name='$user' -c user.email=$user_email commit -m '$commit_message'");
    }
    else {
        # Do nothing
    }
}
=head3 go_back_to_revision($revision)

If git support is enabled C<$revision> is expected to be a commit hash. Otherwise a a path to a I<.old> configuration file.

=cut
sub go_back_to_revision ($self, $revision) {
    if ($self->git_support) {
        run_external("cd " . $self->versions_dir . " && git reset --hard $revision");
    }
    else {
        my $no_old = $revision;
        $no_old =~ s/\.old$//g;
        my $old_path = $revision;
        my $new_path = $no_old;
        # we have to create a copy here, otherwise the mtime gets not updated
        copy($old_path, $new_path . '.temp') or die "Create temp file for `$revision`" . $!;
        move($new_path . '.temp', $new_path) or die "Could not move old->new `$revision`" . $!;
        #move($new_path . '.temp', $old_path. '') or die "Could not create old config `$revision`" . $!;
        unlink($old_path);
    }

}

1;