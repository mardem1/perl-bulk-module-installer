package PerlBulkModuleInstaller;

use utf8;

use 5.010;

use strict;
use warnings;

BEGIN {
    if ( $^O !~ /win32/io ) {
        die 'sorry this is only for windows :(';
    }
}

use base qw(Exporter);

use version;
use POSIX qw( floor :sys_wait_h );
use Carp  qw( croak );
use Carp::Always;
use IPC::Open3;
use Data::Dumper   qw( Dumper );
use List::Util     qw( shuffle );
use Cwd            qw( abs_path );
use File::Basename qw( dirname );

our @EXPORT_OK = qw(
    say_ex
    main
);

our $VERSION = '0.01';

# modules which are known to fail, imported from file via -> import_module_dont_try_list_from_file()
# will not changed after init
# will only exported as file after init
my %modules_install_dont_try_from_file = ();

# modules which should be installed, imported from file via -> import_module_list_from_file()
# will not changed after init
# will only exported as file after init
my %modules_to_install_from_file = ();

# modules which has an update available to installed, checked with -> search_for_modules_for_available_updates()
# will be added to %modules_need_to_install with -> generate_modules_need_to_install()
# will not changed after init
# will only exported as file after init
my %modules_with_available_updates = ();

# modules which should be installed (listfile) and are already installed on the system, generated with -> generate_modules_need_to_install()
# will not changed after init
# will only exported as file after init
# TODO: should it be updated after system module list import update -> eg. some Sub-Module on list Perl::Critic::Utils::McCabe and Perl::Critic itself. After Perl::Critic installed it should recocnize thate McCabe also installed ?
my %modules_install_already = ();

# modules which are installed on the system, checked with -> search_for_installed_modules()
# will be updated after every successful module installation
my %installed_module_version = ();

# will be added if install OK -> install_single_module() / mark_module_as_ok()
my %modules_install_ok = ();

# will be added if install FAILED -> install_single_module() / mark_module_as_failed()
# hint: modules which are on %modules_install_dont_try_from_file will not be added as failed and ignored
my %modules_install_failed = ();

# will be added if module not found at dependency check -> fetch_dependencies_for_module() / mark_module_as_not_found()
my %modules_install_not_found = ();

# modules which needs to be processed (installed/updated), generated with -> generate_modules_need_to_install()
# removed from hash when done
my %modules_need_to_install = ();

my $INSTALL_MODULE_TIMEOUT_IN_SECONDS               = 60 * 10;
my $CHECK_UPDATE_MODULE_TIMEOUT_IN_SECONDS          = 60 * 2;
my $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS = 60 * 2;
my $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS = 60 * 2;

my $EMPTY_STRING = q{};
my $FALSE        = !!0;
my $TRUE         = !0;

my $log_dir_path = $EMPTY_STRING;

sub trim
{
    my ( $s ) = @_;

    $s //= $EMPTY_STRING;
    $s =~ s/^\s+|\s+$//g;

    return $s;
}

sub str_replace
{
    my ( $string, $search, $replace ) = @_;

    $string =~ s/$search/$replace/g;

    return $string;
}

sub module_name_for_fs
{
    my ( $module ) = @_;

    my $module_n = str_replace( $module, '::', '_' );

    return $module_n;
}

sub get_log_line
{
    my @args = @_;

    my $line = $EMPTY_STRING;

    my $now = get_timestamp_for_logline();

    $line = '# ' . $now . ' # ' . join( '', @args );

    return $line;
}

sub say_ex
{
    my @args = @_;

    my $line = get_log_line( @args );

    say $line;

    return;
}

sub is_string_empty
{
    my ( $s ) = @_;

    my $t = !defined $s || $EMPTY_STRING eq $s;

    return $t;
}

sub hashify
{
    my @args = @_;

    return map { $_ => undef } @args;
}

sub sleep_if_called_within_a_second
{
    state $last_call = 0;

    my $now = time;
    if ( $last_call == $now ) {
        sleep 1;
        $now = time;
    }

    $last_call = $now;

    return;
}

sub get_timestamp_for_logline
{
    my ( $time ) = @_;
    $time ||= time;

    my @local = ( localtime $time )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d_%H-%M-%S', @local );

    return $now;
}

sub get_timestamp_pretty
{
    my ( $time ) = @_;
    $time ||= time;

    my @local = ( localtime $time )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y-%m-%d - %H-%M-%S', @local );

    return $now;
}

sub get_timestamp_for_filename
{
    my ( $time ) = @_;
    $time ||= time;

    my @local = ( localtime $time )[ 0 .. 5 ];
    my $now   = POSIX::strftime( '%Y%m%d_%H%M%S', @local );

    return $now;
}

