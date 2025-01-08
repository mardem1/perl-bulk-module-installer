use utf8;

use 5.010;

use strict;
use warnings;

use version;
use POSIX qw( :sys_wait_h );
use Carp  qw( croak );
use Carp::Always;
use IPC::Open3;
use Data::Dumper   qw( Dumper );
use List::Util     qw( shuffle );
use Cwd            qw( abs_path );
use File::Basename qw( dirname );

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
my %modules_need_to_update  = ();

my %modules_install_already = ();
my %modules_install_ok      = ();
my %modules_install_failed  = ();

my %modules_install_not_found = ();

my %modules_install_dont_try = ();

my $INSTALL_MODULE_TIMEOUT_IN_SECONDS               = 60 * 10;
my $CHECK_UPDATE_MODULE_TIMEOUT_IN_SECONDS          = 60 * 2;
my $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS = 60 * 2;
my $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS = 60 * 2;

my $EMPTY_STRING = q{};
my $FALSE        = !!0;
my $TRUE         = !0;

my $module_list_filepath = $EMPTY_STRING;
my $log_dir_path         = $EMPTY_STRING;

sub _trim
{
    my ( $s ) = @_;

    $s //= $EMPTY_STRING;
    $s =~ s/^\s+|\s+$//g;

    return $s;
}

sub _str_replace
{
    my ( $string, $search, $replace ) = @_;

    $string =~ s/$search/$replace/g;

    return $string;
}

sub _module_name_for_fs
{
    my ( $module ) = @_;

    my $module_n = _str_replace( $module, '::', '_' );

    return $module_n;
}

sub _get_log_line
{
    my @args = @_;

    my $line = $EMPTY_STRING;

    my $now = _get_timestamp_for_logline();

    $line = '# ' . $now . ' # ' . join( '', @args );

    return $line;
}

sub _say_ex
{
    my @args = @_;

    my $line = _get_log_line( @args );

    say $line;

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

sub _get_timestamp_for_logline
{
    my @local = ( localtime )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d_%H-%M-%S', @local );

    return $now;
}

sub _get_timestamp_pretty
{
    my @local = ( localtime )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d - %H-%M-%S', @local );

    return $now;
}

sub _get_timestamp_for_filename
{
    my @local = ( localtime )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y%m%d_%H%M%S', @local );

    return $now;
}

sub _read_file
{
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    if ( !( -e -f -r -s $filepath ) ) {
        _say_ex "ERROR: filepath '$filepath' - not exists, readable or empty";
        croak "filepath '$filepath' - not exists, readable or empty";
    }

    _say_ex "read modules from file '$filepath'";

    my $fh = undef;
    if ( !open( $fh, '<', $filepath ) ) {
        _say_ex "ERROR: Couldn't open file-read '$filepath'";
        _say_ex 'ERROR: start $! ->';
        _say_ex '';
        _say_ex "$!";
        _say_ex '';
        _say_ex 'ERROR: <- $! ended';
        croak "Couldn't open file-read '$filepath'";
    }

    local $/;
    $/ = "\n";    # force linux line ends

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
        _say_ex "ERROR: Couldn't open file-write '$filepath'";
        _say_ex 'ERROR: start $! ->';
        _say_ex '';
        _say_ex "$!";
        _say_ex '';
        _say_ex 'ERROR: <- $! ended';
        croak "Couldn't open file-write '$filepath'";
    }

    say { $fh } $header;
    say { $fh } '';
    say { $fh } '';
    foreach my $line ( @content ) {
        say { $fh } $line;
    }
    say { $fh } '';

    close( $fh );
    $fh = undef;

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
            _say_ex 'ERROR: unexpected error';
            _say_ex 'ERROR: start $@ ->';
            _say_ex '';
            _say_ex '' . 0 + $@;
            _say_ex '';
            _say_ex "$@";
            _say_ex '';
            _say_ex 'ERROR: <- $@ ended';
            kill -9, $pid;    # kill
        }
        else {
            _say_ex 'ERROR: timeout';
            _say_ex 'ERROR: start $@ ->';
            _say_ex '';
            _say_ex '' . 0 + $@;
            _say_ex '';
            _say_ex "$@";
            _say_ex '';
            _say_ex 'ERROR: <- $@ ended';
            kill -9, $pid;    # kill
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        _say_ex 'ERROR: eval failed';
        _say_ex 'ERROR: start $@ ->';
        _say_ex '';
        _say_ex '' . 0 + $@;
        _say_ex '';
        _say_ex "$@";
        _say_ex '';
        _say_ex 'ERROR: <- $@ ended';
        kill -9, $pid;    # kill
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

    _say_ex 'remove ', $module, ' from $modules_need_to_update';
    delete $modules_need_to_update{ $module };

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

    if ( exists $modules_install_dont_try{ $module } ) {
        _say_ex 'module ', $module, ' marked as dont try - so dont add to failed!';
    }
    else {
        _say_ex 'add ', $module, ' to modules_install_failed';
        $modules_install_failed{ $module } = $version;
    }

    _say_ex 'remove ', $module, ' from modules_need_to_install';
    delete $modules_need_to_install{ $module };    # remove module - don't care if failed - no retry of failed

    _say_ex 'remove ', $module, ' from $modules_need_to_update';
    delete $modules_need_to_update{ $module };

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

    _say_ex 'remove ', $module, ' from $modules_need_to_update';
    delete $modules_need_to_update{ $module };

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

sub was_module_already_tried
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( exists $modules_install_dont_try{ $module } ) {
        mark_module_as_failed( $module );
        _say_ex 'WARN: install module - ' . $module . ' - marked dont try - abort';

        return 1;
    }

    if ( exists $modules_install_ok{ $module } ) {
        mark_module_as_ok( $module );
        _say_ex 'WARN: install module - ' . $module . ' - already ok - abort';

        return 0;
    }

    if ( exists $modules_install_failed{ $module } ) {
        mark_module_as_failed( $module );
        _say_ex 'WARN: install module - ' . $module . ' - already failed - abort';

        return 1;
    }

    if ( exists $modules_install_not_found{ $module } ) {
        mark_module_as_not_found( $module );
        _say_ex 'WARN: install module - ' . $module . ' - already mot found - abort';

        return 1;
    }

    return undef;
}

