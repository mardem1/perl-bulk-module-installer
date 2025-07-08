package PerlBulkModuleInstallerTest;

use utf8;

use 5.010;

use strict;
use warnings;

use base qw( Test::Class );

use Test::More;
use Test::MockTime qw( set_absolute_time restore_time );
use POSIX          qw( strftime );
use Test::Output   qw( stdout_is );
use Test::MockModule;

use PerlBulkModuleInstaller qw();

sub my_setup : Test(setup)
{
    # diag( 'my_setup' );
}

sub my_teardown : Test(teardown)
{
    # diag( 'my_teardown' );
}

sub trim : Test(4)
{
    is( PerlBulkModuleInstaller::trim( ' t' ),    't' );
    is( PerlBulkModuleInstaller::trim( 't ' ),    't' );
    is( PerlBulkModuleInstaller::trim( ' t ' ),   't' );
    is( PerlBulkModuleInstaller::trim( 't t t' ), 't t t' );
}

sub str_replace : Test(2)
{
    is( PerlBulkModuleInstaller::str_replace( 'text', 't', 'a' ), 'aexa' );
    is( PerlBulkModuleInstaller::str_replace( 's:t',  ':', '_' ), 's_t' );
}

sub module_name_for_fs : Test(1)
{
    is( PerlBulkModuleInstaller::module_name_for_fs( 'My::Test::Module' ), 'My_Test_Module' );
}

sub get_timestamp_for_logline : Test(1)
{
    my $offset = strftime( "%z", localtime() );
    set_absolute_time( '2025-05-14T04:08:16' . $offset, '%Y-%m-%dT%H:%M:%S%z' );

    is( PerlBulkModuleInstaller::get_timestamp_for_logline(), '2025-05-14_04-08-16' );

    restore_time();
}

sub get_timestamp_pretty : Test(1)
{
    my $offset = strftime( "%z", localtime() );
    set_absolute_time( '2025-05-14T04:08:16' . $offset, '%Y-%m-%dT%H:%M:%S%z' );

    is( PerlBulkModuleInstaller::get_timestamp_pretty(), '2025-05-14 - 04-08-16' );

    restore_time();
}

sub get_timestamp_for_filename : Test(1)
{
    my $offset = strftime( "%z", localtime() );
    set_absolute_time( '2025-05-14T04:08:16' . $offset, '%Y-%m-%dT%H:%M:%S%z' );

    is( PerlBulkModuleInstaller::get_timestamp_for_filename(), '20250514_040816' );

    restore_time();
}

sub get_log_line : Test(1)
{
    my $offset = strftime( "%z", localtime() );
    set_absolute_time( '2025-05-14T04:08:16' . $offset, '%Y-%m-%dT%H:%M:%S%z' );

    is( PerlBulkModuleInstaller::get_log_line( 'some text' ), '# 2025-05-14_04-08-16 # some text' );

    restore_time();
}

sub say_ex : Test(1)
{
    my $offset = strftime( "%z", localtime() );
    set_absolute_time( '2025-05-14T04:08:16' . $offset, '%Y-%m-%dT%H:%M:%S%z' );

    stdout_is { PerlBulkModuleInstaller::say_ex( 'some text' ) } "# 2025-05-14_04-08-16 # some text\n";

    restore_time();
}

sub is_string_empty : Test(5)
{
    ok( PerlBulkModuleInstaller::is_string_empty( undef ) );
    ok( PerlBulkModuleInstaller::is_string_empty( '' ) );
    ok( !PerlBulkModuleInstaller::is_string_empty( 0 ) );
    ok( !PerlBulkModuleInstaller::is_string_empty( ' ' ) );
    ok( !PerlBulkModuleInstaller::is_string_empty( 'text' ) );
}

sub hashify : Test(5)
{
    my %got = PerlBulkModuleInstaller::hashify( 'a', 'b', 1 );
    my %exp = ( 'a' => undef, 'b' => undef, 1 => undef );
    is_deeply( \%got, \%exp );
}

sub read_file : Test(1)
{
    local $TODO = "test read_file currently unimplemented";
    fail();
}

sub write_file : Test(1)
{
    local $TODO = "test write_file currently unimplemented";
    fail();
}

sub get_output_with_detached_execute : Test(1)
{
    local $TODO = "test get_output_with_detached_execute currently unimplemented";
    fail();
}

sub get_output_with_detached_execute_and_logfile : Test(1)
{
    local $TODO = "test get_output_with_detached_execute_and_logfile currently unimplemented";
    fail();
}

sub mark_module_as_ok : Test(1)
{
    local $TODO = "test mark_module_as_ok currently unimplemented";
    fail();
}

