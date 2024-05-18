use utf8;

use 5.010;

use strict;
use warnings;

use POSIX qw(:sys_wait_h);
use Carp  qw(croak);
use Carp::Always;
use IPC::Open3;
use Data::Dumper qw(Dumper);

BEGIN {
    if ( $^O !~ /win32/io ) {
        die 'sorry this is only for windows :(';
    }
}

our $VERSION = '0.01';

my @modules_to_install = ();

my %installed_module_version = ();

my %modules_already_installed = ();
my %modules_need_to_install   = ();

my %modules_install_ok     = ();
my %modules_install_failed = ();

my %modules_install_not_found = (
    'B'               => undef,
    'B::Asmdata'      => undef,
    'B::Assembler'    => undef,
    'B::Bblock'       => undef,
    'B::Bytecode'     => undef,
    'B::C'            => undef,
    'B::CC'           => undef,
    'B::Debug'        => undef,
    'B::Deobfuscate'  => undef,
    'B::Deparse'      => undef,
    'B::Disassembler' => undef,
    'B::Lint'         => undef,
    'B::Showlex'      => undef,
    'B::Stash'        => undef,
    'B::Terse'        => undef,
    'B::Xref'         => undef,
    'only'            => undef,
);

my $INSTALL_MODULE_TIMEOUT_IN_SECONDS               = 60 * 5;
my $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS = 60 * 1;
my $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS = 60 * 1;
my $EMPTY_STRING                                    = q{};

sub trim
{
    my ( $s ) = @_;

    $s //= $EMPTY_STRING;
    $s =~ s/^\s+|\s+$//g;

    return $s;
}

sub say_helper_output
{
    my @args = @_;

    my @local = ( localtime )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d_%H-%M-%S', @local );
    say '# ' . $now . ' # ' . join( '', @args );

    return;
}

sub is_string_empty
{
    my ( $s ) = @_;

    my $t = !defined $s || $EMPTY_STRING eq $s;

    return $t;
}

sub add_module_to_ok
{
    my ( $module, $version ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    $modules_install_ok{ $module }       = undef;
    $installed_module_version{ $module } = $version;

    delete $modules_need_to_install{ $module };

    return;
}

sub add_module_to_failed
{
    my ( $module, $version ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    $modules_install_failed{ $module } = $version;

    delete $modules_need_to_install{ $module };    # remove module - don't care if failed - no retry of failed

    return;
}

sub add_module_to_not_found
{
    my ( $module, $version ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    $modules_install_not_found{ $module } = $version;

    delete $modules_need_to_install{ $module };    # remove module - don't care if not found - no retry of not found

    return;
}

sub print_install_state_summary
{
    say_helper_output '';

    say_helper_output 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );

    say_helper_output 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );

    say_helper_output 'modules_need_to_install left - ' . scalar( keys %modules_need_to_install );

    say_helper_output 'modules_install_ok: ' . scalar( keys %modules_install_ok );

    # no dumper with need and ok - not necessary as temporary state.

    say_helper_output '';

    return;
}

sub search_for_installed_modules
{
    %installed_module_version = ();    # reset installed module info

    my $chld_in  = undef;
    my $chld_out = undef;

    my @cmd = ( 'cmd.exe', '/c', 'cpan', '-l' );
    say_helper_output 'start cmd: ' . ( join ' ', @cmd );
    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        say_helper_output 'ERROR: cmd start failed!';
        return;
    }

    say_helper_output 'pid: ' . $pid;

    say_helper_output 'close chld_in';
    close $chld_in;

    say_helper_output 'read output ... ';

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS;

        while ( my $line = <$chld_out> ) {
            $line = trim( $line );

            # say_helper_output 'STDOUT: ' . $line;
            my @t = split /\s+/, $line;
            $installed_module_version{ $t[ 0 ] } =
                ( 'undef' eq $t[ 1 ] ? undef : $t[ 1 ] );
        }

        return 'eval_ok';

    };

    alarm 0;    # disable

    if ( $@ ) {
        if ( "timeout_alarm\n" ne $@ ) {
            say_helper_output 'ERROR: unexpected error - ' - 0 + $@ - ' - ' . $@;

            kill -9, $pid;    # kill
        }
        else {
            say_helper_output 'ERROR: timeout - ' - 0 + $@ - ' - ' . $@;

            kill -9, $pid;    # kill
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        say_helper_output 'ERROR: eval failed ? - ' - 0 + $@ - ' - ' . $@;

        kill -9, $pid;        # kill
    }
    else {
        say_helper_output 'close chld_out';
        close $chld_out;

        say_helper_output 'wait for exit...';

        # reap zombie and retrieve exit status
        waitpid( $pid, 0 );
        my $child_exit_status = $? >> 8;
        say_helper_output '$child_exit_status: ' . $child_exit_status;
    }

    say_helper_output '';
    say_helper_output 'installed_module_version: '
        . scalar( keys %installed_module_version ) . "\n"
        . Dumper( \%installed_module_version );
    say_helper_output '';

    return;
}

