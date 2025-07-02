<#

.SYNOPSIS

Remove Windows Defender exclusions, do a manual defender scan and creates a ZIP for the Strawberry directory.

.PARAMETER StrawberryDir

Path to Strawberry directory for zipping

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

$dir = Get-Item -LiteralPath $StrawberryDir

$packagedTimestmp = Get-Date -Format 'yyyyMMdd_HHmmss'

$targetPath = "$($dir.FullName)-packaged-$($packagedTimestmp).zip"

if ( Test-Path -LiteralPath $targetPath ) {
    throw "compress target $targetPath already exists"
}

Write-Host ''
$cpanCacheDir = "$StrawberryDir\data\.cpanm"
if ( ! ( Test-Path -LiteralPath $cpanCacheDir ) ) {
    Write-Host -ForegroundColor Green "no CPAN-Cache found '$cpanCacheDir' -> SKIP"
}
else {
    Write-Host -ForegroundColor Green "CPAN-Cache found '$cpanCacheDir' remove"
    Remove-Item -Recurse -Force -LiteralPath $cpanCacheDir
}

$hasAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ( ! $hasAdmin ) {
    Write-Host 'admin required for defender config -> SKIP'
}
else {
    Write-Host ''
    Write-Host -ForegroundColor Green '=> check defender config'
    Write-Host ''

    ( Get-MpPreference ).ExclusionPath | ForEach-Object { $_ } | Where-Object {
        # if none set $null given ? why
        ! [string]::IsNullOrWhiteSpace($_) -and (
            $_ -eq $StrawberryDir `
                -or $_.StartsWith($StrawberryDir) )
    } | ForEach-Object {
        Write-Host "remove defender exclude dir '$_'"
        Remove-MpPreference -ExclusionPath $_ -Force
    }

    ( Get-MpPreference ).ExclusionProcess | Where-Object {
        ! [string]::IsNullOrWhiteSpace($_) -and `
            $_.StartsWith($StrawberryDir)
    } | ForEach-Object {
        Write-Host "remove defender exclude process '$_'"
        Remove-MpPreference -ExclusionProcess $_ -Force
    }
}

Write-Host ''
Write-Host -ForegroundColor Green "zip '$StrawberryDir' as '$targetPath'"
# Compress-Archive is really slow
# Compress-Archive -LiteralPath $StrawberryDir -DestinationPath $targetPath -CompressionLevel Fastest
# use .Net direct
Add-Type -Assembly System.IO.Compression.Filesystem
[IO.Compression.ZipFile]::CreateFromDirectory(
    $StrawberryDir,
    $targetPath,
    [System.IO.Compression.CompressionLevel]::Optimal,# Fastest
    $false )

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$($MyInvocation.InvocationName)' ended"
Write-Host ''
