<#

.SYNOPSIS

Wrapper for InstallCpanModules.pl as PowerShell

Install perl modules in bulk with some logic to make this more efficient,
details can be found in the C<README.md>

.PARAMETER StrawberryDir

Dir for strawberry dir to install the modules

.PARAMETER InstallCpanModules

Path to script InstallCpanModules.pl

.PARAMETER InstallModuleListFile

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) to
install. One Name per Line, # marks a comment line Linux-Line-Ends preferred but all work's.

.PARAMETER DontTryModuleListFIle

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) which will not be installed.
One Name per Line, # marks a comment line, Linux-Line-Ends preferred but all work's.

.PARAMETER OnlyAllUpdates

Only update installed modules, no modules from a given filelist will be
installed.

Attention: If a new module version has a additional dependency, this dependency
will be installed!

.PARAMETER AllUpdates

Do not install updates for modules, exception a new module require a module
update as dependency.

.NOTES

BUG REPORTS

Please report bugs on GitHub.

The source code repository can be found
at https://github.com/mardem1/perl-bulk-module-installer

AUTHOR

Markus Demml, mardem@cpan.com

LICENSE AND COPYRIGHT

Copyright (c) 2025, Markus Demml

This library is free software; you can redistribute it and/or modify it
under the same terms as the Perl 5 programming language system itself.
The full text of this license can be found in the LICENSE file included
with this module.

DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [ValidateScript({ $_ -like '*strawberry*portable*' })]
    [string] $StrawberryDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*InstallCpanModules.pl' })]
    [string] $InstallCpanModules,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $InstallModuleListFile,

    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $DontTryModuleListFIle,

    [switch] $OnlyAllUpdates,

    [switch] $AllUpdates
)

Write-Host ''
Write-Host -ForegroundColor Green "started '$($MyInvocation.InvocationName)' ..."
Write-Host ''

# TODO: implement

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$($MyInvocation.InvocationName)' ended"
Write-Host ''
