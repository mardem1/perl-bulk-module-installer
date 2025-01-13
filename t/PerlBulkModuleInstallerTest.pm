package PerlBulkModuleInstallerTest;

use utf8;

use 5.010;

use strict;
use warnings;

use base qw( Test::Class );
use Test::More;

sub my_setup : Test(setup)
{
    diag( 'my_setup' );
}

sub test_dummy : Test(1)
{
    ok( 1 == 1, 'test_dummy' );
}

sub my_teardown : Test(teardown)
{
    diag( 'my_teardown' );
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

Copyright (c) 2025, Markus Demml

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut
