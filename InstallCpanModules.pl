use utf8;

use 5.010;

use strict;
use warnings;

use version;
use POSIX qw( :sys_wait_h );
use Carp  qw( croak );
use Carp::Always;
use IPC::Open3;
use Data::Dumper qw( Dumper );
use List::Util   qw( shuffle );

BEGIN {
    if ( $^O !~ /win32/io ) {
        die 'sorry this is only for windows :(';
    }
}

our $VERSION = '0.01';

my %modules_to_install = ();

my %modules_to_install_with_deps_extended = ();

my %installed_module_version = ();

my %modules_need_to_install = ();

my %modules_install_already = ();
my %modules_install_ok      = ();
my %modules_install_failed  = ();

my %modules_install_not_found = (
    # 'B'               => undef,
    # 'B::Asmdata'      => undef,
    # 'B::Assembler'    => undef,
    # 'B::Bblock'       => undef,
    # 'B::Bytecode'     => undef,
    # 'B::C'            => undef,
    # 'B::CC'           => undef,
    # 'B::Debug'        => undef,
    # 'B::Deobfuscate'  => undef,
    # 'B::Deparse'      => undef,
    # 'B::Disassembler' => undef,
    # 'B::Lint'         => undef,
    # 'B::Showlex'      => undef,
    # 'B::Stash'        => undef,
    # 'B::Terse'        => undef,
    # 'B::Xref'         => undef,
    # 'only'            => undef,
);

my $INSTALL_MODULE_TIMEOUT_IN_SECONDS               = 60 * 10;
my $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS = 60 * 2;
my $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS = 60 * 2;
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

sub _hashify
{
    my @args = @_;

    return map { $_ => undef } @args;
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

sub _get_output_with_detached_execute
{
    my ( $timeout, $show_live_output, @cmd ) = @_;

    if ( _is_string_empty( $timeout ) ) {
        croak 'param timeout empty!';
    }

    if ( 1 > $timeout ) {
        croak 'param timeout greater 0!';
    }

    if ( _is_string_empty( $show_live_output ) ) {
        croak 'param show_live_output empty!';
    }

    if ( ( ( scalar @cmd ) == 0 ) || _is_string_empty( $cmd[ 0 ] ) ) {
        croak 'param @cmd empty!';
    }

    my $child_exit_status = undef;
    my @output            = ();

    my $chld_in  = undef;
    my $chld_out = undef;

    _say_ex 'start cmd: ' . ( join ' ', @cmd );
    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        _say_ex 'ERROR: cmd start failed!';
        return ( $child_exit_status, @output );
    }

    _say_ex 'pid: ' . $pid;

    _say_ex 'close chld_in';
    close $chld_in;

    _say_ex 'read output ... ';

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $timeout;

        while ( my $line = <$chld_out> ) {
            $line = _trim( $line );
            push @output, $line;

            if ( $show_live_output ) {
                _say_ex 'STDOUT: ' . $line;
            }
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
        $child_exit_status = $? >> 8;
        _say_ex '$child_exit_status: ' . $child_exit_status;
    }

    return ( $child_exit_status, @output );
}

