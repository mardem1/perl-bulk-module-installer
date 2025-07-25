use utf8;

use 5.010;

use strict;
use warnings;

BEGIN {
    if ( $^O !~ /win32/io ) {
        die 'sorry this is only for windows :(';
    }
}

BEGIN {
    use File::Basename qw(dirname);
    use lib dirname( __FILE__ ) . '/lib';
    use lib dirname( __FILE__ ) . '/t';
}

use Test::Class;

use PerlBulkModuleInstallerTest qw();

$| = 1;

Test::Class->runtests;

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
