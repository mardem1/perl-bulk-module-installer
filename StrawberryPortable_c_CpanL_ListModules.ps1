<#

.SYNOPSIS

List all installed modules via cpan -l

.PARAMETER StrawberryDir

Dir for strawberry dir to install the modules

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
    [string] $StrawberryDir
)

Write-Host ''
Write-Host -ForegroundColor Green "started '$($MyInvocation.InvocationName)' ..."
Write-Host ''

$PathExtends = "$($StrawberryDir)\perl\site\bin;$($StrawberryDir)\perl\bin;$($StrawberryDir)\c\bin"
if ( $env:Path -notlike "*$PathExtends*" ) {
    $Env:PATH = "$PathExtends;$Env:PATH"
}

$perlexe = $StrawberryDir + '\perl\bin\perl.exe'
& $perlexe -MConfig -e 'printf(qq{Perl executable: %s\nPerl version   : %vd / $Config{archname}\n\n}, $^X, $^V)' | Out-String | Write-Host -ForegroundColor Green

if ( 0 -ne $LASTEXITCODE) {
    Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
    exit
}

# TODO: replace with Start-Process and created ARGV

Write-Host -ForegroundColor Green '=> search modules via cpan -l ...'
( & cmd.exe '/c' 'cpan.bat' '-l' '2>&1' )
Write-Host -ForegroundColor Green '=> ... module list generated'

if ( 0 -ne $LASTEXITCODE) {
    Write-Host -ForegroundColor Red "FATAL ERROR: '$InstallCpanModules' with '$LASTEXITCODE' failed?"
}

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$($MyInvocation.InvocationName)' ended"
Write-Host ''