sub _detached_execute_with_direct_output
{
    my ( $timeout, @cmd ) = @_;

    if ( _is_string_empty( $timeout ) ) {
        croak 'param timeout empty!';
    }

    if ( 1 > $timeout ) {
        croak 'param timeout greater 0!';
    }

    if ( ( ( scalar @cmd ) == 0 ) || _is_string_empty( $cmd[ 0 ] ) ) {
        croak 'param @cmd empty!';
    }

    my $chld_in = undef;

    _say_ex 'start cmd: ' . ( join ' ', @cmd );
    my $pid = open3( $chld_in, '>&STDOUT', '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        _say_ex 'ERROR: cmd start failed!';
        return;
    }

    _say_ex 'started pid: ' . $pid;

    _say_ex 'close chld_in';
    close $chld_in;

    _say_ex 'read output ... ';

    my $timeout_time    = $timeout + time;
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

    my $child_exit_status = undef;

    if ( $timeout_reached ) {
        _say_ex 'ERROR: kill child process pid - ' . $pid;
        $child_exit_status = 1;
        kill -9, $pid;    # kill

    }
    else {
        $child_exit_status = $? >> 8;
        _say_ex '$child_exit_status: ' . $child_exit_status;
    }

    return ( $child_exit_status );
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

    _say_ex 'remove ', $module, ' from modules_to_install_with_deps_extended';
    delete $modules_to_install_with_deps_extended{ $module };

    _say_ex 'remove dependencies ', $module, ' from modules_to_install_with_deps_extended';
    foreach my $key ( keys %modules_to_install_with_deps_extended ) {
        if ( exists $modules_to_install_with_deps_extended{ $key }->{ $module } ) {
            delete $modules_to_install_with_deps_extended{ $key }->{ $module };
        }
    }
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

    _say_ex 'remove ', $module, ' from modules_to_install_with_deps_extended';
    delete $modules_to_install_with_deps_extended{ $module };

    _say_ex 'mark modules as failed which depends on ', $module;
    foreach my $key ( keys %modules_to_install_with_deps_extended ) {
        if ( exists $modules_to_install_with_deps_extended{ $key }->{ $module } ) {
            mark_module_as_failed( $key );
        }
    }

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

    _say_ex 'remove ', $module, ' from modules_to_install_with_deps_extended';
    delete $modules_to_install_with_deps_extended{ $module };

    _say_ex 'mark modules as failed which depends on ', $module;
    foreach my $key ( keys %modules_to_install_with_deps_extended ) {
        if ( exists $modules_to_install_with_deps_extended{ $key }->{ $module } ) {
            mark_module_as_failed( $key );
        }
    }

    return;
}

sub mark_module_as_to_install
{
    my ( $module, $version ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( _is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    if ( exists $modules_need_to_install{ $module } ) {
        return;
    }

    if ( exists $modules_install_not_found{ $module } ) {
        _say_ex $module, ' already in modules_install_not_found';
        return;
    }

    if ( exists $modules_install_failed{ $module } ) {
        _say_ex $module, ' already in modules_install_failed';
        return;
    }

    _say_ex 'add ', $module, ' (dependency) to modules_need_to_install';
    $modules_need_to_install{ $module } = $version;

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
    %modules_install_already = ();    # rest info
    %modules_need_to_install = ();

    foreach my $module ( keys %modules_to_install ) {
        if ( exists $installed_module_version{ $module } ) {
            $modules_install_already{ $module } = undef;
        }
        else {
            $modules_need_to_install{ $module } = undef;
        }
    }

    _say_ex '';
    _say_ex 'modules_install_already: '
        . scalar( keys %modules_install_already ) . "\n"
        . Dumper( \%modules_install_already );

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

    _say_ex 'modules_to_install_with_deps_extended left - '
        . scalar( keys %modules_to_install_with_deps_extended ) . "\n"
        . Dumper( \%modules_to_install_with_deps_extended );

    _say_ex 'modules_need_to_install left - '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );

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

    foreach ( 1 .. 10 ) {
        _say_ex '';
    }
    _say_ex 'summary';
    _say_ex '';

    _say_ex '';
    _write_file(
        $filepath . 'modules_install_already.log',
        'modules_install_already: ' . scalar( keys %modules_install_already ),
        Dumper( \%modules_install_already ),
    );
    _say_ex 'modules_install_already: '
        . scalar( keys %modules_install_already ) . "\n"
        . Dumper( \%modules_install_already );
    _say_ex '';

    _say_ex '';
    _write_file(
        $filepath . 'modules_install_ok.log',
        'modules_install_ok: ' . scalar( keys %modules_install_ok ),
        Dumper( \%modules_install_ok ),
    );
    _say_ex 'modules_install_ok: ' . scalar( keys %modules_install_ok ) . "\n" . Dumper( \%modules_install_ok );
    _say_ex '';

    _say_ex '';
    _write_file(
        $filepath . '_modules_install_not_found.log',
        'modules_install_not_found: ' . scalar( keys %modules_install_not_found ),
        Dumper( \%modules_install_not_found ),
    );
    _say_ex 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );
    _say_ex '';

    _say_ex '';
    _write_file(
        $filepath . 'modules_install_failed.log',
        'modules_install_failed: ' . scalar( keys %modules_install_failed ),
        Dumper( \%modules_install_failed ),
    );
    _say_ex 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );
    _say_ex '';

    _say_ex '';
    _write_file(
        $filepath . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );
    _say_ex 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );
    _say_ex '';

    return;
}

