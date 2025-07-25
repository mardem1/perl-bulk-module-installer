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
}

use PerlBulkModuleInstaller qw( say_ex main );

$| = 1;

say_ex( '==> ' . "started $0" );

main( @ARGV );

say_ex( '==> ' . "ended $0" );

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

InstallCpanModules.pl [ --all-updates ] filepath_install [ filepath_dont_try  [ filepath_no_tests ] ]

InstallCpanModules.pl --only-all-updates [ filepath_dont_try  [ filepath_no_tests ] ]

=head1 DESCRIPTION

Install perl modules in bulk with some logic to make this more efficient,
details can be found in the C<README.md>

=head1 PARAMETERS

=over 12

=item C<filepath_dont_try>

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) which will not be installed.
One Name per Line, # marks a comment line, Linux-Line-Ends preferred but all work's.

=item C<filepath_no_tests>

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) which will be installed without execution of tests.
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

Install all available module updates, if not given updates are only installed,
if a module require a new version of a module.

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

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut
