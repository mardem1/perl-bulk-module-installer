<#

.SYNOPSIS

Creates a ZIP for the Strawberry directory

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

Write-Host ''
Write-Host -ForegroundColor Green "zip '$StrawberryDir' as '$targetPath'"
$zipStartTIme = Get-Date
Write-Host "zip start time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipStartTIme )"
# Compress-Archive is really slow
# Compress-Archive -LiteralPath $StrawberryDir -DestinationPath $targetPath -CompressionLevel Fastest
# use .Net direct
Add-Type -Assembly System.IO.Compression.Filesystem
[IO.Compression.ZipFile]::CreateFromDirectory(
    $StrawberryDir,
    $targetPath,
    [System.IO.Compression.CompressionLevel]::Optimal,# Fastest
    $false )
$zipEndTime = Get-Date
Write-Host "zip end time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipEndTime)"
Write-Host "zip duration $( (New-TimeSpan -Start $zipStartTIme -End $zipEndTime).TotalSeconds )"

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
Write-Host ''

Stop-Transcript