sub search_for_installed_modules
{
    %installed_module_version = ();    # reset installed module info

    my @cmd = ( 'cmd.exe', '/c', 'cpan', '-l' );

    my ( $child_exit_status, @output ) =
        _get_output_with_detached_execute( $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS, 0, @cmd );

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    foreach my $line ( @output ) {
        my @t = split /\s+/, $line;
        $installed_module_version{ $t[ 0 ] } =
            ( 'undef' eq $t[ 1 ] ? undef : $t[ 1 ] );
    }

    _say_ex '';
    _say_ex 'installed_module_version: ' . scalar( keys %installed_module_version ) . "\n"
        # . Dumper( \%installed_module_version );
        . '';
    _say_ex '';

    return;
}

sub fetch_dependencies_for_module
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

    # - FIXME - TODO - NOTE -

    # straberry perl 5.16 : cpanm --verbose --force MIYAGAWA/App-cpanminus-1.6005.tar.gz
    # NOT FOUND: cpanm --verbose --force MIYAGAWA/App-cpanminus-1.6906.tar.gz
    # OK: cpanm --verbose --force MIYAGAWA/App-cpanminus-1.6907.tar.gz
    # NOT FOUND: cpanm --verbose --force MIYAGAWA/App-cpanminus-1.6908.tar.gz
    # BROKEN: cpanm --verbose --force MIYAGAWA/App-cpanminus-1.6909.tar.gz
    # straberry perl 5.18 : cpanm --verbose --force MIYAGAWA/App-cpanminus-1.7012.tar.gz

    # some change in 1.6908 has new behavior - so it end's with exit 1 instead of 0
    # they try to install the modules an not only shows it.
    ## - Rather than counting failures, check the requirements once all deps are installed. #237 Tatsuhiko Miyagawa 27.04.2013 02:45
# now here i wanted to use showdeps to search for missing dependencies - but with the upper change, it exits if 1 because of failed dependencies :)

    # --showdeps - prints the dep-messages an return 1
    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--no-interactive', '--showdeps', $module, '2>&1' );

    my ( $child_exit_status, @output ) =
        _get_output_with_detached_execute( $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS, 1, @cmd );

    if ( !defined $child_exit_status ) {
        return undef;    # as not found
    }

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
                $module_name = _trim( $module_name );
                $dependencies{ $module_name } = undef;
            }
        }
    }

    _say_ex '';
    _say_ex 'deps from Found dependencies: ' . scalar( keys %dependencies ) . "\n" . Dumper( \%dependencies );
    _say_ex '';

    @output =
        grep {
               $_ !~ /Working on/io
            && $_ !~ /Fetching http/io
            && $_ !~ /Found dependencies: /io
            && $_ !~ /^Configuring /io
            && $_ !~ /^skipping /io
            && $_ !~ /^! /o
            && $_ !~ /^==>/o
            && $_ !~ /^-->/o
            && $_ !~ /^OK$/io
            && $_ !~ /^perl~.+/io
            && $_ !~ /^warnings$/o
            && $_ !~ /^strict$/o
            && $_ !~ /^vars$/o
            && $_ !~ /^lib$/o
            && $_ !~ /^overload$/o
            && $_ !~ /^if$/o
            && $_ !~ /^utf8$/o
            && $_ !~ /^[a-z\d]+$/o
            && $_ !~ /^[a-z\d]+~\d+$/o
            && $_ !~ /^[a-z\d]+~\d+\..+$/o
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

    _say_ex '';
    _say_ex 'dependencies found: ' . scalar( keys %dependencies ) . "\n" . Dumper( \%dependencies );
    _say_ex '';

    return \%dependencies;
}

