# Perl Bulk Module Installer

...

## PURPOSE

Install multiple perl modules with some logic to make this more efficient.

Vision:

1. get a portable Windows-Perl from [Strawberry](https://strawberryperl.com/releases.html)

2. open Perl-Location with `portableshell.bat`

3. update all current (base) modules

   ```
   cmd.exe /c cpanm App::cpanoutdated
   cmd.exe /c cpan-outdated -p
   cmd.exe /c cpan-outdated -p | cpanm
   ```

4. install needed modules

   `cmd.exe /c cpanm Carp Carp::Always Data::Dumper`

5. run bulk-installer to add all needed modules

   `perl InstallCpanModules.pl test-module-lists/SmallModuleExample.txt`

6. have a portable Windows-Perl with all modules :)

One problem with cpanm is that it don't save/cache a failed installation state.
If a module needs a module which was already tried cpanm will try it again.
If you install many module, and not all working correctly it will waste much
time and, the installation of modules is already not fast :(

So the main enhancement of this script should be this cache of failed
or not-found dependencies to speed up a bootstrap installation of many modules.

1. check installed modules
2. update all installed modules
3. now the installation loop
4. check dependent modules of current module
5. install dependent modules if not yet tried - abort if failed - recursion possible !
6. install module
7. repeat - restart at 4 with next module.

Note: maybe get all dependencies upfront, as to install modules - speedup?

...

## DESCRIPTION

...

## INSTALLATION

...

## SUPPORT AND DOCUMENTATION

...

## BUG REPORTS

Please report bugs on GitHub.

The source code repository can be found
at [https://github.com/mardem1/perl-bulk-module-installer](https://github.com/mardem1/perl-bulk-module-installer)

## AUTHOR

Markus Demml, mardem@cpan.com

## LICENSE AND COPYRIGHT

Copyright (c) 2024, Markus Demml

This library is free software; you can redistribute it and/or modify it
under the same terms as the Perl 5 programming language system itself.
The full text of this license can be found in the LICENSE file included
with this module.

## DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.
