
use utf8;

use 5.010;

use strict;
use warnings;

use POSIX ":sys_wait_h";
use Carp;
use Carp::Always;
use IPC::Open3;
use Data::Dumper qw( Dumper );

our $VERSION = '0.01';

my @modules_to_install = ();

my %installed_module_version = ();

my %modules_already_installed = ();
my %modules_need_to_install   = ();

my %modules_install_ok     = ();
my %modules_install_failed = ();

my %modules_install_not_found = (
'B' => undef,
'B::Asmdata' => undef,
'B::Assembler' => undef,
'B::Bblock' => undef,
'B::Bytecode' => undef,
'B::C' => undef,
'B::CC' => undef,
'B::Debug' => undef,
'B::Deobfuscate' => undef,
'B::Deparse' => undef,
'B::Disassembler' => undef,
'B::Lint' => undef,
'B::Showlex' => undef,
'B::Stash' => undef,
'B::Terse' => undef,
'B::Xref' => undef,
'only' => undef,
);

my $INSTALL_TIMEOUT_IN_SECONDS = 60*5;

sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s }
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s }
sub trim  { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }

sub say_helper_output
{
    my @args = @_;

    my $now = localtime;
    say '# ' . $now . ' # ' . join( '', @args );

    return;
}

sub _old_search_for_installed_modules
{
    %installed_module_version = ();

    my @output = `cmd.exe /c cpan -l`;
    @output = map { trim( $_ ) } @output;

    foreach my $line ( @output ) {
        if ( 'Loading internal logger. Log::Log4perl recommended for better logging' eq $line ) {
            next;
        }

        my @t = split /\s+/, $line;
        $installed_module_version{ $t[ 0 ] } =
            ( 'undef' eq $t[ 1 ] ? undef : $t[ 1 ] );
    }

    say_helper_output '';
    say_helper_output 'installed_module_version: '
        . scalar( keys %installed_module_version ) . "\n"
        . Dumper( \%installed_module_version );
    say_helper_output '';

    return;
}