sub reduce_dependency_modules_which_are_not_installed
{
    my %dependencies = @_;

    my %not_installed = ();

    foreach my $module ( keys %dependencies ) {
        if ( !exists $installed_module_version{ $module } ) {
            _say_ex 'dependency not installed: ' . $module;
            $not_installed{ $module } = $dependencies{ $module };
        }
        elsif ( defined $dependencies{ $module } && defined $installed_module_version{ $module } ) {
            my $installed_version = version->parse( $installed_module_version{ $module } );
            my $dependent_version = version->parse( $dependencies{ $module } );

            if ( ( $dependent_version cmp $installed_version ) == 1 ) {
                _say_ex 'dependency old version - update needed: ' . $module;
                $not_installed{ $module } = $dependencies{ $module };    # to old version
            }
            else {
                _say_ex 'dependency installed and version check done: ' . $module;
            }
        }
        else {
            _say_ex 'dependency installed: ' . $module;
        }
    }

    return %not_installed;
}

sub add_dependency_module_if_needed
{
    my ( $module ) = @_;

    state $recursion = 1;
    _say_ex 'add_dependency_module_if_needed - recursion level: ' . $recursion;

    _say_ex 'import module dependencies for - ' . $module;

    if ( 10 < $recursion ) {
        croak "deep recursion level $recursion - abort!";
    }

    if ( exists $modules_to_install_with_deps_extended{ $module } ) {
        _say_ex 'dependencies for module - ' . $module . ' - already checked';

        return;
    }

    my $dep_ref = fetch_dependencies_for_module( $module );
    if ( !defined $dep_ref ) {
        _say_ex 'module - ' . $module . ' - not found!';

        $modules_to_install_with_deps_extended{ $module } = {};    # as no deps

        return;
    }

    my %dep = %{ $dep_ref };
    if ( !%dep ) {
        _say_ex 'module - ' . $module . ' - has no dependencies';

        $modules_to_install_with_deps_extended{ $module } = {};    # mark module without needed deps

        return;
    }

    _say_ex 'module - ' . $module . ' - has dependencies - reduce to not installed';
    %dep = reduce_dependency_modules_which_are_not_installed( %dep );
    if ( !%dep ) {
        _say_ex 'module - ' . $module . ' - has no uninstalled dependencies';

        $modules_to_install_with_deps_extended{ $module } = {};    # mark module without needed deps

        return;
    }

    _say_ex 'module - ' . $module . ' has not installed dependencies - add to install list' . "\n" . Dumper( \%dep );

    $modules_to_install_with_deps_extended{ $module } = \%dep;    # mark module needed deps

    foreach my $module ( sort keys %dep ) {
        # only here - not at entry and every return.
        $recursion++;
        add_dependency_module_if_needed( $module );
        $recursion--;
    }

    return;
}

sub add_dependency_modules_for_modules_need_to_install
{
    _say_ex 'add all dependent modules to install list';

    my @needed_modules = keys %modules_need_to_install;

    my $check_max = scalar @needed_modules;
    my $check_i   = 0;

    foreach my $module ( @needed_modules ) {
        $check_i++;
        _say_ex "==> analyze module - ($check_i / $check_max) - $module";

        add_dependency_module_if_needed( $module );
    }

    print_install_state_summary();

    return;
}