sub reduce_modules_to_install
{
    foreach my $module ( keys %modules_to_install ) {
        if ( exists $installed_module_version{ $module } ) {
            $modules_install_already{ $module } = undef;
        }
        elsif (exists $modules_install_dont_try{ $module }
            || exists $modules_install_ok{ $module }
            || exists $modules_install_failed{ $module }
            || exists $modules_install_not_found{ $module }
            || exists $modules_need_to_install{ $module } )
        {
            # already marked somewhere - ignore
        }
        else {
            $modules_need_to_install{ $module } = undef;
        }
    }

    my $timestamp = _get_timestamp_for_filename();

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_already.log',
        'modules_install_already: ' . scalar( keys %modules_install_already ),
        Dumper( \%modules_install_already ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );

    _say_ex '';
    _say_ex 'modules_install_already: '
        . scalar( keys %modules_install_already ) . "\n"
        . Dumper( \%modules_install_already );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );
    _say_ex '';

    return;
}

sub print_install_state_summary
{
    foreach ( 1 .. 10 ) {
        _say_ex '';
    }

    _say_ex 'print_install_state_summary';
    _say_ex '';
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

sub dump_state_to_logfiles
{
    if ( _is_string_empty( $log_dir_path ) ) {
        croak 'param filepath empty!';
    }

    my $timestamp = _get_timestamp_for_filename();

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_to_install_with_deps_extended.log',
        'modules_to_install_with_deps_extended: ' . scalar( keys %modules_to_install_with_deps_extended ),
        Dumper( \%modules_to_install_with_deps_extended ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_dont_try.log',
        'modules_install_dont_try: ' . scalar( keys %modules_install_dont_try ),
        Dumper( \%modules_install_dont_try ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_already.log',
        'modules_install_already: ' . scalar( keys %modules_install_already ),
        Dumper( \%modules_install_already ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_ok.log',
        'modules_install_ok: ' . scalar( keys %modules_install_ok ),
        Dumper( \%modules_install_ok ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_not_found.log',
        'modules_install_not_found: ' . scalar( keys %modules_install_not_found ),
        Dumper( \%modules_install_not_found ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_failed.log',
        'modules_install_failed: ' . scalar( keys %modules_install_failed ),
        Dumper( \%modules_install_failed ),
    );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );

    return;
}

sub print_install_end_summary
{
    foreach ( 1 .. 10 ) {
        _say_ex '';
    }
    _say_ex 'summary';
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_to_install_with_deps_extended: '
        . scalar( keys %modules_to_install_with_deps_extended ) . "\n"
        . Dumper( \%modules_to_install_with_deps_extended );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_already: '
        . scalar( keys %modules_install_already ) . "\n"
        . Dumper( \%modules_install_already );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_ok: ' . scalar( keys %modules_install_ok ) . "\n" . Dumper( \%modules_install_ok );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_not_found: '
        . scalar( keys %modules_install_not_found ) . "\n"
        . Dumper( \%modules_install_not_found );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );
    _say_ex '';

    _say_ex '';
    _say_ex 'modules_need_to_install: '
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );
    _say_ex '';

    return;
}

sub search_for_installed_modules
{
    my @cmd = ( 'cmd.exe', '/c', 'cpan', '-l' );

    my $timestamp  = _get_timestamp_for_filename();
    my $time_start = _get_timestamp_pretty();

    my ( $child_exit_status, @output ) =
        _get_output_with_detached_execute( $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS, 1, @cmd );

    my $time_end = _get_timestamp_pretty();

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'installed_modules_found.log',
        'installed_modules_found',
        'CMD: ' . ( join ' ', @cmd ),
        'ExitCode: ' . $child_exit_status,
        'Started: ' . $time_start,
        'Ended: ' . $time_end,
        '',
        '=' x 80,
        '',
        @output,
        '',
    );

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

    _say_ex 'get module dependencies - ' . $module;

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--no-interactive', '--showdeps', $module, '2>&1' );

    my $timestamp  = _get_timestamp_for_filename();
    my $time_start = _get_timestamp_pretty();

    my ( $child_exit_status, @output ) = ();

    if ( $module eq 'Test::Smoke' ) {
        $child_exit_status = 0;
        @output            = ();
    }
    else {
        ( $child_exit_status, @output ) =
            _get_output_with_detached_execute( $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS, 1, @cmd );
    }

    my $time_end = _get_timestamp_pretty();

    if ( !defined $child_exit_status ) {
        return undef;    # as not found
    }

    if ( $child_exit_status && !@output ) {
        _say_ex 'ERROR: search failed - exitcode - ' . $child_exit_status;
        return undef;    # as not found
    }

    my $module_n = _module_name_for_fs( $module );

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'fetch_dependency__' . $module_n . '.log',
        'fetch_dependency ' . $module,
        'CMD: ' . ( join ' ', @cmd ),
        'ExitCode: ' . $child_exit_status,
        'Started: ' . $time_start,
        'Ended: ' . $time_end,
        '',
        '=' x 80,
        '',
        @output,
        ''
    );

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
            && $_ !~ /Expiring \d+ work directories[.] This might take a while/o
            && $_ !~ /^[a-z\d]+$/o
            && $_ !~ /^[a-z\d]+~\d+$/o
            && $_ !~ /^[a-z\d]+~\d+\..+$/o
# CPAN::Meta::YAML found a duplicate key 'no_index' in line '' at [...] \perl\site\bin/cpanm line 194.
# Couldn't read chunk at offset unknown at [...] \perl\site\bin/cpanm line 119.
# Couldn't read chunk at offset unknown at [...] \perl\site\bin/cpanm line 119. on cpanmetadb failed.
# Couldn't read chunk at offset unknown at [...] \perl\site\bin/cpanm line 119. () on mirror http://www.cpan.org failed.
# Couldn't find module or a distribution Couldn't read chunk at offset unknown at [...] \perl\site\bin/cpanm line 119.
# Invalid header block at offset unknown at [...] \perl\site\bin/cpanm line 119.
            && $_ !~ /^.+ at .+[\\\/]perl[\\\/]site[\\\/]bin[\\\/]cpanm line \d+.*$/o
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
            local $@;
            eval {
                my $installed_version = version->parse( $installed_module_version{ $module } );
                my $dependent_version = version->parse( $dependencies{ $module } );

                if ( ( $dependent_version cmp $installed_version ) == 1 ) {
                    _say_ex 'dependency old version - update needed: ' . $module;
                    $not_installed{ $module } = $dependencies{ $module };    # to old version
                }
                else {
                    _say_ex 'dependency installed and version check done: ' . $module;
                }
            };
            if ( $@ ) {
                _say_ex 'ERROR: dependency and version check failed for module: ' . $module;
                _say_ex 'ERROR: start $@ ->';
                _say_ex '';
                _say_ex "$@";
                _say_ex '';
                _say_ex 'ERROR: <- $@ ended';
                _say_ex 'dependency - unknown handle as needed: ' . $module;
                $not_installed{ $module } = $dependencies{ $module };
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

    foreach my $dep_module ( sort keys %dep ) {
        # only here - not at entry and every return.
        $recursion++;
        add_dependency_module_if_needed( $dep_module );
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

    my $module_n = _module_name_for_fs( $module );

    my $type = 'install';
    if ( exists $installed_module_version{ $module } ) {
        $type = 'update';
    }

    _say_ex $type . ' module - ' . $module;

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '2>&1' );

    my $timestamp  = _get_timestamp_for_filename();
    my $time_start = _get_timestamp_pretty();

    my ( $child_exit_status, @output ) =
        _get_output_with_detached_execute( $INSTALL_MODULE_TIMEOUT_IN_SECONDS, 1, @cmd );

    my $time_end = _get_timestamp_pretty();

    my $action = $type;
    if ( !defined $child_exit_status ) {
        $child_exit_status = 1;

        $action .= '-failed-start';
        mark_module_as_failed( $module, undef );
    }
    elsif ( $child_exit_status ) {
        $child_exit_status = 1;

        $action .= '-failed';
        mark_module_as_failed( $module, undef );
    }
    else {
        $child_exit_status = 0;

        $action .= '-success';
        mark_module_as_ok( $module, 999_999 );    # newest version - so real number not relevant.
    }

    _say_ex 'install module - ' . $module . ' - ' . $action;
    print_install_state_summary();

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'install_module__' . $module_n . '__' . $action . '.log',
        'install_module ' . $module,
        'CMD: ' . ( join ' ', @cmd ),
        'ExitCode: ' . $child_exit_status,
        'Started: ' . $time_start,
        'Ended: ' . $time_end,
        '',
        '=' x 80,
        '',
        @output,
        ''
    );

    return $child_exit_status;
}