sub _old_get_module_dependencies
{
    my ( $module ) = @_;

    my %dependencies = ();

    # --> Working on Perl::Critic
    # Fetching http://www.cpan.org/authors/id/P/PE/PETDANCE/Perl-Critic-1.140.tar.gz ... OK
    # Configuring Perl-Critic-1.140 ... OK
    # Module::Build~0.4204
    # ExtUtils::Install~1.46
    # Fatal

    my $now = localtime;
    say_helper_output 'get module dependencies - ' . $module;

    my @output = `cpanm --showdeps $module 2>&1`;

    if ( $? ) {
        if ( ( join '', @output ) =~ /Couldn't find module or a distribution/io ) {
            say_helper_output 'ERROR: module not found - ' . $module;
        }
        else {
            say_helper_output 'ERROR: search failed - exitcode - ' . $?;
        }
        return undef;    # not found
    }

    @output = map { trim( $_ ) } @output;

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

sub _old_simple_install_module
{
    my ( $module ) = @_;

    my $tried = module_already_tried( $module );
    if ( defined $tried ) {
        return $tried;
    }

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', $module );

    # update needs force
    if ( exists $installed_module_version{ $module } ) {
        say_helper_output 'update module - ' . $module;
    }
    else {
        say_helper_output 'install module - ' . $module;
    }

    say_helper_output 'cmd: ' . ( join ' ', @cmd );
    say_helper_output '';

    die "debug out";

    my $exitcode = system( @cmd );
    say_helper_output '';
    my $action = '';

    if ( $exitcode ) {
        $action = 'failed';

        add_module_to_failed( $module, undef );
    }
    else {
        $action = 'success';

        add_module_to_ok( $module, 999_999 );    # newest version - so real number not relevant.
    }

    say_helper_output 'install module - ' . $module . ' - ' . $action;

    print_install_state_summary();

    return $exitcode ? 1 : 0;
}

sub add_module_to_ok
{
    my ( $module, $version ) = @_;

    $modules_install_ok{ $module }       = undef;
    $installed_module_version{ $module } = $version;

    delete $modules_need_to_install{ $module };

    return;
}

sub add_module_to_failed
{
    my ( $module, $version ) = @_;

    $modules_install_failed{ $module } = $version;

    delete $modules_need_to_install{ $module };    # remove module - don't care if faile - no retry of failed

    return;
}


sub add_module_to_not_found
{
    my ( $module, $version ) = @_;

    $modules_install_not_found{ $module } = $version;

    delete $modules_need_to_install{ $module };    # remove module - don't care if faile - no retry of failed

    return;
}

sub print_install_state_summary
{
    say_helper_output '';
    say_helper_output 'modules_need_to_install left - ' . scalar( keys %modules_need_to_install );
    say_helper_output 'modules_install_ok: ' . scalar( keys %modules_install_ok );
    say_helper_output 'modules_install_not_found: ' . scalar( keys %modules_install_not_found ) . "\n" . Dumper( \%modules_install_not_found );
    say_helper_output 'modules_install_failed: ' . scalar( keys %modules_install_failed ) . "\n" . Dumper( \%modules_install_failed );
    say_helper_output '';

    return;
}

sub search_for_installed_modules
{
    %installed_module_version = ();

    my $chld_in  = undef;
    my $chld_out = undef;

    my @cmd = ( 'cmd.exe', '/c', 'cpan', '-l' );
    say_helper_output 'start cmd: ' . ( join ' ', @cmd );
    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );
    if ( 1 > $pid ) {
        say_helper_output 'ERROR: cmd start failed!';
    }
    else {
        say_helper_output 'pid: ' . $pid;

        say_helper_output 'close chld_in';
        close $chld_in;

        say_helper_output 'read output ... ';

        my $timeout_in_seconds = 60 * 1;

        local $@;
        my $eval_ok = eval {
            local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
            alarm $timeout_in_seconds;

            while ( my $line = <$chld_out> ) {
                $line = trim( $line );

                # say_helper_output 'STDOUT: ' . $line;
                my @t = split /\s+/, $line;
                $installed_module_version{ $t[ 0 ] } =
                    ( 'undef' eq $t[ 1 ] ? undef : $t[ 1 ] );
            }

            return 'eval_ok';

        };

        alarm 0; # disable

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
    %modules_already_installed = ();
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

        return undef;    # as >not found
    }

    say_helper_output 'pid: ' . $pid;

    say_helper_output 'close chld_in';
    close $chld_in;

    say_helper_output 'read output ... ';

    my @output = ();

    my $timeout_in_seconds = 60 * 1;

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $timeout_in_seconds;

        while ( my $line = <$chld_out> ) {
            $line = trim( $line );

            # say_helper_output 'STDOUT: ' . $line;
            push @output, $line;
        }

        return 'eval_ok';
    };

    alarm 0; # disable

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

