package WGwrangler::Model::VersionManager;
use strict;
use warnings FATAL => 'all';
use experimental 'signatures';

use Symbol 'gensym';
use IPC::Open3;
use Data::Dumper;

use constant FALSE => 0;
use constant TRUE => 1;

sub new($class, $versions_dir) {
    # init git
    if (-e $versions_dir) {
        run_external("git init $versions_dir");
        unless (-e $versions_dir . '.gitignore') {
            my $git_ignore = do {
                local $/;
                <DATA>
            };
            run_external("echo '$git_ignore' > $versions_dir.gitignore");
        }
    } else {
        die "`$versions_dir` does not exist";
    }

    my $self = {
        versions_dir => $versions_dir,
    };
    bless $self, $class;
    return $self;
}

sub get_history($self) {
    my @result;
    my (@output, undef) = run_external("cd $self->{versions_dir} && git log --pretty=reference --date=iso8601 -n 10");
    chomp(@output);
    for my $revision (@output) {
        my ($hash, $message, $date) = $revision =~ /^([a-f|0-9]+)\s+\((.*),\s+(.*)\)$/;
        $date =~ s/\)//g;
        push @result, { hash => $hash, date => $date, message => $message };
    }
    return \@result;
}

sub checkin_new_version($self, $commit_message) {
    run_external("cd $self->{versions_dir} && git add .");
    run_external("cd $self->{versions_dir} && git commit -m '$commit_message'");
}

sub go_back_to_revision($self, $revision) {
    run_external("cd $self->{versions_dir} && git reset --hard $revision");
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

1;

# gitignore
__DATA__
*.not_applied