sub import_module_list_from_file
{
    my $filepath = $module_list_filepath;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    my @file_lines = _read_file( $filepath );

    @file_lines = map  { _trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ } @file_lines;

    %modules_to_install = _hashify @file_lines;
    @file_lines         = ();

    _say_ex '';
    _say_ex 'wanted modules to install: ' . ( scalar keys %modules_to_install ) . "\n" . Dumper( \%modules_to_install );
    _say_ex '';

    my $timestamp = _get_timestamp_for_filename();

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_to_install_from_file.log',
        'modules_to_install_from_file: ' . scalar( keys %modules_to_install ),
        Dumper( \%modules_to_install ),
    );

    return;
}

sub print_perl_detail_info
{
    my @cmd = ( 'cmd.exe', '/c', 'perl', '-V' );

    my $timestamp  = _get_timestamp_for_filename();
    my $time_start = _get_timestamp_pretty();

    my ( $child_exit_status, @output ) =
        _get_output_with_detached_execute( $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS, 1, @cmd );

    my $time_end = _get_timestamp_pretty();

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'perl_detail_info.log',
        'perl_detail_info',
        'CMD: ' . ( join ' ', @cmd ),
        'ExitCode: ' . $child_exit_status,
        'Started: ' . $time_start,
        'Ended: ' . $time_end,
        '',
        '=' x 80,
        '',
        @output,
        '',
    );

    return;
}

