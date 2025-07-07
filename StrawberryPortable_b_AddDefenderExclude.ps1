<#

.SYNOPSIS

Configure Windows Defender for more performance.

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
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $StrawberryDir
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

Write-Host ''
Write-Host -ForegroundColor Green "started '$ScriptPath' ..."
Write-Host ''

$hasAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ''
if ( ! $hasAdmin ) {
    Write-Host -ForegroundColor Red 'ERROR: admin required for defender config!'
    Write-Host ''
    Write-Host -ForegroundColor Green 'done'
    Write-Host ''
    Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
    Write-Host ''

    Stop-Transcript
    exit
}

Write-Host -ForegroundColor Green "add defender exclude dir '$StrawberryDir'"
Add-MpPreference -ExclusionPath $StrawberryDir -Force

Get-ChildItem -Recurse -File -LiteralPath $StrawberryDir -Force -Filter '*.exe' | ForEach-Object {
    Write-Host -ForegroundColor Green "add defender exclude process '$_'"
    Add-MpPreference -ExclusionProcess $_ -Force
}

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
Write-Host ''

Stop-Transcript