sub _simple_install_module
{
    my ( $module ) = @_;

    my $tried = module_already_tried( $module );
    if ( defined $tried ) {
        return $tried;
    }

    #my @cmd = ( 'cmd.exe', '/c', 'cpanm', $module, '2>&1' );
    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '2>&1' );

    # update needs force
    if ( exists $installed_module_version{ $module } ) {
        say_helper_output 'update module - ' . $module;
    }
    else {
        say_helper_output 'install module - ' . $module;
    }

    say_helper_output 'start cmd: ' . ( join ' ', @cmd );
    say_helper_output '';

    my $chld_in  = undef;
    my $chld_out = undef;

    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );
    if ( 1 > $pid ) {
        say_helper_output 'install module - ' . $module . ' - process start failed';
        print_install_state_summary();
        return 1;
    }

    say_helper_output 'pid: ' . $pid;

    say_helper_output 'close chld_in';
    close $chld_in;

    say_helper_output 'read output ... ';
    my $child_exit_status = undef;

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $INSTALL_TIMEOUT_IN_SECONDS;

        while ( my $line = <$chld_out> ) {
            $line = trim( $line );

            say_helper_output 'STDOUT: ' . $line;
        }

        return 'eval_ok';
    };

    alarm 0; # disable

    if ( $@ ) {
        if ( "timeout_alarm\n" ne $@ ) {
            say_helper_output 'ERROR: unexpected error - ' - 0 + $@ - ' - ' . $@;

            $child_exit_status = 1;
            kill -9, $pid;    # kill
        }
        else {
            say_helper_output 'ERROR: timeout - ' - 0 + $@ - ' - ' . $@;

            $child_exit_status = 1;
            kill -9, $pid;    # kill
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        say_helper_output 'ERROR: eval failed ? - ' - 0 + $@ - ' - ' . $@;

        $child_exit_status = 1;
        kill -9, $pid;    # kill
    }
    else {
        say_helper_output 'close chld_out';
        close $chld_out;

        say_helper_output 'wait for exit...';

        # reap zombie and retrieve exit status
        waitpid( $pid, 0 );
        $child_exit_status = $? >> 8;
        say_helper_output '$child_exit_status: ' . $child_exit_status;
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

sub simple_install_module
{
    my ( $module ) = @_;

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

    my $timeout_time    = $INSTALL_TIMEOUT_IN_SECONDS + time;
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

sub import_module_list_from_data
{
    #
    # compensate that __DATA__ works slightly differen in main-scripts
    # than in inlcuded modules -> see https://perldoc.perl.org/perldata
    #
    my $data_found = 0;

    while (my $line = <DATA>) {
        $line = trim($line);
        if(!$line) {
        }
        elsif('__DATA__' eq $line) {
            $data_found = 1;
        }
        elsif($data_found) {
            push @modules_to_install, $line;
        }
    }

    close DATA;
}

sub main
{
    import_module_list_from_data();

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
    say_helper_output 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );
    say_helper_output '';
    say_helper_output 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );
    say_helper_output '';
    say_helper_output 'modules_install_ok: '
        . scalar( keys %modules_install_ok ) . "\n"
        . Dumper( \%modules_install_ok );
    say_helper_output '';

    return;
}

$| = 1;

say_helper_output "started $0";

main();

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

Copyright (c) 2022, Markus Demml

This library is free software; you can redistribute it and/or modify it
under the same terms as the Perl 5 programming language system itself.
The full text of this license can be found in the LICENSE file included
with this module.

=cut

__DATA__

Any::Moose
AnyDBM_File
App::Ack
App::Cpan
App::cpanminus
App::Kit
App::perlbrew
App::PerlCriticUtils
App::perlimports
App::perlvars
App::Smbxfer
App::Sqitch
Attribute::Handlers
Attribute::Lexical
Attribute::Types
AutoLoader
AutoSplit
B
B::Asmdata
B::Assembler
B::Bblock
B::Bytecode
B::C
B::CC
B::Debug
B::Deobfuscate
B::Deparse
B::Disassembler
B::Lint
B::Showlex
B::Stash
B::Terse
B::Xref
Benchmark
Benchmark::Forking
BerkeleyDB
BioPerl
Bit::Vector
Business::ISBN
ByteLoader
Cache::Mmap
Carp
Carp::Always
Carp::Assert
Carp::Assert::More
Carp::Notify
Carton
Catalyst
CGI
CGI::Simple
CGI_Lite
Class::Accessor
Class::Classless
Class::Contract
Class::Data::Inheritable
Class::DBI
Class::DBI::Loader
Class::DBI::Loader::Relationship
Class::Load
Class::MethodMaker
Class::MOP
Class::MOP::Attribute
Class::MOP::Class
Class::MOP::Method
Class::Multimethods
Class::Std
Class::Std::Utils
Class::Struct
Class::Tables
Clone::Any
Code::Statistics
Config
Config::General
Config::IniFiles
Config::JSON
Config::Scoped
Config::Std
Config::Tiny
ConfigReader::Simple
Const::Fast
Contextual::Return
CPAN
CPAN::Mini
CPAN::Mini::Inject
CPAN::Reporter
CPAN::Reporter::PrereqCheck
CPAN::Uploader
CPANPLUS
CPANPLUS::YACSmoke
criticism
Cwd
Dancer
Data::Alias
Data::Constraint
Data::Dump
Data::Dump::Streamer
Data::Dumper
Data::MessagePack
Data::Printer
DateTime
DB
DBD
DBD::AnyData
DBD::CSV
DBD::Gofer
DBD::Mock
DBD::SQLite
DBI
DBI::Profile
DBI::ProfileDumper
DBICx::TestDatabase
DBIx::Class
DBM::Deep
DBM_Filter
DB_File
Devel::Assert
Devel::CheckOS
Devel::Cover
Devel::Declare
Devel::DProf
Devel::ebug
Devel::EnforceEncapsulation
Devel::hdb
Devel::NYTProf
Devel::Peek
Devel::ptkdb
Devel::SelfStubber
Devel::Size
Devel::SmallProf
Devel::Trace
Device::SerialPort
diagnostics
Digest
Dist::Zilla
Dist::Zilla::Plugin::Test::Perl::Critic
Dist::Zilla::Plugin::Test::Perl::Critic::Subset
Distribution::Cooker
Dumbbench
DynaLoader
EMail
Email::Send::SMTP
Email::Simple
Email::Stuff
Encode
Encoding::FixLatin
English
Errno
Error
Exception::Class
Expect::Simple
Exporter
ExtUtils::Command
ExtUtils::Embed
ExtUtils::Install
ExtUtils::Installed
ExtUtils::Liblist
ExtUtils::MakeMaker
ExtUtils::Manifest
ExtUtils::MM_Any
ExtUtils::MM_Unix
ExtUtils::MM_Win32
Fatal
Fcntl
FFI::Platypus
File::Basename
File::chdir
File::CheckTree
File::chmod
File::Compare
File::Copy
File::DosGlob
File::Find
File::Find::Closures
File::Find::Rule
File::Finder
File::Glob
File::Path
File::pushd
File::Slurp
File::Slurper
File::Spec
File::Spec::Functions
File::stat
File::Temp
FileHandle
Filter::Macro
FindBin
Getopt::Attribute
Getopt::Declare
Getopt::Easy
Getopt::Euclid
Getopt::Long
Getopt::Lucid
Getopt::Mixed
Getopt::Std
Git::CPAN::Patch
Git::Critic
Gtk
Hash::AsObject
Hash::Util
Hook::LexWrap
HTML::Mason
HTML::Parser
HTML::TreeBuilder
HTTP::Date
HTTP::Recorder
HTTP::SimpleLinkChecker
HTTP::Size
Image::Info
Image::Magick
Image::Size
Imager
Inline
Inline::C
Inline::Java
IO::All
IO::Dir
IO::File
IO::Handle
IO::InSitu
IO::Interactive
IO::Null
IO::Pipe
IO::Poll
IO::Prompt
IO::Pty
IO::Scalar
IO::Seekable
IO::Select
IO::Socket
IO::Socket::INET
IO::Tee
IPC::Msg
IPC::Open2
IPC::Open3
IPC::Run
IPC::Semaphore
IPC::Shareable
IPC::SysV
JSON
JSON::Any
JSON::Syck
Lexical::Alias
lib::relative
List::Cycle
List::MoreUtils
List::Util
Log::Dispatch
Log::Log4perl
Log::Log4perl::Appender::DBI
Log::Log4perl::Appender::File
Log::Log4perl::Layout::PatternLayout
Log::StdLog
LWP
LWP::Simple
Mac::PropertyList
Mac::Speech
Mason
Math::BigFloat
Math::BigInt
Math::Complex
Math::Trig
Memoize
Method::Signatures
MIDI
Modern::Perl
ModPerl::PerlRun
Module::Build
Module::Build::TestReporter
Module::CoreList
Module::Info::File
Module::License::Report
Module::Pluggable
Module::Release
Module::Signature
Module::Starter
Module::Starter::AddModule
Module::Starter::PBP
Mojolicious
Monkey::Patch
Moo
Moops
Moose
Moose::Exporter
Moose::Manual
Moose::Role
Moose::Util::TypeConstraints
MooseX::Declare
MooseX::MultiMethods
MooseX::Params::Validate
MooseX::Types
Mutex
namespace::autoclean
NDBM_File
Net::FTP
Net::hostent
Net::MAC::Vendor
Net::netent
Net::Ping
Net::protoent
Net::servent
Net::SMTP
Net::SMTP::SSL
NEXT
Object::Iterate
only
Opcode
Package::Stash
PadWalker
Params::Validate
Params::ValidationCompiler
Parse::RecDescent
Path::Class
Path::Class::Dir
Path::Class::File
Path::This
PDL
Perl6::Builtins
Perl6::Export::Attrs
Perl6::Form
Perl6::Rules
Perl6::Slurp
Perl::Critic
Perl::Critic::Bangs
Perl::Critic::CognitiveComplexity
Perl::Critic::Community
Perl::Critic::Compatibility
Perl::Critic::Deprecated
Perl::Critic::Dynamic
Perl::Critic::Itch
Perl::Critic::Lax
Perl::Critic::Mardem
Perl::Critic::Moose
Perl::Critic::More
Perl::Critic::Nits
Perl::Critic::PetPeeves::JTRAMMELL
Perl::Critic::Policy
Perl::Critic::Policy::BadStrings
Perl::Critic::Policy::BuiltinFunctions::ProhibitReturnOr
Perl::Critic::Policy::Catalyst::ProhibitUnreachableCode
Perl::Critic::Policy::CodeLayout::ProhibitSpaceIndentation
Perl::Critic::Policy::CodeLayout::TabIndentSpaceAlign
Perl::Critic::Policy::CompileTime
Perl::Critic::Policy::Documentation::RequirePod
Perl::Critic::Policy::Dynamic::NoIndirect
Perl::Critic::Policy::logicLAB::ProhibitUseLib
Perl::Critic::Policy::logicLAB::RequirePackageNamePattern
Perl::Critic::Policy::logicLAB::RequireParamsValidate
Perl::Critic::Policy::logicLAB::RequireSheBang
Perl::Critic::Policy::logicLAB::RequireVersionFormat
Perl::Critic::Policy::Modules::ProhibitUseLib
Perl::Critic::Policy::ProhibitImplicitImport
Perl::Critic::Policy::ProhibitOrReturn
Perl::Critic::Policy::ProhibitSmartmatch
Perl::Critic::Policy::References::ProhibitComplexDoubleSigils
Perl::Critic::Policy::RegularExpressions::RequireDefault
Perl::Critic::Policy::Variables::NameReuse
Perl::Critic::Policy::Variables::ProhibitLoopOnHash
Perl::Critic::Policy::Variables::ProhibitUnusedVarsStricter
Perl::Critic::Policy::Variables::RequireHungarianNotation
Perl::Critic::Pulp
Perl::Critic::RENEEB
Perl::Critic::Storable
Perl::Critic::StricterSubs
Perl::Critic::Swift
Perl::Critic::Tics
Perl::Critic::TooMuchCode
Perl::Lint
Perl::Metrics::Lite
Perl::Metrics::Simple
Perl::Tidy
Plack
Pod::Checker
Pod::Coverage
Pod::Functions
Pod::Html
Pod::Man
Pod::Parser
Pod::Perldoc
Pod::Perldoc::BaseTo
Pod::Perldoc::ToRtf
Pod::Perldoc::ToText
Pod::Perldoc::ToToc
Pod::PseudoPod
Pod::Select
Pod::Simple
Pod::Simple::Subclassing
Pod::Spell
Pod::Text
Pod::Text::Termcap
Pod::TOC
Pod::Usage
Pod::Webserver
POE
POE::Component::CPAN::YACSmoke
POSIX
PPI
Readonly
ReadonlyX
Regexp::Assemble
Regexp::Common
Regexp::Debugger
Regexp::English
Regexp::MatchContext
Regexp::Trie
ReturnValue
Role::Tiny
Safe
Scalar::Util
SelfLoader
Sereal
Sereal::Decoder
Sereal::Encoder
Smart::Comments
SmokeRunner::Multi
Socket
Sort::Maker
Spreadsheet::ParseExcel
Spreadsheet::WriteExcel
SQL
SQLite::DB
Storable
String::Util
Sub::Exporter
Sub::Identify
Sub::Install
Sub::Installer
Sub::Name
Surveyor::App
Surveyor::Benchmark::GetDirectoryListing
Sx
Symbol
Sys::Hostname
Sys::Syslog
Taint::Util
TAP::Harness
Task::Kensho
Task::Perl::Critic
Template
Template::Base
Template::Exception
Template::Toolkit
Term::ANSIColor
Term::ANSIScreen
Term::Cap
Term::Complete
Term::Completion
Term::ReadKey
Term::ReadLine
Term::Rendezvous
Test
Test2::Tools::PerlCritic
Test2::Util
Test::Builder
Test::Builder::Tester
Test::Builder::Tester::Color
Test::CheckManifest
Test::Class
Test::Cmd
Test::Cmd::Common
Test::Database
Test::DatabaseRow
Test::Deep
Test::Differences
Test::Exception
Test::Expect
Test::Fatal
Test::File
Test::Harness
Test::Harness::Straps
Test::HTML::Lint
Test::HTML::Tidy
Test::Inline
Test::Kwalitee
Test::LongString
Test::Manifest
Test::Memory::Cycle
Test::MockDBI
Test::MockModule
Test::MockObject
Test::MockObject::Extends
Test::Mojibake
Test::More
Test::Most
Test::NoWarnings
Test::Number::Delta
Test::Output
Test::Perl::Critic
Test::Perl::Critic::Git
Test::Perl::Critic::Progressive
Test::Perl::Critic::XTFiles
Test::Perl::Metrics::Lite
Test::PerlTidy
Test::Pod
Test::Pod::Coverage
Test::Reporter
Test::Routine
Test::Signature
Test::Simple
Test::Spelling
Test::Taint
Test::Tutorial
Test::Vars
Test::Warn
Test::WWW::Mechanize
Test::WWW::Mechanize::PSGI
Test::XT
Text::Abbrev
Text::Autoformat
Text::CSV
Text::CSV::Simple
Text::CSV_XS
Text::ParseWords
Text::Template
Text::Template::Simple::IO
Text::Trim
Text::Wrap
Thread
Thread::Queue
Thread::Semaphore
Thread::Signal
Throwable::Error
Tie::Array
Tie::Array::PackedC
Tie::BoundedInteger
Tie::Counter
Tie::Cycle
Tie::Cycle::Sinewave
Tie::DBI
Tie::File
Tie::Handle
Tie::Hash
Tie::Persistent
Tie::RefHash
Tie::Scalar
Tie::SecureHash
Tie::StdArray
Tie::STDERR
Tie::StdHash
Tie::StdScalar
Tie::SubstrHash
Tie::Syslog
Tie::TextDir
Tie::Timely
Tie::TransactHash
Tie::VecArray
Tie::Watch
Time::gmtime
Time::HiRes
Time::Local
Time::localtime
Time::tm
Tk
Try::Tiny
TryCatch
underscore
Unicode::CharName
Unicode::Collate
UNIVERSAL
User::grent
User::pwent
Vim::Debug
WeakRef
Win32
Win32::ChangeNotify
Win32::Console
Win32::Console::ANSI
Win32::Event
Win32::EventLog
Win32::FileSecurity
Win32::Internet
Win32::IPC
Win32::NetAdmin
Win32::NetResource
Win32::ODBC
Win32::OLE
Win32::OLE::Const
Win32::OLE::Enum
Win32::OLE::NLS
Win32::OLE::Variant
Win32::PerfLib
Win32::Pipe
Win32::Process
Win32::Registry
Win32::Semaphore
Win32::Service
Win32::Sound
Win32::TieRegistry
Win32API::File
Win32API::Net
Win32API::Registry
WWW::Mechanize
XML
XML::Compile
XML::Parser
XML::Rabbit
XML::Twig
XSLoader
XT::Files
YAML
YAML::LibYAML
YAML::Syck
YAML::Tiny
YAML::XS