sub reduce_modules_to_install
{
    %modules_already_installed = ();    # rest info
    %modules_need_to_install   = ();

    foreach my $module ( @modules_to_install ) {
        if ( exists $installed_module_version{ $module } ) {
            $modules_already_installed{ $module } = undef;
        }
        else {
            $modules_need_to_install{ $module } = undef;
        }
    }

    say_helper_output '';
    say_helper_output 'modules_already_installed: '
        . scalar( keys %modules_already_installed ) . "\n"
        . Dumper( \%modules_already_installed );

    say_helper_output '';
    say_helper_output 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );

    say_helper_output '';

    return;
}

sub renew_local_module_information
{
    search_for_installed_modules();

    reduce_modules_to_install();

    return;
}

sub get_module_dependencies
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    my %dependencies = ();

    # --> Working on Perl::Critic
    # Fetching http://www.cpan.org/authors/id/P/PE/PETDANCE/Perl-Critic-1.140.tar.gz ... OK
    # Configuring Perl-Critic-1.140 ... OK
    # Module::Build~0.4204
    # ExtUtils::Install~1.46
    # Fatal

    say_helper_output 'get module dependencies - ' . $module;

    my $chld_in  = undef;
    my $chld_out = undef;

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--showdeps', $module, '2>&1' );
    say_helper_output 'start cmd: ' . ( join ' ', @cmd );

    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        say_helper_output 'ERROR: cmd start failed!';

        return undef;    # as not found
    }

    say_helper_output 'pid: ' . $pid;

    say_helper_output 'close chld_in';
    close $chld_in;

    say_helper_output 'read output ... ';

    my @output = ();

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS;

        while ( my $line = <$chld_out> ) {
            $line = trim( $line );

            # say_helper_output 'STDOUT: ' . $line;
            push @output, $line;
        }

        return 'eval_ok';
    };

    alarm 0;    # disable

    if ( $@ ) {
        if ( "timeout_alarm\n" ne $@ ) {
            say_helper_output 'ERROR: unexpected error - ' - 0 + $@ - ' - ' . $@;

            kill -9, $pid;    # kill
            return undef;     # as >not found
        }
        else {
            say_helper_output 'ERROR: timeout - ' - 0 + $@ - ' - ' . $@;

            kill -9, $pid;    # kill
            return undef;     # as not found
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        say_helper_output 'ERROR: eval failed ? - ' - 0 + $@ - ' - ' . $@;

        kill -9, $pid;    # kill
        return undef;     # as not found
    }

    say_helper_output 'close chld_out';
    close $chld_out;

    say_helper_output 'wait for exit...';

    # reap zombie and retrieve exit status
    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    say_helper_output '$child_exit_status: ' . $child_exit_status;

    if ( $child_exit_status ) {
        if ( ( join '', @output ) =~ /Couldn't find module or a distribution/io ) {
            say_helper_output 'ERROR: module not found - ' . $module;
        }
        else {
            say_helper_output 'ERROR: search failed - exitcode - ' . $?;
        }

        return undef;    # as not found
    }

    @output =
        grep {
               $_ !~ /Working on/io
            && $_ !~ /Fetching http/io
            && $_ !~ /^Configuring /io
            && $_ !~ /^skipping /io
            && $_ !~ /^! /io
        } @output;

    %dependencies = map {
        my @t = split /~/io, $_;
        if ( ( scalar @t ) <= 1 ) {
            $t[ 0 ] => undef;
        }
        else {
            $t[ 0 ] => $t[ 1 ];
        }
    } @output;

    delete $dependencies{ 'perl' };    # not perl itself

    say_helper_output 'dependencies found: ' . scalar( keys %dependencies ) . "\n" . Dumper( \%dependencies );

    return \%dependencies;
}

