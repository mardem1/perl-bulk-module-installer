# Perl Bulk Modules Installer

Install perl modules in bulk with some logic to make this more efficient.

## VISION / PURPOSE

1. get a portable Windows-Perl from [Strawberry](https://strawberryperl.com/releases.html)

2. open Perl-Location with `portableshell.bat`

3. update all current (base) modules

   ```
   cmd.exe /c cpanm App::cpanoutdated
   cmd.exe /c cpan-outdated -p
   cmd.exe /c cpan-outdated -p | cpanm
   ```

4. install required modules

   ```
   cmd.exe /c cpanm Carp Carp::Always Data::Dumper
   ```

5. run bulk-installer to add all wanted modules

   ```
   perl InstallCpanModules.pl [ --only-all-updates | --no-updates ] filepath_install [ filepath_dont_try ]
   perl InstallCpanModules.pl test-module-lists/SmallModuleExample.txt test-module-lists/_dont_try_modules.txt
   ```

6. have a portable Windows-Perl with all wanted modules :)

## DESCRIPTION

One problem with cpanm is that it don't save/cache a failed installation state.
If a module needs a module which was already tried cpanm will try it again
If you install many modules, and not all are working correctly it will waste
much time, and the installation of modules is already not fast :(

So the main enhancement of this script should be this cache of failed
or not-found dependencies to speed up a bootstrap installation of many modules.

For every external process call (perl/cpanm) there will be a logfile in the
log-subfolder with the call information, start/end time, exitcode and the
complete output.

Logfiles:

* `DATE`_`TIME`_perl_detail_info.log
    * Perl-System-Information `perl -V`
* `DATE`_`TIME`_installed_modules_found.log
    * Perl-Modules found via `cpan -l`
* `DATE`_`TIME`_modules_to_install_from_file.log
    * Modules listed in the given file to install.
* `DATE`_`TIME`_modules_install_already.log
    * Modules from file already installed.
* `DATE`_`TIME`_modules_need_to_install.log
    * Modules from files needs to be installed.
* `DATE`_`TIME`_modules_to_install_with_deps_extended.log
    * analyze result - modules need to install/update with their direct dependencies.
* `DATE`_`TIME`_modules_with_available_updates.log
    * list of modules with an update available, analyzed by `cpan-outdated --exclude-core -p`
* `DATE`_`TIME`_modules_install_not_found.log
    * list of modules which are not found, via cpan.
* `DATE`_`TIME`_modules_install_failed.log
    * list of modules where the installation failed.
* `DATE`_`TIME`\_fetch_dependency__`MODULENAME`.log
    * output of list dependency call `cpanm --no-interactive --showdeps MODULENAME`
* `DATE`_`TIME`\_install_module__`MODULENAME`__`install|update`-`success|failed|failed-start`.log
    * output of install/update call. Type and result are in filename. 
    * Installed via `cpanm --verbose --no-interactive MODULENAME`

Script process:

1. import module list - if not update-only
2. check installed modules
3. search for installed modules
4. search for missing dependency modules
5. search for available update of installed modules - if not no-updates
6. now the installation loop
    1. get the next module which has no found dependency, or abort of there is none.
    2. re-check dependencies - but there should be noting.
    3. try to install module
    4. if ok remove this module from the dependency list of each module, if listed
    5. if not ok mark all modules which depend on this als failed, and all which depend on them - and so on - recursion
    6. mark this module als installed or failed.
    7. repeat loop

## BUG REPORTS

Please report bugs on GitHub.

The source code repository can be found
at [https://github.com/mardem1/perl-bulk-module-installer](https://github.com/mardem1/perl-bulk-module-installer)

## AUTHOR

Markus Demml, mardem@cpan.com

## LICENSE AND COPYRIGHT

Copyright (c) 2025, Markus Demml

This library is free software; you can redistribute it and/or modify it
under the same terms as the Perl 5 programming language system itself.
The full text of this license can be found in the LICENSE file included
with this module.

## DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.
