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

my $log_dir_path = $EMPTY_STRING;

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
    my ( $time ) = @_;
    $time ||= time;

    my @local = ( localtime $time )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d_%H-%M-%S', @local );

    return $now;
}

sub _get_timestamp_pretty
{
    my ( $time ) = @_;
    $time ||= time;

    my @local = ( localtime $time )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d - %H-%M-%S', @local );

    return $now;
}

sub _get_timestamp_for_filename
{
    my ( $time ) = @_;
    $time ||= time;

    my @local = ( localtime $time )[ 0 .. 5 ];
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
    my $start_date        = time;
    my $end_date          = time;
    my $chld_in           = undef;
    my $chld_out          = undef;

    _say_ex 'start cmd: ' . ( join ' ', @cmd );
    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        _say_ex 'ERROR: cmd start failed!';
        return ( $start_date, $end_date, $child_exit_status, @output );
    }

    $start_date = time;
    $end_date   = $start_date;
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

    $end_date = time;

    return ( $start_date, $end_date, $child_exit_status, @output );
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

    dump_state_to_logfiles();

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

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        _get_output_with_detached_execute( $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS, 1, @cmd );

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    my $timestamp      = _get_timestamp_for_filename( $start_date );
    my $time_start     = _get_timestamp_pretty( $start_date );
    my $time_end       = _get_timestamp_pretty( $end_date );
    my $logfile_suffix = 'installed_modules_found';
    my $logfile_title  = 'installed_modules_found';

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.log',
        $logfile_title,
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

    reduce_modules_to_install();

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

    my ( $start_date, $end_date, $child_exit_status, @output ) = ();

    if ( $module eq 'Test::Smoke' ) {
        $child_exit_status = 0;
        @output            = ();
    }
    else {
        ( $start_date, $end_date, $child_exit_status, @output ) =
            _get_output_with_detached_execute( $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS, 1, @cmd );
    }

    if ( !defined $child_exit_status ) {
        return undef;    # as not found
    }

    if ( $child_exit_status && !@output ) {
        _say_ex 'ERROR: search failed - exitcode - ' . $child_exit_status;
        return undef;    # as not found
    }

    my $module_n       = _module_name_for_fs( $module );
    my $timestamp      = _get_timestamp_for_filename( $start_date );
    my $time_start     = _get_timestamp_pretty( $start_date );
    my $time_end       = _get_timestamp_pretty( $end_date );
    my $logfile_suffix = 'fetch_dependency__' . $module_n;
    my $logfile_title  = 'fetch_dependency ' . $module;

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.log',
        $logfile_title,
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

    foreach my $dep_module ( keys %dep ) {
        if ( was_module_already_tried( $dep_module ) ) {
            _say_ex 'module - '
                . $module
                . ' has already failed dependency module - add to failed list' . "\n"
                . Dumper( \%dep );
            mark_module_as_failed( $module );
            last;
        }
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

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        _get_output_with_detached_execute( $INSTALL_MODULE_TIMEOUT_IN_SECONDS, 1, @cmd );

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

    my $timestamp      = _get_timestamp_for_filename( $start_date );
    my $time_start     = _get_timestamp_pretty( $start_date );
    my $time_end       = _get_timestamp_pretty( $end_date );
    my $logfile_suffix = 'install_module__' . $module_n . '__' . $action;
    my $logfile_title  = 'install_module ' . $module;

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.log',
        $logfile_title,
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
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    my @file_lines = _read_file( $filepath );

    @file_lines = map  { _trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ && $_ !~ /^[#]/o } @file_lines;

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

sub import_module_dont_try_list_from_file
{
    my ( $filepath ) = @_;

    if ( _is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    my @file_lines = _read_file( $filepath );

    @file_lines = map  { _trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ && $_ !~ /^[#]/o } @file_lines;

    %modules_install_dont_try = _hashify @file_lines;
    @file_lines               = ();

    _say_ex '';
    _say_ex 'dont try modules to install: '
        . ( scalar keys %modules_install_dont_try ) . "\n"
        . Dumper( \%modules_install_dont_try );
    _say_ex '';

    my $timestamp = _get_timestamp_for_filename();

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'import_module_dont_try_list_from_file.log',
        'import_module_dont_try_list_from_file: ' . scalar( keys %modules_install_dont_try ),
        Dumper( \%modules_install_dont_try ),
    );

    return;
}

sub print_perl_detail_info
{
    my @cmd = ( 'cmd.exe', '/c', 'perl', '-V' );

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        _get_output_with_detached_execute( $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS, 1, @cmd );

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    my $timestamp      = _get_timestamp_for_filename( $start_date );
    my $time_start     = _get_timestamp_pretty( $start_date );
    my $time_end       = _get_timestamp_pretty( $end_date );
    my $logfile_suffix = 'perl_detail_info';
    my $logfile_title  = 'perl_detail_info';

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.log',
        $logfile_title,
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

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        _get_output_with_detached_execute( $CHECK_UPDATE_MODULE_TIMEOUT_IN_SECONDS, 1, @cmd );

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    my $timestamp      = _get_timestamp_for_filename( $start_date );
    my $time_start     = _get_timestamp_pretty( $start_date );
    my $time_end       = _get_timestamp_pretty( $end_date );
    my $logfile_suffix = 'modules_with_available_updates';
    my $logfile_title  = 'modules_with_available_updates';

    _write_file(
        $log_dir_path . '/' . $timestamp . '_' . $$logfile_suffix . '.log',
        $$logfile_title,
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

sub install_modules_sequentially
{
    _say_ex 'install all modules sequentially';

    my $remaining = scalar( keys %modules_need_to_install );
    my $check_i   = 0;

    my $module = q{};
    $module = ( keys %modules_need_to_install )[ 0 ];

    while ( $module ) {
        #    foreach my $module ( @needed_modules ) {
        $check_i++;

        foreach ( 1 .. 10 ) {
            _say_ex '';
        }

        my $tried = was_module_already_tried( $module );
        if ( defined $tried ) {
            _say_ex "==> module already tried -> IGNORE - ($check_i - $remaining) - $module";

            $remaining = scalar( keys %modules_need_to_install );
            $module    = ( keys %modules_need_to_install )[ 0 ];
            next;
        }

        _say_ex "==> handle next install list module - ($check_i - $remaining) - $module";

        my $current_install_count = scalar( keys %modules_install_ok );

        _say_ex "==> analyze module - ($check_i - $remaining) - $module";
        add_dependency_module_if_needed( $module );

        dump_state_to_logfiles();

        _say_ex "==> install module with dependencies - ($check_i - $remaining) - $module";
        install_modules_dep_version();

        my $new_install_count = scalar( keys %modules_install_ok );
        if ( $current_install_count != $new_install_count ) {
            _say_ex "==> after successful module install - reimport all installed modules from system";
            search_for_installed_modules();
        }

        $remaining = scalar( keys %modules_need_to_install );
        $module    = ( keys %modules_need_to_install )[ 0 ];
    }

    print_install_state_summary();

    return;
}

sub handle_main_arguments
{
    my ( $arg1, $arg2, $arg3 ) = @_;
    $arg1 = _trim( $arg1 );
    $arg2 = _trim( $arg2 );
    $arg2 = _trim( $arg3 );

    my $filepath_install  = $EMPTY_STRING;
    my $filepath_dont_try = $EMPTY_STRING;
    my $only_all_updates  = $FALSE;
    my $all_updates       = $FALSE;

    if ( $arg1 eq '--only-all-updates' ) {
        $only_all_updates = $TRUE;
        if ( !_is_string_empty( $arg2 ) ) {
            croak 'wrong parameter set';
        }
    }
    elsif ( $arg1 eq '--all-updates' ) {
        $all_updates = $TRUE;
        if ( _is_string_empty( $arg2 ) ) {
            croak 'wrong parameter set';
        }

        $filepath_install = $arg2;

        if ( !_is_string_empty( $arg3 ) ) {
            $filepath_dont_try = $arg3;
        }
    }
    elsif ( _is_string_empty( $arg1 ) ) {
        croak 'wrong parameter set';
    }
    else {
        $filepath_install = $arg1;

        if ( !_is_string_empty( $arg2 ) ) {
            $filepath_dont_try = $arg2;
        }
    }

    $filepath_install  = _trim( $filepath_install );
    $filepath_dont_try = _trim( $filepath_dont_try );

    return ( $filepath_install, $filepath_dont_try, $only_all_updates, $all_updates );
}

sub init_log_dir_path
{
    my $logdir = dirname( __FILE__ ) . '/log';
    $log_dir_path = abs_path( $logdir );

    if ( _is_string_empty( $log_dir_path ) ) {
        croak "logdir '$logdir' not found";
    }

    if ( !-d $log_dir_path ) {
        croak "logdir '$log_dir_path' not found";
    }

    return;
}

sub main
{
    my ( $filepath_install, $filepath_dont_try, $only_all_updates, $all_updates ) = handle_main_arguments( @_ );

    init_log_dir_path();

    print_perl_detail_info();

    if ( $only_all_updates ) {
        _say_ex '--only-all-updates: skip module list file import';
    }
    else {
        if ( _is_string_empty( $filepath_install ) ) {
            croak 'no file arg given';
        }

        import_module_list_from_file( $filepath_install );
    }

    if ( !_is_string_empty( $filepath_dont_try ) ) {
        # mark modules as failed, some to old to build, other not for windows ...
        import_module_dont_try_list_from_file( $filepath_dont_try );
    }

    search_for_installed_modules();

    if ( !$all_updates ) {
        _say_ex 'no --all-updates: skip update module list import';
    }
    else {
        search_for_modules_for_available_updates();
    }

    # add_dependency_modules_for_modules_need_to_install();

    dump_state_to_logfiles();

    print_install_state_summary();

    # install_modules_dep_version();

    install_modules_sequentially();

    print_install_end_summary();

    dump_state_to_logfiles();

    return;
}

$| = 1;

_say_ex "started $0";

main( $ARGV[ 0 ] // $EMPTY_STRING, $ARGV[ 1 ] // $EMPTY_STRING, $ARGV[ 2 ] // $EMPTY_STRING );

_say_ex "ended $0";

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

InstallCpanModules.pl [ --only-all-updates | --all-updates ] filepath_install [ filepath_dont_try ]

=head1 DESCRIPTION

Install perl modules in bulk with some logic to make this more efficient,
details can be found in the C<README.md>

=head1 PARAMETERS

=over 12

=item C<filepath_dont_try>

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) which will not be installed.
One Name per Line, # marks a comment line, Linux-Line-Ends preferred but all work's.

=item C<filepath_install>

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) to
install. One Name per Line, # marks a comment line Linux-Line-Ends preferred but all work's.

=item C<--only-all-updates>

Only update installed modules, no modules from a given filelist will be
installed.

Attention: If a new module version has a additional dependency, this dependency
will be installed!

=item C<--all-updates>

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