sub install_module_dep_version
{
    my ( $module ) = @_;

    if ( _is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    _say_ex '' foreach ( 1 .. 25 );
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

sub search_for_modules_for_available_updates
{
    my @cmd = ( 'cmd.exe', '/c', 'cpan-outdated', '--exclude-core', '-p' );

    my $timestamp  = _get_timestamp_for_filename();
    my $time_start = _get_timestamp_pretty();

    my ( $child_exit_status, @output ) =
        _get_output_with_detached_execute( $CHECK_UPDATE_MODULE_TIMEOUT_IN_SECONDS, 1, @cmd );

    my $time_end = _get_timestamp_pretty();

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_with_available_updates.log',
        'modules_with_available_updates',
        'CMD: ' . ( join ' ', @cmd ),
        'ExitCode: ' . $child_exit_status,
        'Started: ' . $time_start,
        'Ended: ' . $time_end,
        '',
        '=' x 80,
        '',
        @output,
        '',
    );

    foreach my $module ( @output ) {
        $modules_need_to_update{ $module } = undef;
    }

    _say_ex '';
    _say_ex 'modules_need_to_update: '
        . scalar( keys %modules_need_to_update ) . "\n"
        . Dumper( \%modules_need_to_update );
    _say_ex '';

    _say_ex 'add all update modules to dependency-module-list with no dependency';
    foreach my $module ( keys %modules_need_to_update ) {
        if ( !exists $modules_to_install_with_deps_extended{ $module } ) {
            _say_ex 'module - ' . $module . ' - not in dep-list add';
            $modules_to_install_with_deps_extended{ $module } = {};
        }

        if ( !exists $modules_need_to_install{ $module } ) {
            _say_ex 'module - ' . $module . ' - not in to-install-list add';
            $modules_need_to_install{ $module } = {};
        }
    }

    print_install_state_summary();

    return;
}

sub main
{
    my ( $arg1, $arg2 ) = @_;

    my $filepath = undef;

    my $only_updates = $FALSE;
    my $no_updates   = $FALSE;

    if ( $arg1 eq '--only-updates' ) {
        $only_updates = $TRUE;
        $filepath     = $arg2;
    }
    elsif ( $arg1 eq '--no-updates' ) {
        $no_updates = $TRUE;
        $filepath   = $arg2;
    }
    elsif ( !_is_string_empty( $arg1 ) && !_is_string_empty( $arg2 ) ) {
        croak 'wrong parameter set';
    }
    else {
        $filepath = $arg1;
    }

    $filepath = _trim( $filepath );
    if ( _is_string_empty( $filepath ) ) {
        croak 'no file arg given';
    }

    $module_list_filepath = $filepath;

    my $logdir = dirname( __FILE__ ) . '/log';
    $log_dir_path = abs_path( $logdir );

    if ( _is_string_empty( $log_dir_path ) ) {
        croak "logdir '$logdir' not found";
    }

    if ( !-d $log_dir_path ) {
        croak "logdir '$log_dir_path' not found";
    }

    print_perl_detail_info();

    if ( $only_updates ) {
        _say_ex 'only-updates: skip module list file import';
    }
    else {
        import_module_list_from_file();
    }

    search_for_installed_modules();

    reduce_modules_to_install();    # updates should be handled another time ...

    add_dependency_modules_for_modules_need_to_install();

    if ( $no_updates ) {
        _say_ex 'no-updates: skip update module list import';
    }
    else {
        search_for_modules_for_available_updates();
    }

    dump_state_to_logfiles();

    print_install_state_summary();

    install_modules_dep_version();

    print_install_end_summary();

    dump_state_to_logfiles();

    return;
}

# mark modules as failed, some to old to build, other not for windows ...
%modules_install_dont_try = (
    'Acme::Spork'                                           => undef,
    'AnyData'                                               => undef,
    'AnyEvent'                                              => undef,
    'AnyEvent::HTTP'                                        => undef,
    'Apache2::Authen::OdinAuth'                             => undef,
    'Apache2::AuthzCaps'                                    => undef,
    'Apache2::CondProxy'                                    => undef,
    'Apache2::EmbedFLV'                                     => undef,
    'Apache2::reCaptcha'                                    => undef,
    'Apache2::UserDirAuthz'                                 => undef,
    'Apache::Admin::Config'                                 => undef,
    'Apache::App::Mercury'                                  => undef,
    'Apache::ASP'                                           => undef,
    'Apache::AuthLDAP'                                      => undef,
    'Apache::AuthPerLDAP'                                   => undef,
    'Apache::AuthPOP3'                                      => undef,
    'Apache::AuthTkt'                                       => undef,
    'Apache::AxKit::Provider::RDBMS'                        => undef,
    'Apache::BabyConnect'                                   => undef,
    'Apache::BalancerManager'                               => undef,
    'Apache::Bootstrap'                                     => undef,
    'Apache::Constants'                                     => undef,
    'Apache::DB'                                            => undef,
    'Apache::DBI'                                           => undef,
    'Apache::DebugLog'                                      => undef,
    'Apache::Description'                                   => undef,
    'Apache::Dir'                                           => undef,
    'Apache::EmbeddedPerl::Lite'                            => undef,
    'Apache::Emulator'                                      => undef,
    'Apache::FakeCookie'                                    => undef,
    'Apache::FakeTable'                                     => undef,
    'Apache::GDGraph'                                       => undef,
    'Apache::HeavyCGI'                                      => undef,
    'Apache::Htgroup'                                       => undef,
    'Apache::Htpasswd'                                      => undef,
    'Apache::Htpasswd::Perishable'                          => undef,
    'Apache::ImageMagick'                                   => undef,
    'Apache::ImgIndex'                                      => undef,
    'Apache::Keywords'                                      => undef,
    'Apache::Log::Parser'                                   => undef,
    'Apache::LogF'                                          => undef,
    'Apache::LogFormat::Compiler'                           => undef,
    'Apache::LogIgnore'                                     => undef,
    'Apache::Logmonster'                                    => undef,
    'Apache::LogRegex'                                      => undef,
    'Apache::MSIISProbes'                                   => undef,
    'Apache::OWA'                                           => undef,
    'Apache::Perldoc'                                       => undef,
    'Apache::PHLogin'                                       => undef,
    'Apache::Pod'                                           => undef,
    'Apache::PrettyText'                                    => undef,
    'Apache::ProxyPass'                                     => undef,
    'Apache::Request::Redirect'                             => undef,
    'Apache::Scriptor'                                      => undef,
    'Apache::Scriptor::Simple'                              => undef,
    'Apache::Session'                                       => undef,
    'Apache::Session::Browseable'                           => undef,
    'Apache::Session::CacheAny'                             => undef,
    'Apache::Session::Counted'                              => undef,
    'Apache::Session::Generate::AutoIncrement'              => undef,
    'Apache::Session::Lazy'                                 => undef,
    'Apache::Session::LDAP'                                 => undef,
    'Apache::Session::NoSQL'                                => undef,
    'Apache::Session::PHP'                                  => undef,
    'Apache::Session::Serialize::Dumper'                    => undef,
    'Apache::Session::Serialize::SOAPEnvelope'              => undef,
    'Apache::Session::Serialize::YAML'                      => undef,
    'Apache::Session::SQLite'                               => undef,
    'Apache::Session::SQLite3'                              => undef,
    'Apache::Session::Wrapper'                              => undef,
    'Apache::SimpleReplace'                                 => undef,
    'Apache::SiteConfig'                                    => undef,
    'Apache::Sling'                                         => undef,
    'Apache::SMTP'                                          => undef,
    'Apache::Solr'                                          => undef,
    'Apache::StrReplace'                                    => undef,
    'Apache::Sybase::CTlib'                                 => undef,
    'Apache::Test'                                          => undef,
    'Apache::TieBucketBrigade'                              => undef,
    'Apache::TransLDAP'                                     => undef,
    'Apache::TS::AdminClient'                               => undef,
    'Apache::WebSNMP'                                       => undef,
    'ApacheLog::Compressor'                                 => undef,
    'ApacheMysql'                                           => undef,
    'App::Kit'                                              => undef,
    'App::perlbrew'                                         => undef,
    'App::PerlCriticUtils'                                  => undef,
    'App::Smbxfer'                                          => undef,
    'App::Sqitch'                                           => undef,
    'Archive::Any::Create'                                  => undef,
    'Archive::Any::Create::Zip'                             => undef,
    'Attean'                                                => undef,
    'B'                                                     => undef,
    'B::Asmdata'                                            => undef,
    'B::Assembler'                                          => undef,
    'B::Bblock'                                             => undef,
    'B::Bytecode'                                           => undef,
    'B::C'                                                  => undef,
    'B::CC'                                                 => undef,
    'B::Debug'                                              => undef,
    'B::Deobfuscate'                                        => undef,
    'B::Deparse'                                            => undef,
    'B::Disassembler'                                       => undef,
    'B::Lint'                                               => undef,
    'B::Showlex'                                            => undef,
    'B::Stash'                                              => undef,
    'B::Terse'                                              => undef,
    'B::Xref'                                               => undef,
    'Benchmark::Forking'                                    => undef,
    'BerkeleyDB'                                            => undef,
    'ByteLoader'                                            => undef,
    'Cache::Mmap'                                           => undef,
    'Carp::Ensure'                                          => undef,
    'Carp::POE'                                             => undef,
    'Carp::REPL'                                            => undef,
    'Catalyst::Authentication::Credential::HTTP'            => undef,
    'CatalystX::REPL'                                       => undef,
    'CGI_Lite'                                              => undef,
    'CHI'                                                   => undef,
    'Code::Statistics'                                      => undef,
    'Code::TidyAll'                                         => undef,
    'Color::Conversions'                                    => undef,
    'Config::JSON'                                          => undef,
    'CPAN::Checksums'                                       => undef,
    'CPAN::Mini::Inject'                                    => undef,
    'CPAN::YACSmoke'                                        => undef,
    'Crypt::CBC'                                            => undef,
    'Crypt::OpenSSL::CA'                                    => undef,
    'Crypt::PBKDF2'                                         => undef,
    'Crypt::Random'                                         => undef,
    'Curses'                                                => undef,
    'Data::Fake'                                            => undef,
    'Data::Fake::Names'                                     => undef,
    'Data::Sah'                                             => undef,
    'Data::Sah::Coerce'                                     => undef,
    'Data::Sah::CoerceCommon'                               => undef,
    'Data::Sah::Compiler::perl::TH::any'                    => undef,
    'Data::Sah::Compiler::perl::TH::array'                  => undef,
    'Data::Sah::Compiler::perl::TH::bool'                   => undef,
    'Data::Sah::Compiler::perl::TH::hash'                   => undef,
    'Data::Sah::Compiler::perl::TH::int'                    => undef,
    'Data::Sah::Compiler::perl::TH::obj'                    => undef,
    'Data::Sah::Compiler::perl::TH::str'                    => undef,
    'Data::Sah::DefaultValueCommon'                         => undef,
    'Data::Sah::Filter'                                     => undef,
    'Data::Sah::Filter::perl::Perl::normalize_perl_modname' => undef,
    'Data::Sah::FilterCommon'                               => undef,
    'Data::Sah::Type::array'                                => undef,
    'Data::Sah::Type::hash'                                 => undef,
    'Data::Sah::Type::int'                                  => undef,
    'DBD'                                                   => undef,
    'DBD::AnyData'                                          => undef,
    'DBD::mysql'                                            => undef,
    'DBD::Oracle'                                           => undef,
    'DBD::Pg'                                               => undef,
    'Devel::Cover::Report::Clover'                          => undef,
    'Devel::DProf'                                          => undef,
    'Devel::SmallProf'                                      => undef,
    'Device::SerialPort'                                    => undef,
    'Dist::Metadata'                                        => undef,
    'Distribution::Cooker'                                  => undef,
    'EMail'                                                 => undef,
    'Email::Send'                                           => undef,
    'Email::Send::SMTP'                                     => undef,
    'Email::Send::Test'                                     => undef,
    'Email::Stuff'                                          => undef,
    'Env::Sourced'                                          => undef,
    'Expect'                                                => undef,
    'Expect::Simple'                                        => undef,
    'FCGI'                                                  => undef,
    'File::Finder'                                          => undef,
    'File::NFSLock'                                         => undef,
    'Filesys::SmbClient'                                    => undef,
    'Furl'                                                  => undef,
    'Furl::HTTP'                                            => undef,
    'Getopt::Clade'                                         => undef,
    'Git::CPAN::Patch'                                      => undef,
    'Git::Repository'                                       => undef,
    'Git::Repository::Plugin'                               => undef,
    'Git::Repository::Plugin::AUTOLOAD'                     => undef,
    'Gtk'                                                   => undef,
    'HTML::Mason'                                           => undef,
    'HTML::Tidy'                                            => undef,
    'HTTP::Proxy'                                           => undef,
    'HTTP::Recorder'                                        => undef,
    'Image::Magick'                                         => undef,
    'Inline::Java'                                          => undef,
    'IO::Async'                                             => undef,
    'IO::InSitu'                                            => undef,
    'IO::Pty'                                               => undef,
    'IO::Socket::SSL'                                       => undef,
    'IO::Tty'                                               => undef,
    'IPC::Msg'                                              => undef,
    'IPC::Open3::Utils'                                     => undef,
    'IPC::Open3SelfLoader'                                  => undef,
    'IPC::Semaphore'                                        => undef,
    'IPC::Shareable'                                        => undef,
    'IPC::System::Options'                                  => undef,
    'IPC::SysV'                                             => undef,
    'Kavorka'                                               => undef,
    'Language::Expr'                                        => undef,
    'Language::Expr::Interpreter::var_enumer'               => undef,
    'Locale::Maketext::Utils'                               => undef,
    'Locale::Maketext::Utils::Mock'                         => undef,
    'Log::Any'                                              => undef,
    'Log::Any::Test'                                        => undef,
    'Mac::Speech'                                           => undef,
    'Mail'                                                  => undef,
    'Mason'                                                 => undef,
    'Math::Pari'                                            => undef,
    'Matrix'                                                => undef,
    'MIME'                                                  => undef,
    'MIME::Entity'                                          => undef,
    'ModPerl::PerlRun'                                      => undef,
    'Module::Build::TestReporter'                           => undef,
    'Module::Faker::Dist'                                   => undef,
    'Module::Install::POE::Test::Loops'                     => undef,
    'Module::License::Report'                               => undef,
    'Module::Pluggable'                                     => undef,
    'Module::Release'                                       => undef,
    'Module:Starter'                                        => undef,
    'Mojolicious'                                           => undef,
    'Moops'                                                 => undef,
    'MooseX::Param::Validate'                               => undef,
    'MooseX::POE'                                           => undef,
    'MooX::Log::Any'                                        => undef,
    'Net::EmptyPort'                                        => undef,
    'Net::Nslookup'                                         => undef,
    'Net::proto'                                            => undef,
    'Net::Server'                                           => undef,
    'Net::Server::Daemonize'                                => undef,
    'Net::Server::Fork'                                     => undef,
    'Net::Server::HTTP'                                     => undef,
    'Net::Server::INET'                                     => undef,
    'Net::Server::Log::Log::Log4perl'                       => undef,
    'Net::Server::Log::Sys::Syslog'                         => undef,
    'Net::Server::Multiplex'                                => undef,
    'Net::Server::MultiType'                                => undef,
    'Net::Server::PreFork'                                  => undef,
    'Net::Server::PreForkSimple'                            => undef,
    'Net::Server::Proto'                                    => undef,
    'Net::Server::Proto::SSL'                               => undef,
    'Net::Server::Proto::SSLEAY'                            => undef,
    'Net::Server::Proto::TCP'                               => undef,
    'Net::Server::Proto::UDP'                               => undef,
    'Net::Server::Proto::UNIX'                              => undef,
    'Net::Server::Proto::UNIXDGRAM'                         => undef,
    'Net::Server::PSGI'                                     => undef,
    'Net::Server::SIG'                                      => undef,
    'Net::Server::Single'                                   => undef,
    'Net::Server::SSL'                                      => undef,
    'Nodejs::Util'                                          => undef,
    'only'                                                  => undef,
    'Padre::Util::Win32'                                    => undef,
    'Parallel::Runner'                                      => undef,
    'Param::Validate'                                       => undef,
    'Path::Iter'                                            => undef,
    'Perinci::Access'                                       => undef,
    'Perinci::Access::Perl'                                 => undef,
    'Perinci::Access::Schemeless'                           => undef,
    'Perinci::CmdLine::Any'                                 => undef,
    'Perinci::CmdLine::Gen'                                 => undef,
    'Perinci::CmdLine::Help'                                => undef,
    'Perinci::CmdLine::Lite'                                => undef,
    'Perinci::Sub::Complete'                                => undef,
    'Perinci::Sub::DepChecker'                              => undef,
    'Perinci::Sub::GetArgs::Argv'                           => undef,
    'Perinci::Sub::To::CLIDocData'                          => undef,
    'Perinci::Sub::Wrapper'                                 => undef,
    'Perl6::Builtins'                                       => undef,
    'Perl6::Rules'                                          => undef,
    'Perl::Critic::CognitiveComplexity'                     => undef,
    'Perl::Critic::Dynamic'                                 => undef,
    'Perl::Critic::DynamicPolicy'                           => undef,
    'Perl::Critic::Policy::Dynamic::NoIndirect'             => undef,
    'Perl::Lint'                                            => undef,
    'Perl::Metrics::Lite'                                   => undef,
    'Pinto'                                                 => undef,
    'POD'                                                   => undef,
    'Pod::InputObject'                                      => undef,
    'Pod::ManPod::Parser'                                   => undef,
    'Pod::SelectPod::Text'                                  => undef,
    'Pod::Simple::Subclassing'                              => undef,
    'POE'                                                   => undef,
    'POE::Component::CPAN::YACSmoke'                        => undef,
    'POE::Component::Server::TCP'                           => undef,
    'POE::Component::Win32::ChangeNotify'                   => undef,
    'POE::Component::Win32::EventLog'                       => undef,
    'POE::Component::Win32::Service'                        => undef,
    'POE::Filter'                                           => undef,
    'POE::Filter::Line'                                     => undef,
    'POE::Filter::Reference'                                => undef,
    'POE::Kernel'                                           => undef,
    'POE::Session'                                          => undef,
    'POE::Test::Helpers'                                    => undef,
    'POE::Test::Loops'                                      => undef,
    'POE::Wheel::ReadWrite'                                 => undef,
    'POE::Wheel::Run'                                       => undef,
    'POE::Wheel::SocketFactory'                             => undef,
    'PPod::Checker'                                         => undef,
    'PRegexp::Assemble'                                     => undef,
    'Proc::Daemon'                                          => undef,
    'Proc::Terminator'                                      => undef,
    'Redis'                                                 => undef,
    'Regexp::Autoflags'                                     => undef,
    'Regexp::MatchContext'                                  => undef,
    'RPerl'                                                 => undef,
    'Sah::Schema::perl::modname'                            => undef,
    'SmokeRunner::Multi'                                    => undef,
    'SpreadSheet::ParseExcel'                               => undef,
    'Spreadsheet::ParseExecl'                               => undef,
    'Spredsheet::WriteExcel'                                => undef,
    'SQL'                                                   => undef,
    'SQLite'                                                => undef,
    'Starman'                                               => undef,
    'Sub::Call::Tail'                                       => undef,
    'Sx'                                                    => undef,
    'System::Command'                                       => undef,
    'Task::Catalyst'                                        => undef,
    'Task::Kensho'                                          => undef,
    'Task::Kensho::Async'                                   => undef,
    'Task::Kensho::Dates'                                   => undef,
    'Task::Kensho::Hackery'                                 => undef,
    'Task::Kensho::Logging'                                 => undef,
    'Task::Kensho::ModuleDev'                               => undef,
    'Task::Kensho::Scalability'                             => undef,
    'Task::Kensho::Toolchain'                               => undef,
    'Task::Kensho::WebCrawling'                             => undef,
    'Task::Kensho::WebDev'                                  => undef,
    'Task::Perl::Critic'                                    => undef,
    'Term::ProgressBar::Quiet'                              => undef,
    'Term::ProgressBar::Simple'                             => undef,
    'Term::Rendezvous'                                      => undef,
    'Test::Between'                                         => undef,
    'Test::CSV'                                             => undef,
    'Test::CSV_XS'                                          => undef,
    'Test::Expect'                                          => undef,
    'Test::Flatten'                                         => undef,
    'Test::Git'                                             => undef,
    'Test::HTML::Lint'                                      => undef,
    'Test::HTML::Tidy'                                      => undef,
    'Test::Mock::LWP'                                       => undef,
    'Test::MockDBI'                                         => undef,
    'Test::MockObject'                                      => undef,
    'Test::MockObject::Extends'                             => undef,
    'Test::MockObject::Extra'                               => undef,
    'Test::more'                                            => undef,
    'Test::Output::Tie'                                     => undef,
    'Test::Perinci::CmdLine'                                => undef,
    'Test::Perl::Metrics::Lite'                             => undef,
    'Test::POE::Client::TCP'                                => undef,
    'Test::POE::Server::TCP'                                => undef,
    # STDOUT: --> Working on Test::Smoke
    # STDOUT: Configuring Test-Smoke-1.83 ... Where would you like to install Test::Smoke?
    # STDOUT: Fetching http://www.cpan.org/authors/id/C/CO/CONTRA/Test-Smoke-1.83.tar.gz ... OK
    # Test::Smoke require user input ?
    'Test::Smoke'                                           => undef,
    'Test::Tutorial'                                        => undef,
    'Test::WWW::Mechanize'                                  => undef,
    'Test::WWW::Mechanize::Catalyst'                        => undef,
    'Test::WWW::Mechanize::PSGI'                            => undef,
    'Text::CSV'                                             => undef,
    'Text::CSV_XS'                                          => undef,
    'Tie::DevNull'                                          => undef,
    'Tie::DevRandom'                                        => undef,
    'Tie::SecureHash'                                       => undef,
    'Tie::TextDir'                                          => undef,
    'Tie::TransactHash'                                     => undef,
    'Time::HiRes::usleep'                                   => undef,
    'Time::ParseDate'                                       => undef,
    'TRest::Perl::Critic'                                   => undef,
    'TRest::Perl::Critic::Progresive'                       => undef,
    'TryCatch'                                              => undef,
    'Underscore'                                            => undef,
    'Unicode::CharName'                                     => undef,
    'Unix::Whereis'                                         => undef,
    'Vim::Debug'                                            => undef,
    'Win32::CLR'                                            => undef,
    'Win32::DirSize'                                        => undef,
    'Win32::FileSystem::Watcher'                            => undef,
    'Win32::Hardlink'                                       => undef,
    'Win32::MMF::Shareable'                                 => undef,
    'Win32::Mock'                                           => undef,
    'Win32::Netsh'                                          => undef,
    'Win32::PerfMon'                                        => undef,
    'Win32::Printer'                                        => undef,
    'Win32::Process::CommandLine'                           => undef,
    'Win32::Process::Info'                                  => undef,
    'Win32::Resources'                                      => undef,
    'Win32::Script'                                         => undef,
    'Win32::Unicode'                                        => undef,
    'Win32API::Const'                                       => undef,
    'Win32API::Resources'                                   => undef,
    'WWW::Curl::Easy'                                       => undef,
    'WWW::Mechanize::TreeBuilder'                           => undef,
    'WWW::Selenium'                                         => undef,
    'XML'                                                   => undef,
);

$| = 1;

_say_ex "started $0";

main( $ARGV[ 0 ] // $EMPTY_STRING, $ARGV[ 1 ] // $EMPTY_STRING );

_say_ex "ended $0";

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

InstallCpanModules.pl [ --only-updates | --no-updates ] filepath

=head1 DESCRIPTION

Install perl modules in bulk with some logic to make this more efficient,
details can be found in the C<README.md>

=head1 PARAMETERS

=over 12

=item C<filepath>

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) to
install. One Name per Line, Linux-Line-Ends preferred but all work's.

=item C<--only-updates>

Only update installed modules, no modules from a given filelist will be
installed.

Attention: If a new module version has a additional dependency, this dependency
will be installed!

=item C<--no-updates>

Do not install updates for modules, exception a new module require a module
update as dependency.

=back

=head1 BUG REPORTS

Please report bugs on GitHub.

The source code repository can be found
at https://github.com/mardem1/perl-bulk-module-installer

=head1 AUTHOR

Markus Demml, mardem@cpan.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2025, Markus Demml

This library is free software; you can redistribute it and/or modify it
under the same terms as the Perl 5 programming language system itself.
The full text of this license can be found in the LICENSE file included
with this module.

=head1 DISCLAIMER

Copyright (c) 2025, Markus Demml

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut
