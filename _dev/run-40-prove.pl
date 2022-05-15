#!perl

use utf8;

use 5.010;

use strict;
use warnings;

our $VERSION = '0.01';

use Readonly;
use Path::This qw( $THISDIR );
use Cwd qw( getcwd abs_path );
use File::Find::Rule;
use English qw( -no_match_vars );

Readonly::Scalar my $SYSTEM_START_FAILURE     => -1;
Readonly::Scalar my $SYSTEM_CALL_SIGNAL_BIT   => 127;
Readonly::Scalar my $SYSTEM_CALL_COREDUMP_BIT => 127;
Readonly::Scalar my $EXITCODE_OFFSET          => 8;

sub reduce_filepath_to_relapth
{
    my ( $filepath ) = @_;

    my $cwd_abs_path = abs_path( getcwd() );
    if ( !$cwd_abs_path ) {
        return $filepath;
    }

    my $relpath = abs_path( $filepath );

    if ( !$relpath ) {
        return $filepath;
    }

    my $pos = index $relpath, $cwd_abs_path;
    if ( defined $pos && 0 == $pos ) {
        $relpath = substr $relpath, ( ( length $cwd_abs_path ) );
        if ( q{/} eq substr $relpath, 0, 1 ) {
            $relpath = q{.} . $relpath;
        }
    }

    return $relpath;
}

sub get_only_test_files
{
    my $include_test = File::Find::Rule->new()->file()->name( '*.t' );

    my $search = File::Find::Rule->new()->or( $include_test );

    my @files = $search->in( abs_path( $THISDIR . '/..' ) );

    @files = map { reduce_filepath_to_relapth( $_ ) } @files;

    return @files;
}

sub run_system_visible
{
    my ( @params ) = @_;

    say q{};
    say 'execute ' . ( join q{ }, @params );

    my $failure = system @params;

    if ( $failure ) {
        if ( $SYSTEM_START_FAILURE == $CHILD_ERROR ) {
            say "failed to execute: $ERRNO";
        }
        elsif ( $SYSTEM_CALL_SIGNAL_BIT & $CHILD_ERROR )    ## no critic (ProhibitBitwiseOperators)
        {
            ## no critic (ProhibitBitwiseOperators)
            printf "child died with signal %d, %s coredump\n", ( $SYSTEM_CALL_SIGNAL_BIT & $CHILD_ERROR ),
                ( $SYSTEM_CALL_COREDUMP_BIT & $CHILD_ERROR ) ? 'with' : 'without';
        }
        else {
            printf "child exited with value %d\n", $CHILD_ERROR >> $EXITCODE_OFFSET;
        }
    }

    say q{};

    return !!$failure;
}

sub run_prove
{
    my ( $filepath ) = @_;

    my $failure = run_system_visible( 'prove', $filepath );

    return !!$failure;
}

sub main
{

    # set include path for test
    local $ENV{ 'PERL5LIB' } = abs_path( $THISDIR . '/../lib' );

    my @test_files = get_only_test_files();

    my $failed_files = 0;

    foreach my $filepath ( @test_files ) {
        my $failure = run_prove( $filepath );

        if ( $failure ) {
            $failed_files++;
        }
    }

    if ( $failed_files ) {
        say q{};
        say q{};

        say 'ERROR: some files failed: ' . $failed_files;

        say q{};
        say q{};
    }
    else {
        say q{};
        say q{};

        say 'All Successful';

        say q{};
        say q{};
    }

    return;
}

main();

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

run-40-prove.pl

=head1 DESCRIPTION

Helper script to run a prove test on all test files.

=head1 AFFILIATION

This policy is part of L<Mardem::RefactoringPerlCriticPolicies>.

=head1 AUTHOR

Markus Demml, mardem@cpan.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2022, Markus Demml

This library is free software; you can redistribute it and/or modify it 
under the same terms as the Perl 5 programming language system itself. 
The full text of this license can be found in the LICENSE file included
with this module.

=cut
