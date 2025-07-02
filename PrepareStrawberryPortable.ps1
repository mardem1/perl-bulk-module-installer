
<#

.SYNOPSIS

Extracts the Strawberry ZIP and configure Windows Defender for more performance.

.PARAMETER StrawberryZip

Path to Strawberry ZIP portable.

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
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*strawberry*portable*.zip' })]
    [string] $StrawberryZip
)

Write-Host ''
Write-Host -ForegroundColor Green "started '$($MyInvocation.InvocationName)' ..."

$hasAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$zip = Get-Item -LiteralPath $StrawberryZip
$targetPath = "$($zip.Directory.FullName)\$($zip.BaseName)"

if ( Test-Path -LiteralPath $targetPath ) {
    throw "extraction target $targetPath already exists"
}

Write-Host ''
Write-Host -ForegroundColor Green "unzip '$StrawberryZip' to '$targetPath'"
$zipStartTIme = Get-Date
Write-Host "unzip start time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipStartTIme )"
# Expand-Archive is really slow
# Expand-Archive -LiteralPath $StrawberryZip -DestinationPath $targetPath
# use .Net direct
Add-Type -Assembly System.IO.Compression.Filesystem
[IO.Compression.ZipFile]::ExtractToDirectory(
    $StrawberryZip,
    $targetPath,
    $true )
$zipEndTime = Get-Date
Write-Host "unzip end time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipEndTime)"
Write-Host "unzip duration $( (New-TimeSpan -Start $zipStartTIme -End $zipEndTime).TotalSeconds )"

Write-Host ''
if ( ! $hasAdmin ) {
    Write-Host -ForegroundColor Yellow 'admin required for defender config -> SKIP'
}
else {
    Write-Host -ForegroundColor Green "add defender exclude dir '$targetPath'"
    Add-MpPreference -ExclusionPath $targetPath -Force

    Get-ChildItem -Recurse -File -LiteralPath $targetPath -Force -Filter '*.exe' | ForEach-Object {
        Write-Host -ForegroundColor Green "add defender exclude process '$_'"
        Add-MpPreference -ExclusionProcess $_ -Force
    }
}

Write-Host ''
Write-Host -ForegroundColor Green 'done'

Write-Host ''
Write-Host -ForegroundColor Green "... '$($MyInvocation.InvocationName)' ended"

Write-Host ''