sub reduce_dependency_modules_which_are_not_installed
{
    my %dependencies = @_;

    my %not_installed = ();

    foreach my $module ( keys %dependencies ) {
        if ( !exists $installed_module_version{ $module } ) {
            $not_installed{ $module } = $dependencies{ $module };
        }
        elsif (defined $dependencies{ $module }
            && defined $installed_module_version{ $module }
            && ( 0.0 + $installed_module_version{ $module } ) < ( 0.0 + $dependencies{ $module } ) )
        {
            $not_installed{ $module } = $dependencies{ $module };    # to old version
        }
    }

    return %not_installed;
}

sub install_module_with_dep
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    say_helper_output 'analyze module - ' . $module;

    my $dep_ref = get_module_dependencies( $module );
    if ( !defined $dep_ref ) {
        say_helper_output 'ERROR: module - ' . $module . ' - not found - abort !';
        add_module_to_not_found( $module, undef );

        print_install_state_summary();

        return 1;
    }

    my %dep = %{ $dep_ref };
    if ( %dep ) {
        say_helper_output 'module has dependencies - ' . $module . ' - reduce to not installed';
        %dep = reduce_dependency_modules_which_are_not_installed( %dep );
    }

    if ( %dep ) {
        say_helper_output 'module - ' . $module . ' has not installed dependencies ' . "\n" . Dumper( \%dep );

        foreach my $dep_module ( keys %dep ) {
            my $ret = install_module_with_dep( $dep_module );
            if ( $ret ) {
                say_helper_output 'ERROR: module - ' . $module . ' - aborted - failed dependencies';
                add_module_to_failed( $module, undef );    # delete if something wrong - should not happen

                print_install_state_summary();

                return 1;
            }
        }
    }
    else {
        say_helper_output 'module - ' . $module . ' - no dependencies to install';
    }

    my $ret = simple_install_module( $module );

    return $ret ? 1 : 0;
}

sub simple_install_module
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    my $tried = module_already_tried( $module );
    if ( defined $tried ) {
        return $tried;
    }

    # my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '1>NUL', '2>&1' );    # no output

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '2>&1' );    # no output

    # update needs force
    if ( exists $installed_module_version{ $module } ) {
        say_helper_output 'update module - ' . $module;
    }
    else {
        say_helper_output 'install module - ' . $module;
    }

    say_helper_output 'start cmd: ' . ( join ' ', @cmd );
    say_helper_output '';

    my $chld_in = undef;

    my $pid = open3( $chld_in, '>&STDOUT', '>&STDERR', @cmd );
    if ( 1 > $pid ) {
        say_helper_output 'install module - ' . $module . ' - process start failed';
        add_module_to_failed( $module, undef );
        print_install_state_summary();
        return 1;
    }

    say_helper_output 'started pid: ' . $pid;

    say_helper_output 'close chld_in';
    close $chld_in;

    say_helper_output 'read output ... ';
    my $child_exit_status = undef;

    my $timeout_time    = $INSTALL_MODULE_TIMEOUT_IN_SECONDS + time;
    my $timeout_reached = 0;

    my $kid;
    do {
        $kid = waitpid( $pid, WNOHANG );
        say_helper_output 'kid: ' . $kid;
        if ( 0 == $kid ) {
            if ( $timeout_time < time ) {
                say_helper_output 'ERROR: timeout reached';
                $timeout_reached = 1;
            }
            else {
                sleep 1;
            }
        }
    } while ( ( !$timeout_reached ) && ( 0 == $kid ) );

    if ( !$timeout_reached ) {
        $child_exit_status = $? >> 8;
        say_helper_output '$child_exit_status: ' . $child_exit_status;
    }
    else {
        say_helper_output 'ERROR: kill child process pid - ' . $pid;
        $child_exit_status = 1;
        kill -9, $pid;    # kill
    }

    my $action = '';

    if ( $child_exit_status ) {
        $action = 'failed';

        add_module_to_failed( $module, undef );
    }
    else {
        $action = 'success';

        add_module_to_ok( $module, 999_999 );    # newest version - so real number not relevant.
    }

    say_helper_output 'install module - ' . $module . ' - ' . $action;

    print_install_state_summary();

    return $child_exit_status ? 1 : 0;
}

