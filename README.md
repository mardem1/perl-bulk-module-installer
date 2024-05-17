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
  
   `perl InstallCpanModules.pl MyModulesToInstallExample.txt` 

6. have a portable Windows-Perl with all modules :)

...

## DESCRIPTION

...

## INSTALLATION

...

## SUPPORT AND DOCUMENTATION

...

## BUG REPORTS

Please report bugs on GitHub.

The source code repository can be found at [https://github.com/mardem1/perl-bulk-module-installer](https://github.com/mardem1/perl-bulk-module-installer)

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
