﻿<#

.SYNOPSIS

Wrapper for InstallCpanModules.pl as PowerShell

Install perl modules in bulk with some logic to make this more efficient,
details can be found in the C<README.md>

.PARAMETER StrawberryDir

Dir for strawberry dir to install the modules

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
    [ValidateScript({
            $notFound = $false
            $_ | ForEach-Object {
                if ( [string]::IsNullOrWhiteSpace( $_ ) ) {
                    $notFound = $true
                }
                elseif ( $_ -notlike '*.txt' ) {
                    $notFound = $true
                }
                elseif ( ! ( Test-Path -LiteralPath $_ -PathType Leaf ) ) {
                    $notFound = $true
                }
            }
            ! $notFound
        })]
    [string[]] $InstallModuleListFile,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $DontTryModuleListFile,

    [switch] $OnlyAllUpdates,

    [switch] $AllUpdates
)

$ScriptPath = $MyInvocation.InvocationName
# Invoked wiht &
if ( $ScriptPath -eq '&' -and
    $null -ne $MyInvocation.MyCommand -and
    ! [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path) ) {
    $ScriptPath = $MyInvocation.MyCommand.Path
}

$ScriptItem = Get-Item -LiteralPath $ScriptPath -ErrorAction Stop
Start-Transcript -LiteralPath "$($ScriptItem.Directory.FullName)\log\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($ScriptItem.BaseName).log"

$InstallCpanModules = "$($ScriptItem.Directory.FullName)\InstallCpanModules.pl"

Write-Host ''
Write-Host -ForegroundColor Green "started '$ScriptPath' ..."
Write-Host ''

$PathExtends = "$($StrawberryDir)\perl\site\bin;$($StrawberryDir)\perl\bin;$($StrawberryDir)\c\bin"
if ( $env:Path -notlike "*$PathExtends*" ) {
    $Env:PATH = "$PathExtends;$Env:PATH"
}

$perlexe = $StrawberryDir + '\perl\bin\perl.exe'
& $perlexe -MConfig -e 'printf(qq{Perl executable: %s\nPerl version   : %s / $Config{archname}\n\n}, $^X, $^V)' | Out-String | Write-Host -ForegroundColor Green

if ( 0 -ne $LASTEXITCODE) {
    Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
    exit
}

# for PerlBulkModuleInstaller
$Env:PERL5LIB = "$((Get-Item -LiteralPath $InstallCpanModules).Directory.FullName)\lib".Replace('\', '/')

$InstallModuleListFile | ForEach-Object {
    $listfile = $_

    0..25 | ForEach-Object { Write-Host '' }
    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with '$listfile'"
    Write-Host ''

    # TODO: replace with Start-Process and created ARGV
    if ( [string]::IsNullOrWhiteSpace($DontTryModuleListFile) ) {
        if ( $OnlyAllUpdates ) {
            & $perlexe $InstallCpanModules '--only-all-updates' $listfile | Write-Host
        }
        elseif ( $AllUpdates ) {
            & $perlexe $InstallCpanModules '--all-updates' $listfile | Write-Host
        }
        else {
            & $perlexe $InstallCpanModules $listfile | Write-Host
        }
    }
    else {
        if ( $OnlyAllUpdates ) {
            & $perlexe $InstallCpanModules '--only-all-updates' $listfile $DontTryModuleListFile | Write-Host
        }
        elseif ( $AllUpdates ) {
            & $perlexe $InstallCpanModules '--all-updates' $listfile $DontTryModuleListFile | Write-Host
        }
        else {
            & $perlexe $InstallCpanModules $listfile $DontTryModuleListFile | Write-Host
        }
    }

    if ( 0 -ne $LASTEXITCODE) {
        Write-Host -ForegroundColor Red "FATAL ERROR: '$InstallCpanModules' with '$LASTEXITCODE' failed?"
    }
}

0..25 | ForEach-Object { Write-Host '' }

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
Write-Host ''

Stop-Transcript