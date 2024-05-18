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

sub _trim
{
    my ( $s ) = @_;

    $s //= $EMPTY_STRING;
    $s =~ s/^\s+|\s+$//g;

    return $s;
}

sub _say_ex
{
    my @args = @_;

    my @local = ( localtime )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d_%H-%M-%S', @local );
    say '# ' . $now . ' # ' . join( '', @args );

    return;
}

sub _is_string_empty
{
    my ( $s ) = @_;

    my $t = !defined $s || $EMPTY_STRING eq $s;

    return $t;
}

sub _read_file
{
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    if ( !( -e -f -r -s $filepath ) ) {
        croak "filepath '$filepath' - not exists, readable or empty";
    }

    _say_ex "read modules from file '$filepath'";

    my $fh = undef;
    if ( !open( $fh, '<', $filepath ) ) {
        croak "Couldn't open file $filepath, $!";
    }

    my @raw_file_lines = <$fh>;
    close( $fh );

    return @raw_file_lines;
}

sub _write_file
{
    my ( $filepath, $header, @content ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    if ( _is_string_empty( $header ) ) {
        croak 'param header empty!';
    }

    _say_ex "write '$filepath'";

    my $fh = undef;
    if ( !open( $fh, '>', $filepath ) ) {
        croak "Couldn't open file $filepath, $!";
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

sub mark_module_as_ok
{
    my ( $module, $version ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( _is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    _say_ex 'add ', $module, ' to modules_install_ok';
    $modules_install_ok{ $module } = undef;

    _say_ex 'add ', $module, ' to installed_module_version';
    $installed_module_version{ $module } = $version;

    _say_ex 'remove ', $module, ' from modules_need_to_install';
    delete $modules_need_to_install{ $module };

    return;
}

sub mark_module_as_failed
{
    my ( $module, $version ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( _is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    _say_ex 'add ', $module, ' to modules_install_failed';
    $modules_install_failed{ $module } = $version;

    _say_ex 'remove ', $module, ' from modules_need_to_install';
    delete $modules_need_to_install{ $module };    # remove module - don't care if failed - no retry of failed

    return;
}

sub mark_module_as_not_found
{
    my ( $module, $version ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( _is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    _say_ex 'add ', $module, ' to modules_install_not_found';
    $modules_install_not_found{ $module } = $version;

    _say_ex 'remove ', $module, ' from modules_need_to_install';
    delete $modules_need_to_install{ $module };    # remove module - don't care if not found - no retry of not found

    return;
}

sub was_module_already_tried
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( exists $modules_install_ok{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        _say_ex 'WARN: install module - ' . $module . ' - already ok - abort';

        return 0;
    }

    if ( exists $modules_install_failed{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        _say_ex 'WARN: install module - ' . $module . ' - already failed - abort';

        return 1;
    }

    if ( exists $modules_install_not_found{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        _say_ex 'WARN: install module - ' . $module . ' - already mot found - abort';

        return 1;
    }

    return undef;
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

    _say_ex '';
    _say_ex 'modules_already_installed: '
        . scalar( keys %modules_already_installed ) . "\n"
        . Dumper( \%modules_already_installed );

    _say_ex '';
    _say_ex 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );

    _say_ex '';

    return;
}

sub print_install_state_summary
{
    _say_ex '';

    _say_ex 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );

    _say_ex 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );

    _say_ex 'modules_need_to_install left - ' . scalar( keys %modules_need_to_install );

    _say_ex 'modules_install_ok - ' . scalar( keys %modules_install_ok );

    # no dumper with need and ok - not necessary as temporary state.

    _say_ex '';

    return;
}

sub print_install_end_summary
{
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    _say_ex '';
    _say_ex 'summary';
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );
    _write_file(
        $filepath . '_modules_install_not_found.log',
        'modules_install_not_found: ' . scalar( keys %modules_install_not_found ),
        Dumper( \%modules_install_not_found ),
    );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );
    _write_file(
        $filepath . 'modules_install_failed.log',
        'modules_install_failed: ' . scalar( keys %modules_install_failed ),
        Dumper( \%modules_install_failed ),
    );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_ok: '
        . scalar( keys %modules_install_ok ) . "\n"
        . Dumper( \%modules_install_ok );
    _write_file(
        $filepath . 'modules_install_ok.log',
        'modules_install_ok: ' . scalar( keys %modules_install_ok ),
        Dumper( \%modules_install_ok ),
    );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );
    _write_file(
        $filepath . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_already_installed: '
        . scalar( keys %modules_already_installed ) . "\n"
        . Dumper( \%modules_already_installed );
    _write_file(
        $filepath . 'modules_already_installed.log',
        'modules_already_installed: ' . scalar( keys %modules_already_installed ),
        Dumper( \%modules_already_installed ),
    );
    _say_ex '';

    return;
}

sub search_for_installed_modules
{
    %installed_module_version = ();    # reset installed module info

    my $chld_in  = undef;
    my $chld_out = undef;

    my @cmd = ( 'cmd.exe', '/c', 'cpan', '-l' );
    _say_ex 'start cmd: ' . ( join ' ', @cmd );
    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        _say_ex 'ERROR: cmd start failed!';
        return;
    }

    _say_ex 'pid: ' . $pid;

    _say_ex 'close chld_in';
    close $chld_in;

    _say_ex 'read output ... ';

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS;

        while ( my $line = <$chld_out> ) {
            $line = _trim( $line );

            # _say_ex 'STDOUT: ' . $line;
            my @t = split /\s+/, $line;
            $installed_module_version{ $t[ 0 ] } =
                ( 'undef' eq $t[ 1 ] ? undef : $t[ 1 ] );
        }

        return 'eval_ok';
    };

    alarm 0;    # disable

    if ( $@ ) {
        if ( "timeout_alarm\n" ne $@ ) {
            _say_ex 'ERROR: unexpected error - ' - 0 + $@ - ' - ' . $@;
            kill -9, $pid;    # kill
        }
        else {
            _say_ex 'ERROR: timeout - ' - 0 + $@ - ' - ' . $@;
            kill -9, $pid;    # kill
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        _say_ex 'ERROR: eval failed ? - ' - 0 + $@ - ' - ' . $@;
        kill -9, $pid;        # kill
    }
    else {
        _say_ex 'close chld_out';
        close $chld_out;

        _say_ex 'wait for exit...';
        # reap zombie and retrieve exit status
        waitpid( $pid, 0 );
        my $child_exit_status = $? >> 8;
        _say_ex '$child_exit_status: ' . $child_exit_status;
    }

    _say_ex '';
    _say_ex 'installed_module_version: '
        . scalar( keys %installed_module_version ) . "\n"
        . Dumper( \%installed_module_version );
    _say_ex '';

    return;
}

sub get_module_dependencies
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    ## old 2022-05-15 ?
# --> Working on Perl::Critic
# Fetching http://www.cpan.org/authors/id/P/PE/PETDANCE/Perl-Critic-1.140.tar.gz ... OK
# Configuring Perl-Critic-1.140 ... OK
# Module::Build~0.4204
# ExtUtils::Install~1.46
# Fatal

    ## 2024-05-18 cpan new style or bug -> fetch all and use exit 1 ?
# start cmd: cmd.exe /c cpanm --showdeps Perl::Critic 2>&1
# --> Working on Perl::Critic
# Fetching http://www.cpan.org/authors/id/P/PE/PETDANCE/Perl-Critic-1.152.tar.gz ... OK
# ==> Found dependencies: B::Keywords, List::SomeUtils
# --> Working on B::Keywords
# Fetching http://www.cpan.org/authors/id/R/RU/RURBAN/B-Keywords-1.26.tar.gz ... OK
# Configuring B-Keywords-1.26 ... OK
# ExtUtils::MakeMaker~6.58
# ExtUtils::MakeMaker
# B
# --> Working on List::SomeUtils
# Fetching http://www.cpan.org/authors/id/D/DR/DROLSKY/List-SomeUtils-0.59.tar.gz ... OK
# Configuring List-SomeUtils-0.59 ... ! Installing the dependencies failed: Module 'List::SomeUtils' is not installed, Module 'B::Keywords' is not installed
# ! Bailing out the installation for Perl-Critic-1.152.
# OK
# ExtUtils::MakeMaker~6.58
# Text::ParseWords
# Test::LeakTrace
# Storable
# perl~5.006
# Test::More~0.96
# vars
# lib
# Tie::Array
# Module::Implementation~0.04
# List::Util
# strict
# base
# List::SomeUtils::XS~0.54
# Scalar::Util
# overload
# warnings
# ExtUtils::MakeMaker
# Carp
# File::Spec
# Exporter
# Test::Builder::Module

    _say_ex 'get module dependencies - ' . $module;

    my $chld_in  = undef;
    my $chld_out = undef;

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--showdeps', $module, '2>&1' );
    _say_ex 'start cmd: ' . ( join ' ', @cmd );

    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        _say_ex 'ERROR: cmd start failed!';

        return undef;    # as not found
    }

    _say_ex 'pid: ' . $pid;

    _say_ex 'close chld_in';
    close $chld_in;

    _say_ex 'read output ... ';

    my @output = ();

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS;

        while ( my $line = <$chld_out> ) {
            $line = _trim( $line );

            # _say_ex 'STDOUT: ' . $line;
            push @output, $line;
        }

        return 'eval_ok';
    };

    alarm 0;    # disable

    if ( $@ ) {
        if ( "timeout_alarm\n" ne $@ ) {
            _say_ex 'ERROR: unexpected error - ' - 0 + $@ - ' - ' . $@;

            kill -9, $pid;    # kill
            return undef;     # as >not found
        }
        else {
            _say_ex 'ERROR: timeout - ' - 0 + $@ - ' - ' . $@;

            kill -9, $pid;    # kill
            return undef;     # as not found
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        _say_ex 'ERROR: eval failed ? - ' - 0 + $@ - ' - ' . $@;

        kill -9, $pid;    # kill
        return undef;     # as not found
    }

    _say_ex 'close chld_out';
    close $chld_out;

    _say_ex 'wait for exit...';

    # reap zombie and retrieve exit status
    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    _say_ex '$child_exit_status: ' . $child_exit_status;

    if ( $child_exit_status && !@output ) {
        _say_ex 'ERROR: search failed - exitcode - ' . $child_exit_status;
        return undef;    # as not found
    }

    if ( ( join '', @output ) =~ /Couldn't find module or a distribution/io ) {
        _say_ex 'ERROR: module not found - ' . $module;
        return undef;    # as not found
    }

    my %dependencies = ();

    my @dependencie_lines =
        grep { $_ =~ /Found dependencies: /io } @output;

    foreach my $line ( @dependencie_lines ) {
        if ( $line =~ /Found dependencies: (.+)/o ) {
            my @module_names = split /[,]/io, $1;
            foreach my $module_name ( @module_names ) {
                $module_name = _trim($module_name);
                $dependencies{ $module_name } = undef;
            }
        }
    }

    @output =
        grep {
               $_ !~ /Working on/io
            && $_ !~ /Fetching http/io
            && $_ !~ /^Configuring /io
            && $_ !~ /^skipping /io
            && $_ !~ /^! /io
            && $_ !~ /^==>/io
            && $_ !~ /^-->/io
            && $_ !~ /^OK$/io
            && $_ !~ /^perl~.+/io
            && $_ !~ /^warnings$/io
            && $_ !~ /^strict$/io
            && $_ !~ /^vars$/io
            && $_ !~ /^lib$/io
            && $_ !~ /^overload$/io
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
    delete $dependencies{ 'warnings' };
    delete $dependencies{ 'strict' };
    delete $dependencies{ 'vars' };
    delete $dependencies{ 'lib' };
    delete $dependencies{ 'overload' };

    _say_ex 'dependencies found: ' . scalar( keys %dependencies ) . "\n" . Dumper( \%dependencies );

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

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    _say_ex 'analyze module - ' . $module;

    my $dep_ref = get_module_dependencies( $module );
    if ( !defined $dep_ref ) {
        _say_ex 'ERROR: module - ' . $module . ' - not found - abort !';
        mark_module_as_not_found( $module, undef );

        print_install_state_summary();

        return 1;
    }

    my %dep = %{ $dep_ref };
    if ( %dep ) {
        _say_ex 'module has dependencies - ' . $module . ' - reduce to not installed';
        %dep = reduce_dependency_modules_which_are_not_installed( %dep );
    }

    if ( %dep ) {
        _say_ex 'module - ' . $module . ' has not installed dependencies ' . "\n" . Dumper( \%dep );

        foreach my $dep_module ( keys %dep ) {
            my $ret = install_module_with_dep( $dep_module );
            if ( $ret ) {
                _say_ex 'ERROR: module - ' . $module . ' - aborted - failed dependencies';
                mark_module_as_failed( $module, undef );    # delete if something wrong - should not happen

                print_install_state_summary();

                return 1;
            }
        }
    }
    else {
        _say_ex 'module - ' . $module . ' - no dependencies to install';
    }

    my $ret = install_single_module( $module );

    return $ret ? 1 : 0;
}

sub install_single_module
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    my $tried = was_module_already_tried( $module );
    if ( defined $tried ) {
        return $tried;
    }

    # my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '1>NUL', '2>&1' );    # no output

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '2>&1' );    # no output

    # update needs force
    if ( exists $installed_module_version{ $module } ) {
        _say_ex 'update module - ' . $module;
    }
    else {
        _say_ex 'install module - ' . $module;
    }

    _say_ex 'start cmd: ' . ( join ' ', @cmd );
    _say_ex '';

    my $chld_in = undef;

    my $pid = open3( $chld_in, '>&STDOUT', '>&STDERR', @cmd );
    if ( 1 > $pid ) {
        _say_ex 'install module - ' . $module . ' - process start failed';
        mark_module_as_failed( $module, undef );
        print_install_state_summary();
        return 1;
    }

    _say_ex 'started pid: ' . $pid;

    _say_ex 'close chld_in';
    close $chld_in;

    _say_ex 'read output ... ';
    my $child_exit_status = undef;

    my $timeout_time    = $INSTALL_MODULE_TIMEOUT_IN_SECONDS + time;
    my $timeout_reached = 0;

    my $kid;
    do {
        $kid = waitpid( $pid, WNOHANG );
        # _say_ex 'kid: ' . $kid;
        if ( 0 == $kid ) {
            if ( $timeout_time < time ) {
                _say_ex 'ERROR: timeout reached';
                $timeout_reached = 1;
            }
            else {
                sleep 1;
            }
        }
    } while ( ( !$timeout_reached ) && ( 0 == $kid ) );

    if ( !$timeout_reached ) {
        $child_exit_status = $? >> 8;
        _say_ex '$child_exit_status: ' . $child_exit_status;
    }
    else {
        _say_ex 'ERROR: kill child process pid - ' . $pid;
        $child_exit_status = 1;
        kill -9, $pid;    # kill
    }

    my $action = '';

    if ( $child_exit_status ) {
        $action = 'failed';

        mark_module_as_failed( $module, undef );
    }
    else {
        $action = 'success';

        mark_module_as_ok( $module, 999_999 );    # newest version - so real number not relevant.
    }

    _say_ex 'install module - ' . $module . ' - ' . $action;

    print_install_state_summary();

    return $child_exit_status ? 1 : 0;
}

sub get_next_module_to_install
{
    # return ( reverse sort keys %modules_need_to_install )[ 0 ];

    use List::Util qw/shuffle/;

    return ( shuffle keys %modules_need_to_install )[ 0 ];
}

sub import_module_list_from_file
{
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    my @file_lines = _read_file( $filepath );

    @file_lines = map  { _trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ } @file_lines;

    @modules_to_install = @file_lines;
    @file_lines         = ();

    return;
}

sub install_modules
{
    my $install_module = get_next_module_to_install();
    while ( $install_module ) {
        install_module_with_dep( $install_module );

        my $next_module = get_next_module_to_install();
        if ( !$next_module ) {
            _say_ex 'no more modules to do';

            $install_module = '';
        }
        elsif ( $next_module ne $install_module ) {
            $install_module = $next_module;
        }
        else {
            _say_ex 'ERROR: next module not changed ' . $next_module . ' - abort !';

            $install_module = '';
        }
    }

    return;
}

sub print_perl_detail_info
{
    my @cmd = ( 'cmd.exe', '/c', 'perl', '-V' );
    _say_ex 'start cmd: ' . ( join ' ', @cmd );
    system( @cmd );
    _say_ex 'cmd ended';

    return;
}

sub main
{
    my ( $filepath ) = @_;

    $filepath = _trim( $filepath );
    if ( _is_string_empty( $filepath ) ) {
        croak 'no file arg given';
    }

    print_perl_detail_info();

    import_module_list_from_file( $filepath );

    search_for_installed_modules();

    reduce_modules_to_install();

    install_modules();

    print_install_end_summary( $filepath );

    return;
}

$| = 1;

_say_ex "started $0";

main( $ARGV[ 0 ] // '' );

_say_ex "ended $0";

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
