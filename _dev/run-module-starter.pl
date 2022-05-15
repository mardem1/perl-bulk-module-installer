#!perl

use utf8;

use 5.010;

use strict;
use warnings;

our $VERSION = '0.01';

use English qw( -no_match_vars );

use Module::Starter;

sub main
{
    local $EVAL_ERROR = undef;

    my $eval_ok_test = eval {
        Module::Starter->create_distro(
            'force'        => 1,
            'verbose'      => 1,
            'builder'      => 'Module::Build',
            'ignores_type' => [ 'git', 'generic' ],
            'license'      => 'perl',
            'genlicense'   => 1,
            'minperl'      => '5.010',
            'author'       => 'mardem',
            'email'        => 'mardem1@users.noreply.github.com',
            'distro'       => 'Mardem-RefactoringPerlCriticPolicies',
            'dir'          => 'Mardem-RefactoringPerlCriticPolicies',
            'modules'      => [
                'Mardem::RefactoringPerlCriticPolicies',
                'Mardem::RefactoringPerlCriticPolicies::Util',
                'Perl::Critic::Policy::Mardem::ProhibitBlockComplexity',
                'Perl::Critic::Policy::Mardem::ProhibitBlockComplexity',
                'Perl::Critic::Policy::Mardem::ProhibitConditionComplexity',
                'Perl::Critic::Policy::Mardem::ProhibitLargeBlock',
                'Perl::Critic::Policy::Mardem::ProhibitLargeSub',
                'Perl::Critic::Policy::Mardem::ProhibitManyConditionsInSub',
                'Perl::Critic::Policy::Mardem::ProhibitReturnBooleanAsInt',
            ],
        );

        return 'ok';
    };

    if ( $EVAL_ERROR ) {
        say 'ERROR: ' . $EVAL_ERROR;
        return 1;
    }
    elsif ( 'ok' ne $eval_ok_test ) {
        say 'ERROR: eval not ok?';
        return 1;
    }
    else {
        return 0;
    }
}

exit main();

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

run-module-starter.pl

=head1 DESCRIPTION

Reminder-Script to see, how the module/dist was started.

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