sub module_already_tried
{
    my ( $module ) = @_;

    if ( exists $modules_install_ok{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        say_helper_output 'WARN: install module - ' . $module . ' - already done - abort';

        return 0;
    }

    if ( exists $modules_install_failed{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        say_helper_output 'WARN: install module - ' . $module . ' - already tried - abort';

        return 1;
    }

    if ( exists $modules_install_not_found{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        say_helper_output 'WARN: install module - ' . $module . ' - already mot found - abort';

        return 1;
    }

    return undef;
}

sub get_next_module_to_install
{
    # return ( reverse sort keys %modules_need_to_install )[ 0 ];

    use List::Util qw/shuffle/;

    return ( shuffle keys %modules_need_to_install )[ 0 ];
}

sub simple_file_read
{
    my ( $filepath ) = @_;

    if ( !( -e -f -r -s $filepath ) ) {
        die "filepath '$filepath' - not exists, readable or empty";
    }

    say_helper_output "read modules from file '$filepath'";

    my $fh = undef;
    if ( !open( $fh, '<', $filepath ) ) {
        die "Couldn't open file $filepath, $!";
    }

    my @raw_file_lines = <$fh>;
    close( $fh );

    return @raw_file_lines;
}

sub simple_file_write
{
    my ( $filepath, $header, @content ) = @_;

    say_helper_output "write '$filepath'";

    my $fh = undef;
    if ( !open( $fh, '>', $filepath ) ) {
        die "Couldn't open file $filepath, $!";
    }

    say { $fh } $header;
    say { $fh } '';
    say { $fh } '';
    foreach my $line ( @content ) {
        say { $fh } $line;
    }

    close( $fh );

    return;
}

sub import_module_list_from_file
{
    my ( $filepath ) = @_;

    my @file_lines = simple_file_read( $filepath );

    @file_lines = map  { trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ } @file_lines;

    @modules_to_install = @file_lines;
    @file_lines         = ();

    return;
}

sub main
{
    my ( $filepath ) = @_;

    $filepath = trim( $filepath );
    if ( !defined $filepath || $EMPTY_STRING eq $filepath ) {
        die 'no file arg given';
    }

    import_module_list_from_file( $filepath );

    renew_local_module_information();

    my $install_module = get_next_module_to_install();
    while ( $install_module ) {
        install_module_with_dep( $install_module );

        my $next_module = get_next_module_to_install();
        if ( !$next_module ) {
            say_helper_output 'no more modules to do';

            $install_module = '';
        }
        elsif ( $next_module ne $install_module ) {
            $install_module = $next_module;
        }
        else {
            say_helper_output 'ERROR: next module not changed ' . $next_module . ' - abort !';

            $install_module = '';
        }
    }

    say_helper_output '';
    say_helper_output 'summary';
    say_helper_output '';

    say_helper_output '';
    say_helper_output 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );
    simple_file_write(
        $filepath . '_modules_install_not_found.log',
        'modules_install_not_found: ' . scalar( keys %modules_install_not_found ),
        Dumper( \%modules_install_not_found ),
    );
    say_helper_output '';

    say_helper_output '';
    say_helper_output 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );
    simple_file_write(
        $filepath . 'modules_install_failed.log',
        'modules_install_failed: ' . scalar( keys %modules_install_failed ),
        Dumper( \%modules_install_failed ),
    );
    say_helper_output '';

    say_helper_output '';
    say_helper_output 'modules_install_ok: '
        . scalar( keys %modules_install_ok ) . "\n"
        . Dumper( \%modules_install_ok );
    simple_file_write(
        $filepath . 'modules_install_ok.log',
        'modules_install_ok: ' . scalar( keys %modules_install_ok ),
        Dumper( \%modules_install_ok ),
    );
    say_helper_output '';

    say_helper_output '';
    say_helper_output 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );
    simple_file_write(
        $filepath . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );
    say_helper_output '';

    say_helper_output '';
    say_helper_output 'modules_already_installed: '
        . scalar( keys %modules_already_installed ) . "\n"
        . Dumper( \%modules_already_installed );
    simple_file_write(
        $filepath . 'modules_already_installed.log',
        'modules_already_installed: ' . scalar( keys %modules_already_installed ),
        Dumper( \%modules_already_installed ),
    );
    say_helper_output '';

    return;
}

$| = 1;

say_helper_output "started $0";

main( $ARGV[ 0 ] // '' );

say_helper_output "ended $0";

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

InstallCpanModules.pl

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Markus Demml, mardem@cpan.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024, Markus Demml

This library is free software; you can redistribute it and/or modify it
under the same terms as the Perl 5 programming language system itself.
The full text of this license can be found in the LICENSE file included
with this module.

=cut
