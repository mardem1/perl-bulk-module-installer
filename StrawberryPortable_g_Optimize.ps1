<#

.SYNOPSIS

Removes CPAN-Cache data and merge perl lib dirs for performance

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
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $StrawberryDir,

    [switch] $NoMerge
)

$ScriptPath = ''
$transcript = $false

try {
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
    Write-Host -ForegroundColor Green "started '$ScriptPath' ..."
    Write-Host ''

    Write-Host ''
    $cpanCacheDir = "$StrawberryDir\data\.cpanm"
    if ( ! ( Test-Path -LiteralPath $cpanCacheDir ) ) {
        Write-Host -ForegroundColor Green "no CPAN-Cache found '$cpanCacheDir' -> SKIP"
    }
    else {
        Write-Host -ForegroundColor Green "CPAN-Cache found '$cpanCacheDir' remove"
        Remove-Item -Recurse -Force -LiteralPath $cpanCacheDir
    }

    if ( $NoMerge ) {
        Write-Host ''
        Write-Host -ForegroundColor Green 'NoMerge given - SKIP'
    }
    else {
        #
        # windows is fs-access sensitive so merge libs
        # @INC:
        #   strawberry/perl/site/lib/MSWin32-x64-multi-thread
        #   strawberry/perl/site/lib
        #   strawberry/perl/vendor/lib
        #   strawberry/perl/lib
        #

        Write-Host ''
        Write-Host -ForegroundColor Green 'merge and remove perl libs for improved performance'

        $perlDir = "$StrawberryDir\perl"

        $vendorDir = "$perlDir\vendor"
        if (Test-Path -LiteralPath $vendorDir) {
            $dirCount = @(Get-ChildItem -LiteralPath $vendorDir -Recurse -Directory -Force -ErrorAction Continue ).Count
            $fileCount = @(Get-ChildItem -LiteralPath $vendorDir -Recurse -File -Force -ErrorAction Continue ).Count
            Write-Host -ForegroundColor Green "copy and remove '$vendorDir' ($dirCount dirs, $fileCount files)"
            Copy-Item -Recurse -Path "$vendorDir\*" -Destination "$perlDir\" -Force -Confirm:$false -ErrorAction Stop
            Remove-Item -Path "$vendorDir" -Recurse -Force -Confirm:$false -ErrorAction Stop
        }

        $siteDir = "$perlDir\site"
        if (Test-Path -LiteralPath $siteDir) {
            $dirCount = @(Get-ChildItem -LiteralPath $siteDir -Recurse -Directory -Force -ErrorAction Continue ).Count
            $fileCount = @(Get-ChildItem -LiteralPath $siteDir -Recurse -File -Force -ErrorAction Continue ).Count
            Write-Host -ForegroundColor Green "copy and remove '$siteDir' ($dirCount dirs, $fileCount files)"
            Copy-Item -Recurse -Path "$siteDir\*" -Destination "$perlDir\" -Force -Confirm:$false -ErrorAction Stop
            Remove-Item -Path "$siteDir" -Recurse -Force -Confirm:$false -ErrorAction Stop
        }

        # perl\lib\MSWin32-x64-multi-thread instad of perl\site\lib\MSWin32-x64-multi-thread because before relocated !
        $ms32Dir = "$perlDir\lib\MSWin32-x64-multi-thread"
        if (Test-Path -LiteralPath $ms32Dir) {
            $dirCount = @(Get-ChildItem -LiteralPath $ms32Dir -Recurse -Directory -Force -ErrorAction Continue ).Count
            $fileCount = @(Get-ChildItem -LiteralPath $ms32Dir -Recurse -File -Force -ErrorAction Continue ).Count
            Write-Host -ForegroundColor Green "copy and remove '$ms32Dir' ($dirCount dirs, $fileCount files)"
            Copy-Item -Recurse -Path "$ms32Dir\*" -Destination "$perlDir\lib\" -Force -Confirm:$false -ErrorAction Stop
            Remove-Item -Path "$ms32Dir" -Recurse -Force -Confirm:$false -ErrorAction Stop
        }
    }

    exit 0
}
catch {
    Write-Host -ForegroundColor Red "ERROR: msg: $_"
    exit 1
}
finally {
    Write-Host ''
    Write-Host -ForegroundColor Green 'done'
    Write-Host ''
    Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
    Write-Host ''

    if ($transcript) {
        Stop-Transcript
    }
}