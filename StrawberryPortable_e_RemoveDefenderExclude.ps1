﻿
<#

.SYNOPSIS

Remove Windows Defender exclusions.

.PARAMETER StrawberryDir

Path to Strawberry directory

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
    # [ValidateScript({ $_ -like '*strawberry*portable*' })]
    # better test perl.exe location, path name not the point
    [ValidateScript({ $_ -like '*strawberry*' })]
    [ValidateScript({ Test-Path -LiteralPath "$_\perl\bin\perl.exe" -PathType Leaf })]
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $StrawberryDir
)

$ScriptStartTime = Get-Date
$ScriptPath = ''
$transcript = $false
$ori_ErrorActionPreference = $Global:ErrorActionPreference
$ori_Location = (Get-Location ).Path

try {
    $Global:ErrorActionPreference = 'Stop'

    $ScriptPath = $MyInvocation.InvocationName
    # Invoked wiht &
    if ( $ScriptPath -eq '&' -and
        $null -ne $MyInvocation.MyCommand -and
        ! [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path) ) {
        $ScriptPath = $MyInvocation.MyCommand.Path
    }

    $ScriptItem = Get-Item -LiteralPath $ScriptPath -ErrorAction Stop
    Start-Transcript -LiteralPath "$($ScriptItem.Directory.FullName)\log\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($ScriptItem.BaseName).log" -ErrorAction Stop
    $transcript = $true

    Write-Host ''
    Write-Host -ForegroundColor Green "Script '$ScriptPath' started at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $ScriptStartTime )"
    Write-Host ''

    $hasAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Write-Host ''
    if ( ! $hasAdmin ) {
        Write-Host -ForegroundColor Red 'ERROR: admin required for defender config!'
        throw 'admin required'
    }

    Write-Host ''
    Write-Host -ForegroundColor Green '=> check defender config'
    Write-Host ''

    ( Get-MpPreference ).ExclusionPath | ForEach-Object { $_ } | Where-Object {
        # if none set $null given ? why
        ! [string]::IsNullOrWhiteSpace( $_ ) -and (
            $_ -eq $StrawberryDir `
                -or $_.StartsWith($StrawberryDir) )
    } | ForEach-Object {
        Write-Host "remove defender exclude dir '$_'"
        Remove-MpPreference -ExclusionPath $_ -Force
    }

    ( Get-MpPreference ).ExclusionProcess | Where-Object {
        ! [string]::IsNullOrWhiteSpace( $_ ) -and `
            $_.StartsWith($StrawberryDir)
    } | ForEach-Object {
        Write-Host "remove defender exclude process '$_'"
        Remove-MpPreference -ExclusionProcess $_ -Force
    }

    exit 0
}
catch {
    Write-Host -ForegroundColor Red "ERROR: msg: $_"
    exit 1
}
finally {
    if ( $ori_Location -ne (Get-Location ).Path) {
        Write-Host "Set-Location $ori_Location"
        Set-Location $ori_Location
    }

    Write-Host ''
    Write-Host -ForegroundColor Green 'done'
    Write-Host ''
    $ScriptEndTime = Get-Date
    $durationMinutes = (New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime).TotalMinutes
    Write-Host -ForegroundColor Green "Script '$ScriptPath' ended at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $ScriptEndTime ) - duration $durationMinutes minutes"
    Write-Host ''

    if ($transcript) {
        Stop-Transcript
    }

    $Global:ErrorActionPreference = $ori_ErrorActionPreference
}