sub read_file
{
    my ( $filepath ) = @_;

    if ( is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    if ( !( -e -f -r -s $filepath ) ) {
        say_ex( "ERROR: filepath '$filepath' - not exists, readable or empty" );
        croak "filepath '$filepath' - not exists, readable or empty";
    }

    say_ex( '==> ' . "read '$filepath'" );

    my $fh = undef;
    if ( !open( $fh, '<', $filepath ) ) {
        say_ex( "ERROR: Couldn't open file-read '$filepath'" );
        say_ex( 'ERROR: start $! ->' );
        say_ex( '' );
        say_ex( "$!" );
        say_ex( '' );
        say_ex( 'ERROR: <- $! ended' );
        croak "Couldn't open file-read '$filepath'";
    }

    local $/;
    $/ = "\n";    # force linux line ends

    my @raw_file_lines = <$fh>;

    close( $fh );

    return @raw_file_lines;
}

sub write_file
{
    my ( $filepath, $header, @content ) = @_;

    if ( is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    if ( is_string_empty( $header ) ) {
        croak 'param header empty!';
    }

    say_ex( '==> ' . "write '$filepath'" );

    my $fh = undef;
    if ( !open( $fh, '>', $filepath ) ) {
        say_ex( "ERROR: Couldn't open file-write '$filepath'" );
        say_ex( 'ERROR: start $! ->' );
        say_ex( '' );
        say_ex( "$!" );
        say_ex( '' );
        say_ex( 'ERROR: <- $! ended' );
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

sub get_output_with_detached_execute
{
    my ( $timeout, $show_live_output, @cmd ) = @_;

    if ( is_string_empty( $timeout ) ) {
        croak 'param timeout empty!';
    }

    if ( 1 > $timeout ) {
        croak 'param timeout greater 0!';
    }

    if ( is_string_empty( $show_live_output ) ) {
        croak 'param show_live_output empty!';
    }

    if ( ( ( scalar @cmd ) == 0 ) || is_string_empty( $cmd[ 0 ] ) ) {
        croak 'param @cmd empty!';
    }

    sleep_if_called_within_a_second();

    if ( $show_live_output ) {
        say_ex( '' ) foreach ( 1 .. 25 );
        say_ex( '=' x 80 );
        say_ex( '' );
    }

    say_ex( '==> ' . 'start cmd: ' . ( join ' ', @cmd ) );

    my $child_exit_status = undef;
    my @output            = ();
    my $start_date        = time;
    my $end_date          = time;
    my $chld_in           = undef;
    my $chld_out          = undef;

    my $pid = open3( $chld_in, $chld_out, '>&STDERR', @cmd );

    if ( 1 > $pid ) {
        say_ex( 'ERROR: cmd start failed!' );
        return ( $start_date, $end_date, $child_exit_status, @output );
    }

    $start_date = time;
    $end_date   = $start_date;
    say_ex( 'pid: ' . $pid );

    say_ex( 'close chld_in' );
    close $chld_in;

    say_ex( 'read output ... ' );

    local $@;
    my $eval_ok = eval {
        local $SIG{ 'ALRM' } = sub { die "timeout_alarm\n"; };    # NB: \n required
        alarm $timeout;

        while ( my $line = <$chld_out> ) {
            $line = trim( $line );
            push @output, $line;

            if ( $show_live_output ) {
                say_ex( 'STDOUT: ' . $line );
            }
        }

        return 'eval_ok';
    };

    alarm 0;    # disable

    if ( $@ ) {
        if ( "timeout_alarm\n" ne $@ ) {
            say_ex( 'ERROR: unexpected error' );
            say_ex( 'ERROR: start $@ ->' );
            say_ex( '' );
            say_ex( '' . 0 + $@ );
            say_ex( '' );
            say_ex( "$@" );
            say_ex( '' );
            say_ex( 'ERROR: <- $@ ended' );
            kill -9, $pid;    # kill
        }
        else {
            say_ex( 'ERROR: timeout' );
            say_ex( 'ERROR: start $@ ->' );
            say_ex( '' );
            say_ex( '' . 0 + $@ );
            say_ex( '' );
            say_ex( "$@" );
            say_ex( '' );
            say_ex( 'ERROR: <- $@ ended' );
            kill -9, $pid;    # kill
        }
    }
    elsif ( 'eval_ok' ne $eval_ok ) {
        say_ex( 'ERROR: eval failed' );
        say_ex( 'ERROR: start $@ ->' );
        say_ex( '' );
        say_ex( '' . 0 + $@ );
        say_ex( '' );
        say_ex "$@";
        say_ex( '' );
        say_ex( 'ERROR: <- $@ ended' );
        kill -9, $pid;    # kill
    }
    else {
        say_ex( 'close chld_out' );
        close $chld_out;

        say_ex( 'wait for exit...' );
        # reap zombie and retrieve exit status
        waitpid( $pid, 0 );
        $child_exit_status = $? >> 8;
        say_ex( '$child_exit_status: ' . $child_exit_status );
    }

    $end_date = time;

    say_ex( '==> ' . 'cmd ended: ' . ( join ' ', @cmd ) );

    if ( $show_live_output ) {
        say_ex( '' );
        say_ex( '=' x 80 );
        say_ex( '' ) foreach ( 1 .. 25 );
    }

    return ( $start_date, $end_date, $child_exit_status, @output );
}

sub get_output_with_detached_execute_and_logfile
{
    my ( $logfile_suffix, $logfile_title, $timeout, $show_live_output, @cmd ) = @_;

    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    if ( is_string_empty( $logfile_suffix ) ) {
        croak 'param logfile_suffix empty!';
    }

    if ( is_string_empty( $logfile_title ) ) {
        croak 'param logfile_title empty!';
    }

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        get_output_with_detached_execute( $timeout, $show_live_output, @cmd );

    my $timestamp  = get_timestamp_for_filename( $start_date );
    my $time_start = get_timestamp_pretty( $start_date );
    my $time_end   = get_timestamp_pretty( $end_date );

    my $duration_seconds = $end_date - $start_date;
    my $duration_minutes = ( 0.0 + $duration_seconds ) / 60.0;

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.log',
        $logfile_title,
        'CMD: ' . ( join ' ', @cmd ),
        'ExitCode: ' . $child_exit_status,
        'Started: ' . $time_start,
        'Ended: ' . $time_end,
        'Duration: ' . $duration_seconds . ' seconds => ' . $duration_minutes . ' minutes',
        '',
        '=' x 80,
        '',
        @output,
        '',
    );

    return ( $start_date, $end_date, $child_exit_status, @output );
}

sub import_module_list_from_file
{
    my ( $filepath ) = @_;

    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    if ( is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    say_ex( '==> ' . 'import module list from file: ' . $filepath );

    my @file_lines = read_file( $filepath );

    @file_lines = map  { trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ && $_ !~ /^[#]/o } @file_lines;

    %modules_to_install_from_file = hashify( @file_lines );
    @file_lines                   = ();

    say_ex( '' );
    say_ex(   'modules_to_install_from_file: '
            . ( scalar keys %modules_to_install_from_file ) . "\n"
            . Dumper( \%modules_to_install_from_file ) );
    say_ex( '' );

    my $timestamp = get_timestamp_for_filename();

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_to_install_from_file.log',
        'modules_to_install_from_file: ' . scalar( keys %modules_to_install_from_file ),
        Dumper( \%modules_to_install_from_file ),
    );

    return;
}

sub import_module_dont_try_list_from_file
{
    my ( $filepath ) = @_;

    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    if ( is_string_empty( $filepath ) ) {
        croak 'param filepath empty!';
    }

    say_ex( '==> ' . 'import module dont try list file: ' . $filepath );

    my @file_lines = read_file( $filepath );

    @file_lines = map  { trim( $_ ) } @file_lines;
    @file_lines = grep { $EMPTY_STRING ne $_ && $_ !~ /^[#]/o } @file_lines;

    %modules_install_dont_try_from_file = hashify( @file_lines );
    @file_lines                         = ();

    say_ex( '' );
    say_ex(   'modules_install_dont_try_from_file: '
            . ( scalar keys %modules_install_dont_try_from_file ) . "\n"
            . Dumper( \%modules_install_dont_try_from_file ) );
    say_ex( '' );

    my $timestamp = get_timestamp_for_filename();

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'import_module_dont_try_list_from_file.log',
        'import_module_dont_try_list_from_file: ' . scalar( keys %modules_install_dont_try_from_file ),
        Dumper( \%modules_install_dont_try_from_file ),
    );

    return;
}

sub mark_module_as_ok
{
    my ( $module, $version ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    say_ex( 'add ', $module, ' to modules_install_ok' );
    $modules_install_ok{ $module } = undef;

    say_ex( 'add ', $module, ' to installed_module_version' );
    $installed_module_version{ $module } = $version;

    say_ex( 'remove ', $module, ' from modules_need_to_install' );
    delete $modules_need_to_install{ $module };

    return;
}

sub mark_module_as_failed
{
    my ( $module, $version ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    if ( exists $modules_install_dont_try_from_file{ $module } ) {
        say_ex( 'module ', $module, ' marked as dont try - so dont add to failed!' );
    }
    else {
        say_ex( 'add ', $module, ' to modules_install_failed' );
        $modules_install_failed{ $module } = $version;
    }

    say_ex( 'remove ', $module, ' from modules_need_to_install' );
    delete $modules_need_to_install{ $module };    # remove module - don't care if failed - no retry of failed

    return;
}

sub mark_module_as_not_found
{
    my ( $module, $version ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( is_string_empty( $version ) ) {
        $version = undef;    # force undef if empty - param optional
    }

    say_ex( 'add ', $module, ' to modules_install_not_found' );
    $modules_install_not_found{ $module } = $version;

    say_ex( 'remove ', $module, ' from modules_need_to_install' );
    delete $modules_need_to_install{ $module };    # remove module - don't care if not found - no retry of not found

    return;
}

sub was_module_already_tried
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    if ( exists $modules_install_dont_try_from_file{ $module } ) {
        say_ex( 'WARN: install module - ' . $module . ' - marked dont try - abort' );

        return 1;
    }

    if ( exists $modules_install_ok{ $module } ) {
        say_ex( 'WARN: install module - ' . $module . ' - already ok - abort' );

        return 0;
    }

    if ( exists $modules_install_failed{ $module } ) {
        say_ex( 'WARN: install module - ' . $module . ' - already failed - abort' );

        return 1;
    }

    if ( exists $modules_install_not_found{ $module } ) {
        say_ex( 'WARN: install module - ' . $module . ' - already mot found - abort' );

        return 1;
    }

    return undef;
}

sub generate_modules_need_to_install
{
    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    foreach my $module ( keys %modules_with_available_updates ) {
        if (   exists $modules_install_dont_try_from_file{ $module }
            || exists $modules_install_ok{ $module }
            || exists $modules_install_failed{ $module }
            || exists $modules_install_not_found{ $module }
            || exists $modules_need_to_install{ $module } )
        {
            # already marked somewhere - ignore
        }
        # no check $installed_module_version if update already exist
        else {
            $modules_need_to_install{ $module } = undef;
        }
    }

    foreach my $module ( keys %modules_to_install_from_file ) {
        if (   exists $modules_install_dont_try_from_file{ $module }
            || exists $modules_install_ok{ $module }
            || exists $modules_install_failed{ $module }
            || exists $modules_install_not_found{ $module }
            || exists $modules_need_to_install{ $module } )
        {
            # already marked somewhere - ignore
        }
        elsif ( exists $installed_module_version{ $module } ) {
            $modules_install_already{ $module } = undef;
        }
        else {
            $modules_need_to_install{ $module } = undef;
        }
    }

    my $timestamp = get_timestamp_for_filename();

    say_ex( '' );
    say_ex(   'modules_install_already: '
            . scalar( keys %modules_install_already ) . "\n"
            . Dumper( \%modules_install_already ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_already.log',
        'modules_install_already: ' . scalar( keys %modules_install_already ),
        Dumper( \%modules_install_already ),
    );

    say_ex( '' );
    say_ex(   'modules_need_to_install: '
            . scalar( keys %modules_need_to_install ) . "\n"
            . Dumper( \%modules_need_to_install ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );

    return;
}

sub print_and_log_intermediate_state
{
    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    my $timestamp = get_timestamp_for_filename();

    foreach ( 1 .. 10 ) {
        say_ex( '' );
    }

    say_ex( '==> ' . 'print_and_log_intermediate_state' );
    say_ex( '' );
    say_ex( '' );

    if ( %modules_install_ok ) {
        say_ex( 'modules_install_ok: ' . scalar( keys %modules_install_ok ) . "\n" . Dumper( \%modules_install_ok ) );

        write_file(
            $log_dir_path . '/' . $timestamp . '_' . 'modules_install_ok.log',
            'modules_install_ok: ' . scalar( keys %modules_install_ok ),
            Dumper( \%modules_install_ok ),
        );
    }

    if ( %modules_install_not_found ) {
        say_ex(   'modules_install_not_found: '
                . scalar( keys %modules_install_not_found ) . "\n"
                . Dumper( \%modules_install_not_found ) );

        write_file(
            $log_dir_path . '/' . $timestamp . '_' . 'modules_install_not_found.log',
            'modules_install_not_found: ' . scalar( keys %modules_install_not_found ),
            Dumper( \%modules_install_not_found ),
        );
    }

    if ( %modules_install_failed ) {

        say_ex(   'modules_install_failed: '
                . scalar( keys %modules_install_failed ) . "\n"
                . Dumper( \%modules_install_failed ) );

        write_file(
            $log_dir_path . '/' . $timestamp . '_' . 'modules_install_failed.log',
            'modules_install_failed: ' . scalar( keys %modules_install_failed ),
            Dumper( \%modules_install_failed ),
        );
    }

    if ( %modules_need_to_install ) {
        say_ex(   'modules_need_to_install left: '
                . scalar( keys %modules_need_to_install ) . "\n"
                . Dumper( \%modules_need_to_install ) );

        write_file(
            $log_dir_path . '/' . $timestamp . '_' . 'modules_need_to_install.log',
            'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
            Dumper( \%modules_need_to_install ),
        );
    }

    say_ex( '' );
    say_ex( '' );

    return;
}

sub print_and_log_full_summary
{
    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    my $timestamp = get_timestamp_for_filename();

    foreach ( 1 .. 10 ) {
        say_ex( '' );
    }

    say_ex( '==> ' . 'full summary' );
    say_ex( '' );

    say_ex( '' );
    say_ex(   'modules_install_dont_try_from_file: '
            . scalar( keys %modules_install_dont_try_from_file ) . "\n"
            . Dumper( \%modules_install_dont_try_from_file ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'import_module_dont_try_list_from_file.log',
        'import_module_dont_try_list_from_file: ' . scalar( keys %modules_install_dont_try_from_file ),
        Dumper( \%modules_install_dont_try_from_file ),
    );

    say_ex( '' );
    say_ex(   'modules_to_install_from_file: '
            . scalar( keys %modules_to_install_from_file ) . "\n"
            . Dumper( \%modules_to_install_from_file ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_to_install_from_file.log',
        'modules_to_install_from_file: ' . scalar( keys %modules_to_install_from_file ),
        Dumper( \%modules_to_install_from_file ),
    );

    say_ex( '' );
    say_ex(   'modules_with_available_updates: '
            . scalar( keys %modules_with_available_updates ) . "\n"
            . Dumper( \%modules_with_available_updates ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_with_available_updates.log',
        'modules_with_available_updates: ' . scalar( keys %modules_with_available_updates ),
        Dumper( \%modules_with_available_updates ),
    );

    say_ex( '' );
    say_ex(   'installed_module_version: '
            . scalar( keys %installed_module_version ) . "\n"
            . Dumper( \%installed_module_version ) );
    say_ex( '' );

    say_ex( '' );
    say_ex(   'modules_install_already: '
            . scalar( keys %modules_install_already ) . "\n"
            . Dumper( \%modules_install_already ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_already.log',
        'modules_install_already: ' . scalar( keys %modules_install_already ),
        Dumper( \%modules_install_already ),
    );

    say_ex( '' );
    say_ex(   'modules_install_not_found: '
            . scalar( keys %modules_install_not_found ) . "\n"
            . Dumper( \%modules_install_not_found ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_not_found.log',
        'modules_install_not_found: ' . scalar( keys %modules_install_not_found ),
        Dumper( \%modules_install_not_found ),
    );

    say_ex( '' );
    say_ex(   'modules_install_failed: '
            . scalar( keys %modules_install_failed ) . "\n"
            . Dumper( \%modules_install_failed ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_failed.log',
        'modules_install_failed: ' . scalar( keys %modules_install_failed ),
        Dumper( \%modules_install_failed ),
    );

    say_ex( '' );
    say_ex( 'modules_install_ok: ' . scalar( keys %modules_install_ok ) . "\n" . Dumper( \%modules_install_ok ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_install_ok.log',
        'modules_install_ok: ' . scalar( keys %modules_install_ok ),
        Dumper( \%modules_install_ok ),
    );

    say_ex( '' );
    say_ex(   'modules_need_to_install: '
            . scalar( keys %modules_need_to_install ) . "\n"
            . Dumper( \%modules_need_to_install ) );
    say_ex( '' );

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_need_to_install.log',
        'modules_need_to_install: ' . scalar( keys %modules_need_to_install ),
        Dumper( \%modules_need_to_install ),
    );

    return;
}

sub print_perl_detail_info
{
    my $logfile_suffix = 'perl_detail_info';
    my $logfile_title  = 'perl_detail_info';

    # my @cmd = ( 'cmd.exe', '/c', 'perl', '-V', '2>&1' );
    my @cmd = ( 'cmd.exe', '/c', $^X, '-V', '2>&1' );

    say_ex( '==> ' . 'perl information' );

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        get_output_with_detached_execute_and_logfile( $logfile_suffix, $logfile_title,
            $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS,
            1, @cmd );

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    return;
}

sub search_for_installed_modules
{
    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    my @cmd = ( 'cmd.exe', '/c', 'cpan', '-l', '2>&1' );

    my $logfile_suffix = 'installed_modules_found';
    my $logfile_title  = 'installed_modules_found';

    say_ex( '==> ' . 'search for installed modules' );

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        get_output_with_detached_execute_and_logfile( $logfile_suffix, $logfile_title,
            $SEARCH_FOR_INSTALLED_MODULES_TIMEOUT_IN_SECONDS,
            0, @cmd );    # no direct output only log

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;           # error nothing found
    }

    say_ex( '  ==> ' . 'analyze found modules' );

    # extra hash needed instead of direct use of installed_module_version because update / duplicate check.
    # second run would be always a duplicate.
    my %found_module_version = ();
    foreach my $line ( @output ) {
        $line = trim( $line );
        if ( $EMPTY_STRING eq $line ) {
            next;
        }

        # say_ex( '  ==> ' . "check $line");

        if ( $line !~ /^([\S]+)[\s]+([\S]+)$/ ) {
            say_ex( '    ==> ' . "ignore - unknown line format - '$line'" );
            next;
        }

        my $m = trim( $1 );
        my $v = trim( $2 );
        $v = ( $EMPTY_STRING eq $v || 'undef' eq $v ? undef : $v );

        # some modules wrong listed - end with : ? => ignore?
        # Upper-Case defined as first character for none core / standard modules
        # but we need all modules for dependency check here so also lower case start allowed
        if ( $line !~ /^(([a-zA-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]/io ) {
            say_ex( '    ==> ' . "ignore - no match - '$m'" );
        }
        elsif ( !exists $found_module_version{ $m } ) {
            # say_ex( '    ==> ' . "unknown module save it - '$m'" );
            $found_module_version{ $m } = $v;
        }
        elsif ( !defined $found_module_version{ $m } && !defined $v ) {
            # say_ex( '    ==> ' . "both modules undefined number, do nothing - '$m'" );
        }
        elsif ( defined $found_module_version{ $m } && !defined $v ) {
            # say_ex( '    ==> ' . "already known number, keep it - '$m'" );
        }
        elsif ( !defined $found_module_version{ $m } && defined $v ) {
            # say_ex( '    ==> ' . "replace undefined with defined version number - '$m'" );
            $found_module_version{ $m } = $v;
        }
        else {
            # elsif ( defined $found_module_version{ $m }  && defined $v ) {

            my $version_m = version->parse( $found_module_version{ $m } );
            my $version_v = version->parse( $v );

            if ( !$version_m ) {
                say_ex( '    ==> ' . "version convert failed - '$m' " . $found_module_version{ $m } );

                # TODO: what to do ?
            }
            elsif ( !$version_v ) {
                say_ex( '    ==> ' . "version convert failed - '$m' " . $v );

                # TODO: what to do ?
            }
            elsif ( ( $version_m cmp $version_v ) >= 0 ) {
                say_ex(   '    ==> '
                        . "known module equal or newer - '$m' "
                        . $found_module_version{ $m } . " vs. "
                        . $v );
            }
            else {
                say_ex(   '    ==> '
                        . "found module newer, replace - '$m' "
                        . $found_module_version{ $m } . " vs. "
                        . $v );
                $found_module_version{ $m } = $v;
            }
        }
    }

    my $timestamp = get_timestamp_for_filename( $start_date );

    # for module list txt and csv files reduce to Upper-Case start - see above
    my @moduleNames = grep { $_ =~ /^[A-Z]/o } sort keys %found_module_version;

    write_file( $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.txt',
        "# $logfile_title $^V", @moduleNames );

    my @moduleCsvLines = ();
    foreach my $name ( @moduleNames ) {
        my $version = $found_module_version{ $name } // 'undef';
        push @moduleCsvLines, "$name;$version";
    }
    write_file(
        $log_dir_path . '/' . $timestamp . '_' . $logfile_suffix . '.csv',
        "# $logfile_title;$^V",
        @moduleCsvLines
    );

    # import found modules to install modules
    foreach my $name ( keys %found_module_version ) {
        $installed_module_version{ $name } = $found_module_version{ $name };
    }

    say_ex( '' );
    say_ex(
        'installed_module_version: ' . scalar( keys %installed_module_version ) . "\n"
            # . Dumper( \%installed_module_version );
            . ''
    );
    say_ex( '' );

    # filedump not needed exported as txt and csv

    return;
}

sub search_for_modules_for_available_updates
{
    if ( is_string_empty( $log_dir_path ) ) {
        croak 'log_dir_path empty!';
    }

    my $logfile_suffix = 'modules_with_available_updates';
    my $logfile_title  = 'modules_with_available_updates';

    my @cmd = ( 'cmd.exe', '/c', 'cpan-outdated', '--exclude-core', '-p', '2>&1' );

    say_ex( '==> ' . 'search for available updates' );

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        get_output_with_detached_execute_and_logfile( $logfile_suffix, $logfile_title,
            $CHECK_UPDATE_MODULE_TIMEOUT_IN_SECONDS,
            1, @cmd );

    if ( !defined $child_exit_status || ( $child_exit_status && !@output ) ) {
        return;    # error nothing found
    }

    foreach my $module ( @output ) {
        $modules_with_available_updates{ $module } = undef;
    }

    say_ex( '' );
    say_ex 'modules_with_available_updates: '
        . scalar( keys %modules_with_available_updates ) . "\n"
        . Dumper( \%modules_with_available_updates );
    say_ex( '' );

    my $timestamp = get_timestamp_for_filename();

    write_file(
        $log_dir_path . '/' . $timestamp . '_' . 'modules_with_available_updates.log',
        'modules_with_available_updates: ' . scalar( keys %modules_with_available_updates ),
        Dumper( \%modules_with_available_updates ),
    );

    return;
}

sub install_single_module
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    my $tried = was_module_already_tried( $module );
    if ( defined $tried ) {
        return $tried;
    }

    my $module_n = module_name_for_fs( $module );

    my $type = 'install';
    if ( exists $installed_module_version{ $module } ) {
        $type = 'update';
    }

    say_ex( '==> ' . $type . ' module - ' . $module );

    my $logfile_suffix = 'install_module__' . $module_n . '__' . $type;
    my $logfile_title  = 'install_module -> ' . $module . ' -> ' . $type;

    # for update force not needed
    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--verbose', '--no-interactive', $module, '2>&1' );

    my ( $start_date, $end_date, $child_exit_status, @output ) =
        get_output_with_detached_execute_and_logfile( $logfile_suffix, $logfile_title,
            $INSTALL_MODULE_TIMEOUT_IN_SECONDS,
            1, @cmd );

    my $action   = $type;
    my $hasError = 0;
    if ( !defined $child_exit_status ) {
        $hasError = 1;

        $action .= '-failed-start';
        mark_module_as_failed( $module, undef );
    }
    elsif ( $child_exit_status ) {
        $hasError = 1;

        $action .= '-failed';
        mark_module_as_failed( $module, undef );
    }
    else {
        $hasError = 0;

        $action .= '-success';
        mark_module_as_ok( $module, 999_999 );    # newest version - so real number not relevant.
    }

    say_ex( '==> ' . $type . ' module - ' . $module . ' ' . $action );

    if ( !$hasError ) {
        say_ex( '==> ' . 'after successful module install - reimport all installed modules from system' );
        search_for_installed_modules();
    }

    return $hasError;
}

sub fetch_dependencies_for_module
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    say_ex( '==> ' . 'get module dependencies - ' . $module );

    my $module_n       = module_name_for_fs( $module );
    my $logfile_suffix = 'fetch_dependency__' . $module_n;
    my $logfile_title  = 'fetch_dependency ' . $module;

    # showdeps checks also the dependency of the dependency if not already installed.
    # eg Perl::Critic shows other dependencies if all dependencies are installed.
    # so the information can change
    my @cmd = ( 'cmd.exe', '/c', 'cpanm', '--no-interactive', '--showdeps', $module, '2>&1' );

    my ( $start_date, $end_date, $child_exit_status, @output ) = ();

    if ( $module eq 'Test::Smoke' ) {
        $child_exit_status = 0;
        @output            = ();
    }
    else {
        ( $start_date, $end_date, $child_exit_status, @output ) =
            get_output_with_detached_execute_and_logfile( $logfile_suffix, $logfile_title,
                $SEARCH_FOR_MODULE_DEPENDENCY_TIMEOUT_IN_SECONDS,
                1, @cmd );
    }

    if ( !defined $child_exit_status ) {
        mark_module_as_not_found( $module );
        return undef;    # as not found
    }

    if ( $child_exit_status && !@output ) {
        say_ex( 'ERROR: search failed - exitcode - ' . $child_exit_status );
        mark_module_as_not_found( $module );
        return undef;    # as not found
    }

    if ( ( join '', @output ) =~ /Couldn't find module or a distribution/io ) {
        say_ex( 'ERROR: module not found - ' . $module );
        mark_module_as_not_found( $module );
        return undef;    # as not found
    }

    my %dependencies = ();

    my @dependencie_lines =
        grep { $_ =~ /Found dependencies: /io } @output;

    foreach my $line ( @dependencie_lines ) {
        if ( $line =~ /Found dependencies: (.+)/o ) {
            my @module_names = split /[,]/io, $1;
            foreach my $module_name ( @module_names ) {
                $module_name = trim( $module_name );
                $dependencies{ $module_name } = undef;
            }
        }
    }

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

    my %tmp = map {
        my @t = split /~/io, $_;

        if ( ( scalar @t ) <= 1 ) {
            $t[ 0 ] => undef;
        }
        else {
            $t[ 0 ] => $t[ 1 ];
        }
    } @output;

    foreach my $key ( keys %tmp ) {
        $dependencies{ $key } = $tmp{ $key };
    }

    say_ex( '' );
    say_ex( 'dependencies found: ' . scalar( keys %dependencies ) . "\n" . Dumper( \%dependencies ) );
    say_ex( '' );

    return \%dependencies;
}

sub reduce_dependency_modules_which_are_not_installed
{
    my %dependencies = @_;

    my %not_installed = ();

    foreach my $module ( keys %dependencies ) {
        if ( !exists $installed_module_version{ $module } ) {
            if ( exists $modules_install_ok{ $module } ) {
                # also check if module was installed, and system list currently not renewed
                say_ex( 'dependency already installed: ' . $module );
            }
            else {
                say_ex( 'dependency not installed: ' . $module );
                $not_installed{ $module } = $dependencies{ $module };
            }
        }
        elsif ( defined $dependencies{ $module } && defined $installed_module_version{ $module } ) {
            local $@;
            eval {
                my $installed_version = version->parse( $installed_module_version{ $module } );
                my $dependent_version = version->parse( $dependencies{ $module } );

                if ( ( $dependent_version cmp $installed_version ) == 1 ) {
                    say_ex( 'dependency old version - update needed: ' . $module );
                    $not_installed{ $module } = $dependencies{ $module };    # to old version
                }
                else {
                    say_ex( 'dependency installed and version check done: ' . $module );
                }
            };
            if ( $@ ) {
                say_ex( 'ERROR: dependency and version check failed for module: ' . $module );
                say_ex( 'ERROR: start $@ ->' );
                say_ex( '' );
                say_ex( "$@" );
                say_ex( '' );
                say_ex( 'ERROR: <- $@ ended' );
                say_ex( 'dependency - unknown handle as needed: ' . $module );
                $not_installed{ $module } = $dependencies{ $module };
            }
        }
        else {
            say_ex( 'dependency installed: ' . $module );
        }
    }

    return %not_installed;
}

sub get_not_installed_dependencies_for_module
{
    my ( $module ) = @_;

    my $dep_ref = fetch_dependencies_for_module( $module );
    if ( !defined $dep_ref ) {
        say_ex( 'module - ' . $module . ' - not found!' );

        return undef;
    }

    my %dep = %{ $dep_ref };
    if ( !%dep ) {
        say_ex( 'module - ' . $module . ' - has no dependencies' );

        return undef;
    }

    say_ex( 'module - ' . $module . ' - has dependencies - reduce to not installed' );
    %dep = reduce_dependency_modules_which_are_not_installed( %dep );
    if ( !%dep ) {
        say_ex( 'module - ' . $module . ' - has no uninstalled dependencies' );

        return undef;
    }

    say_ex( 'module - ' . $module . ' has not installed dependencies' . "\n" . Dumper( \%dep ) );

    return \%dep;
}

sub install_module_with_dependencies_first_recursive
{
    my ( $module ) = @_;

    if ( is_string_empty( $module ) ) {
        croak 'param module empty!';
    }

    state $recursion = 1;
    say_ex( '==> ' . 'install_module_with_dependencies_first_recursive - recursion level: ' . $recursion );

    if ( 10 < $recursion ) {
        croak "deep recursion level $recursion - abort!";
    }

    my $tried = was_module_already_tried( $module );
    if ( defined $tried ) {
        say_ex( '==> ' . "module already tried -> IGNORE - $module" );

        return $tried;
    }

    my $current_install_count = 0;
    my $new_install_count     = 0;

    my $analyze_run = 1;
    do {
        $current_install_count = scalar( keys %modules_install_ok );
        $new_install_count     = $current_install_count;

        # some modules change dependencies if all dependencies are installed, so recheck after install of dependencies
        say_ex( '==> ' . "analyze module (run #$analyze_run) - $module" );
        my $dep_ref = get_not_installed_dependencies_for_module( $module );
        if ( defined $dep_ref ) {
            my %dep = %{ $dep_ref };
            if ( %dep ) {
                foreach my $dep_module ( sort keys %dep ) {
                    say_ex( '==> ' . "install required dependency - '$dep_module' - for - '$module'" );
                    # only here - not at entry and every return.
                    $recursion++;
                    my $hasError = install_module_with_dependencies_first_recursive( $dep_module );
                    $recursion--;

                    if ( $hasError ) {
                        # mark module as failed, if dependent module not ok
                        mark_module_as_failed( $module );
                        return $hasError;
                    }
                }
            }
        }

        $new_install_count = scalar( keys %modules_install_ok );
        $analyze_run++;
    } while ( $current_install_count != $new_install_count );

    $current_install_count = scalar( keys %modules_install_ok );
    $new_install_count     = $current_install_count;

    my $hasError = install_single_module( $module );    # retval ignored - install count !

    print_and_log_intermediate_state();

    if ( $hasError ) {
        return $hasError;
    }

    $new_install_count = scalar( keys %modules_install_ok );
    if ( $current_install_count != $new_install_count ) {
        return 0;
    }
    else {
        return 1;    # hasError
    }
}

sub install_modules_sequentially
{
    say_ex( '==> ' . 'install all modules sequentially' );

    my $start_time           = time;
    my $install_target_count = scalar( keys %modules_need_to_install );
    my $remaining            = $install_target_count;
    my $check_i              = 0;

    my $module = q{};
    $module = ( sort keys %modules_need_to_install )[ 0 ];

    while ( $module ) {
        $check_i++;

        foreach ( 1 .. 10 ) {
            say_ex( '' );
        }

        my $tried = was_module_already_tried( $module );
        if ( defined $tried ) {
            say_ex( '==> ' . "module already tried -> IGNORE - ($check_i - $remaining) - $module" );

            $remaining = scalar( keys %modules_need_to_install );
            $module    = ( keys %modules_need_to_install )[ 0 ];
            next;
        }

        say_ex( '==> ' . "handle next install list module - ($check_i - $remaining) - $module ..." );

        install_module_with_dependencies_first_recursive( $module );

        say_ex( '==> ' . "... handle install list module - ($check_i - $remaining) - $module done" );

        $remaining = scalar( keys %modules_need_to_install );
        $module    = ( sort keys %modules_need_to_install )[ 0 ];

        my $now_time      = time;
        my $install_count = $install_target_count - $remaining;

        my $duration_total_seconds = $now_time - $start_time;
        my $duration_h             = floor( ( 0.0 + $duration_total_seconds ) / 3600 );
        my $duration_m             = floor( ( 0.0 + ( $duration_total_seconds - ( $duration_h * 3600 ) ) ) / 60 );
        my $duration_s             = floor( $duration_total_seconds - ( $duration_h * 3600 ) - ( $duration_m * 60 ) );
        my $duration_txt           = sprintf( '%02d:%02d:%02d', $duration_h, $duration_m, $duration_s );

        my $expect_total_seconds = ( ( 0.0 + $duration_total_seconds ) / $install_count ) * $remaining;
        my $expect_h             = floor( ( 0.0 + $expect_total_seconds ) / 3600 );
        my $expect_m             = floor( ( 0.0 + ( $expect_total_seconds - ( $expect_h * 3600 ) ) ) / 60 );
        my $expect_s             = floor( $expect_total_seconds - ( $expect_h * 3600 ) - ( $expect_m * 60 ) );
        my $expect_txt           = sprintf( '%02d:%02d:%02d', $expect_h, $expect_m, $expect_s );

        say_ex(   '==> '
                . "installed $install_count modules from start-list in $duration_txt (hh:mm:ss) - expect remaining $remaining modules needs $expect_txt (hh:mm:ss)"
        );

        print_and_log_intermediate_state();
    }

    return;
}

sub handle_main_arguments
{
    my ( $arg1, $arg2, $arg3 ) = @_;
    $arg1 = trim( $arg1 );
    $arg2 = trim( $arg2 );
    $arg3 = trim( $arg3 );

    my $filepath_install  = $EMPTY_STRING;
    my $filepath_dont_try = $EMPTY_STRING;
    my $only_all_updates  = $FALSE;
    my $all_updates       = $FALSE;

    if ( $arg1 eq '--only-all-updates' ) {
        $only_all_updates = $TRUE;

        if ( !is_string_empty( $arg2 ) ) {
            $filepath_dont_try = $arg2;
        }

        if ( !is_string_empty( $arg3 ) ) {
            croak 'wrong parameter set';
        }
    }
    elsif ( $arg1 eq '--all-updates' ) {
        $all_updates = $TRUE;
        if ( is_string_empty( $arg2 ) ) {
            croak 'wrong parameter set';
        }

        $filepath_install = $arg2;

        if ( !is_string_empty( $arg3 ) ) {
            $filepath_dont_try = $arg3;
        }
    }
    elsif ( is_string_empty( $arg1 ) ) {
        croak 'wrong parameter set';
    }
    else {
        $filepath_install = $arg1;

        if ( !is_string_empty( $arg2 ) ) {
            $filepath_dont_try = $arg2;
        }
    }

    $filepath_install  = trim( $filepath_install );
    $filepath_dont_try = trim( $filepath_dont_try );

    say_ex( '==> ' . 'filepath_install: ' . $filepath_install );
    say_ex( '==> ' . 'filepath_dont_try: ' . $filepath_dont_try );
    say_ex( '==> ' . 'only_all_updates: ' . ( $only_all_updates ? '1' : '0' ) );
    say_ex( '==> ' . 'all_updates: ' . ( $all_updates           ? '1' : '0' ) );

    return ( $filepath_install, $filepath_dont_try, $only_all_updates, $all_updates );
}

sub init_log_dir_path
{
    my $logdir = dirname( __FILE__ ) . '/../log';
    $log_dir_path = abs_path( $logdir );

    if ( is_string_empty( $log_dir_path ) ) {
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
        say_ex( '--only-all-updates: skip module list file import' );
    }
    else {
        if ( is_string_empty( $filepath_install ) ) {
            croak 'no file arg given';
        }

        import_module_list_from_file( $filepath_install );
    }

    if ( !is_string_empty( $filepath_dont_try ) ) {
        # mark modules as failed, some to old to build, other not for windows ...
        import_module_dont_try_list_from_file( $filepath_dont_try );
    }

    search_for_installed_modules();

    if ( $only_all_updates || $all_updates ) {
        search_for_modules_for_available_updates();
    }
    else {
        say_ex( 'no --all-updates or --only-all-updates: skip update module list import' );
    }

    generate_modules_need_to_install();

    print_and_log_full_summary();
    install_modules_sequentially();
    print_and_log_full_summary();

    return;
}

1;

__END__

#-----------------------------------------------------------------------------

=pod

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

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut
