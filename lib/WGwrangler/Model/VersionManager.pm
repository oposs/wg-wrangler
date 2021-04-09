package WGwrangler::Model::VersionManager;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';

use Symbol 'gensym';
use IPC::Open3;
use Data::Dumper;
use File::Copy qw(move copy);

use constant FALSE => 0;
use constant TRUE => 1;

sub new($class, $versions_dir, $not_applied_suffix, $git_support = 1) {
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

sub get_history($self, $filter) {
    my @result;
    if ($self->{git_support}) {
        my (@output, undef) = run_external("cd $self->{versions_dir} && git log --pretty=reference --date=unix -n 10");
        chomp(@output);
        for my $revision (@output) {
            my ($hash, $message, $date) = $revision =~ /^([a-f|0-9]+)\s+\((.*),\s+(.*)\)$/;
            $date =~ s/\)//g;
            my $date_string = localtime($date);
            push @result, { hash => $hash, date_unix => $date, date => "$date_string", message => $message };
        }

    }
    else {
        my @files = _read_dir($self->{versions_dir}, qr/\.old$/);
        chomp(@files);
        for my $old_version (@files) {
            my $date = _get_mtime($old_version);
            my $date_string = localtime($date);
            push @result, { 'hash' => $old_version, 'date_unix' => $date, date => "$date_string", 'message' => 'git not activated or not supported' };
        }
    }
    return \@result, scalar @result;
}

sub get_n_entries($self, $filter) {
    my (undef, $count) = $self->get_history($filter);
    return $count;
}

sub checkin_new_version($self, $commit_message, $user, $user_email) {
    if ($self->{git_support}) {
        run_external("cd $self->{versions_dir} && git add .");
        run_external("cd $self->{versions_dir} && git -c user.name='$user' -c user.email=$user_email commit -m '$commit_message'");
    }
    else {
        # Do nothing
    }
}

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

=head2 run_external($command_line [, $input, $soft_fail])

Runs an external program and throws an exception (or a warning if C<$soft_fail> is true) if the return code is != 0

B<Parameters>

=over 1

=item *

C<$command_line> Complete commandline for the external program to execute.

=item *

C<[$input = undef]> If defined, this is feed into STD_IN of C<$command_line>.

=item *

C<[$soft_fail = FALSE]> If set to true, a warning is thrown instead of an exception

=back

B<Raises>

Exception if return code is not 0 (if C<$soft_fail> is set to true, just a warning)

B<Returns>

Returns two lists with all lines of I<STDout> and I<STDerr>

=cut
sub run_external($command_line, $input = undef, $soft_fail = FALSE) {
    my $pid = open3(my $std_in, my $std_out, my $std_err = gensym, $command_line);
    if (defined($input)) {
        print $std_in $input;
    }
    close $std_in;
    my @output = <$std_out>;
    my @err = <$std_err>;
    close $std_out;
    close $std_err;

    waitpid($pid, 0);

    my $child_exit_status = $? >> 8;
    if ($child_exit_status != 0) {
        if ($soft_fail == TRUE) {
            warn "Command `$command_line` failed @err";
        }
        else {
            die "Command `$command_line` failed @err";
        }

    }
    return @output, @err;
}

sub _read_dir($path, $pattern) {
    opendir(DIR, $path) or die "Could not open $path\n";
    my @files;

    while (my $file = readdir(DIR)) {
        if ($file =~ $pattern) {
            push @files, $path . $file;
        }
    }
    closedir(DIR);
    return @files;
}

sub _get_mtime($path) {
    my @stat = stat($path);
    return (defined($stat[9])) ? "$stat[9]" : "0";
}

1;