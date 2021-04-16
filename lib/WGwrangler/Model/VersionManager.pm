=head1 NAME

WGwrangler::Model::VersionManager - Manages different config versions

=head1 DESCRIPTION

Manages configuration version either by maintaining a git repository or by relieving on I<.old> files

=head1 METHODS

=cut

package WGwrangler::Model::VersionManager;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';

use Symbol 'gensym';
use IPC::Open3;
use Data::Dumper;
use File::Copy qw(move copy);
use Wireguard::WGmeta::Wrapper::Bridge;
use Wireguard::WGmeta::Utils;

use constant FALSE => 0;
use constant TRUE => 1;

=head3 new($versions_dir, $not_applied_suffix [, $git_support])

Initializes a git repo in C<$versions_dis> if no I<.git> directory is found the parent dir and C<$git_support> is set to one.

Please note that all methods in this class raise Exceptions on failure!

=cut
sub new($class, $versions_dir, $not_applied_suffix, $git_support = 0) {
    my $self = {
        versions_dir => $versions_dir,
        git_support  => (-e $versions_dir . '../.git' || not $git_support) ? 0 : 1
    };

    # init git
    if ($self->{git_support}) {
        if (-e $versions_dir) {
            run_external("git init $versions_dir");
            unless (-e $versions_dir . '.gitignore') {
                run_external("echo '*.$not_applied_suffix' > $versions_dir.gitignore");
            }

        }
        else {
            die "`$versions_dir` does not exist";
        }
    }

    bless $self, $class;
    return $self;
}

=head3 get_history($filter)

Runs the external I<git log> command and returns the obtained data in a Callbackery-compatible way. If git support is
disabled, the list of I<.old> files is returned instead.

=cut
sub get_history($self, $filter) {
    my @result;
    if ($self->{git_support}) {
        my (@output, undef) = run_external("cd $self->{versions_dir} && git log --pretty=format:'%h,%an,%s,%ad' --date=unix -n 10");
        chomp(@output);
        for my $revision (@output) {
            my ($hash, $user, $message, $date) = split /,/, $revision;
            $date =~ s/\)//g;
            my $date_string = localtime($date);
            push @result, { hash => $hash, date_unix => $date, user => $user, date => "$date_string", message => $message };
        }

    }
    else {
        my @files = read_dir($self->{versions_dir}, qr/\.old$/);
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
sub get_n_entries($self, $filter) {
    my (undef, $count) = $self->get_history($filter);
    return $count;
}

=head3 checkin_new_version($commit_message, $user, $user_email)

Checks in a new version. If git support is disabled, this method is a No-op.

=cut
sub checkin_new_version($self, $commit_message, $user, $user_email) {
    if ($self->{git_support}) {
        run_external("cd $self->{versions_dir} && git add .");
        run_external("cd $self->{versions_dir} && git -c user.name='$user' -c user.email=$user_email commit -m '$commit_message'");
    }
    else {
        # Do nothing
    }
}
=head3 go_back_to_revision($revision)

If git support is enabled C<$revision> is expected to be a commit hash. Otherwise a a path to a I<.old> configuration file.

=cut
sub go_back_to_revision($self, $revision) {
    if ($self->{git_support}) {
        run_external("cd $self->{versions_dir} && git reset --hard $revision");
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