sub mark_module_as_failed : Test(1)
{
    local $TODO = "test mark_module_as_failed currently unimplemented";
    fail();
}

sub mark_module_as_not_found : Test(1)
{
    local $TODO = "test mark_module_as_not_found currently unimplemented";
    fail();
}

sub was_module_already_tried : Test(1)
{
    local $TODO = "test was_module_already_tried currently unimplemented";
    fail();
}

sub reduce_modules_to_install_from_file : Test(1)
{
    local $TODO = "test reduce_modules_to_install_from_file currently unimplemented";
    fail();
}

sub print_install_state_summary : Test(1)
{
    local $TODO = "test print_install_state_summary currently unimplemented";
    fail();
}

sub dump_state_to_logfiles : Test(1)
{
    local $TODO = "test dump_state_to_logfiles currently unimplemented";
    fail();
}

sub print_install_end_summary : Test(1)
{
    local $TODO = "test print_install_end_summary currently unimplemented";
    fail();
}

sub search_for_installed_modules : Test(1)
{
    local $TODO = "test search_for_installed_modules currently unimplemented";
    fail();
}

sub fetch_dependencies_for_module : Test(1)
{
    my $mock = Test::MockModule->new( 'PerlBulkModuleInstaller' );
    $mock->mock(
        'get_output_with_detached_execute_and_logfile' => sub
        {
            # cmd.exe /c cpanm --no-interactive --showdeps Log::Log4perl
            return (
                '--> Working on Log::Log4perl',
                'Fetching http://www.cpan.org/authors/id/E/ET/ETJ/Log-Log4perl-1.57.tar.gz ... OK',
                'Configuring Log-Log4perl-1.57 ... OK',
                'ExtUtils::MakeMaker~6.58',
                'File::Spec~0.82',
                'File::Path~2.07',
                'ExtUtils::MakeMaker',
                'Test::More~0.88',
                'perl~5.006',
            );
        }
    );

    my %exp = (
        'ExtUtils::MakeMaker' => 6.58,
        'File::Spec'          => 0.82,
        'File::Path'          => 2.07,
        'ExtUtils::MakeMaker' => undef,
        'Test::More'          => 0.88,
        # perl~5.006
    );

    my $got_ref = PerlBulkModuleInstaller::fetch_dependencies_for_module( 'Log::Log4perl' );

    is_deeply( $got_ref, \%exp );

    $mock->unmock_all();
}

sub reduce_dependency_modules_which_are_not_installed : Test(1)
{
    local $TODO = "test reduce_dependency_modules_which_are_not_installed currently unimplemented";
    fail();
}

sub add_dependency_module_if_needed : Test(1)
{
    local $TODO = "test add_dependency_module_if_needed currently unimplemented";
    fail();
}

sub add_dependency_modules_for_modules_need_to_install : Test(1)
{
    local $TODO = "test add_dependency_modules_for_modules_need_to_install currently unimplemented";
    fail();
}

sub install_single_module : Test(1)
{
    local $TODO = "test install_single_module currently unimplemented";
    fail();
}

sub import_module_list_from_file : Test(1)
{
    local $TODO = "test import_module_list_from_file currently unimplemented";
    fail();
}

sub import_module_dont_try_list_from_file : Test(1)
{
    local $TODO = "test import_module_dont_try_list_from_file currently unimplemented";
    fail();
}

sub print_perl_detail_info : Test(1)
{
    local $TODO = "test print_perl_detail_info currently unimplemented";
    fail();
}

sub install_module_dep_version : Test(1)
{
    local $TODO = "test install_module_dep_version currently unimplemented";
    fail();
}

sub get_next_module_to_install_dep_version : Test(1)
{
    local $TODO = "test get_next_module_to_install_dep_version currently unimplemented";
    fail();
}

sub install_modules_dep_version : Test(1)
{
    local $TODO = "test install_modules_dep_version currently unimplemented";
    fail();
}

sub search_for_modules_for_available_updates : Test(1)
{
    local $TODO = "test search_for_modules_for_available_updates currently unimplemented";
    fail();
}

sub install_modules_sequentially : Test(1)
{
    local $TODO = "test install_modules_sequentially currently unimplemented";
    fail();
}

sub handle_main_arguments : Test(1)
{
    local $TODO = "test handle_main_arguments currently unimplemented";
    fail();
}

sub init_log_dir_path : Test(1)
{
    local $TODO = "test init_log_dir_path currently unimplemented";
    fail();
}

sub main : Test(1)
{
    local $TODO = "test main currently unimplemented";
    fail();
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