sub install_module_with_dep
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    _say_ex 'analyze module - ' . $module;

    my $dep_ref = fetch_dependencies_for_module( $module );
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

    if ( exists $installed_module_version{ $module } ) {
        _say_ex 'update module - ' . $module;
    }
    else {
        _say_ex 'install module - ' . $module;
    }

    my $action = '';

    # my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '1>NUL', '2>&1' );    # no output
    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '2>&1' );    # no output

    my $child_exit_status = _detached_execute_with_direct_output( $INSTALL_MODULE_TIMEOUT_IN_SECONDS, @cmd );

    if ( !defined $child_exit_status ) {
        $child_exit_status = 1;

        _say_ex 'install module - ' . $module . ' - process start failed';
        mark_module_as_failed( $module, undef );
        print_install_state_summary();

    }
    elsif ( $child_exit_status ) {
        $child_exit_status = 1;

        $action = 'failed';
        mark_module_as_failed( $module, undef );
    }
    else {
        $child_exit_status = 0;

        $action = 'success';
        mark_module_as_ok( $module, 999_999 );    # newest version - so real number not relevant.
    }

    _say_ex 'install module - ' . $module . ' - ' . $action;
    print_install_state_summary();

    return $child_exit_status;
}

sub get_next_module_to_install
{
    my @install_modules = keys %modules_need_to_install;
    my $remaining       = scalar @install_modules;
    _say_ex "==> $remaining remaining modules to install";

    return ( shuffle @install_modules )[ 0 ];
}

sub install_modules
{
    my $install_module = get_next_module_to_install();
    while ( !_is_string_empty( $install_module ) ) {
        install_module_with_dep( $install_module );

        my $next_module = get_next_module_to_install();
        if ( _is_string_empty( $next_module ) ) {
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

sub import_module_list_from_file
{
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    my @file_lines = _read_file( $filepath );

    @file_lines = map  { _trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ } @file_lines;

    %modules_to_install = _hashify @file_lines;
    @file_lines         = ();

    _say_ex '';
    _say_ex 'wanted modules to install found: '
        . ( scalar keys %modules_to_install ) . "\n"
        . Dumper( \%modules_to_install );
    _say_ex '';

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

sub install_module_dep_version
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    _say_ex '';
    _say_ex( '=' x 80 );
    _say_ex '';

    _say_ex 'analyze module - ' . $module;

    my $dep_ref = fetch_dependencies_for_module( $module );
    if ( !defined $dep_ref ) {
        _say_ex 'ERROR: module - ' . $module . ' - not found - abort !';
        mark_module_as_not_found( $module, undef );

        print_install_state_summary();

        return 1;
    }

    _say_ex 'module - ' . $module . ' - found try install';
    my $ret = install_single_module( $module );

    return $ret ? 1 : 0;
}

sub get_next_module_to_install_dep_version
{
    my @install_modules = keys %modules_to_install_with_deps_extended;
    my @no_deps_modules =
        grep { 0 == ( scalar keys %{ $modules_to_install_with_deps_extended{ $_ } } ) } @install_modules;

    my $remaining = scalar @install_modules;

    _say_ex '';
    _say_ex "==> $remaining remaining modules to install";
    _say_ex '';

    if ( $remaining && !@no_deps_modules ) {
        _say_ex 'ERROR: remaining modules but no one without dependencies ?';
    }

    if ( !@no_deps_modules ) {
        return;
    }

    return ( shuffle @no_deps_modules )[ 0 ];    # only modules with no other dependencies
}

sub install_modules_dep_version
{
    my $install_module = get_next_module_to_install_dep_version();
    while ( !_is_string_empty( $install_module ) ) {
        install_module_dep_version( $install_module );

        my $next_module = get_next_module_to_install_dep_version();
        if ( _is_string_empty( $next_module ) ) {
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

    reduce_modules_to_install();    # updates should be handled another time ...

    add_dependency_modules_for_modules_need_to_install();

    print_install_state_summary();

    install_modules_dep_version();

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
