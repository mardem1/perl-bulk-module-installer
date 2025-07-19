
<#

.SYNOPSIS

Removes CPAN-Cache data and merge perl lib dirs for performance.

.PARAMETER StrawberryDir

Path to Strawberry directory for zipping

.PARAMETER MergeLibs

Merge of additional-libs in single main-lib-dir

Windows is sensitive for file-access, so reduce lib search-path for better performance

From:
* "site/lib/MSWin32-x64-multi-thread"
* "site/lib"
* "vendor/lib"

To:
* "lib"

.PARAMETER RemoveBuildTools

Removes strawberry perl package build tools, not needed only to run perl without module installations.

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
    [string] $StrawberryDir,

    [switch] $MergeLibs,

    [switch] $RemoveBuildTools
)

$ScriptStartTime = Get-Date
$ScriptPath = ''
$transcript = $false
$ori_ErrorActionPreference = $Global:ErrorActionPreference

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

    Write-Host ''
    $cpanCacheDir = "$StrawberryDir\data\.cpanm"
    if ( ! ( Test-Path -LiteralPath $cpanCacheDir ) ) {
        Write-Host -ForegroundColor Green "no CPAN-Cache found '$cpanCacheDir' -> SKIP"
    }
    else {
        Write-Host -ForegroundColor Green "CPAN-Cache found '$cpanCacheDir' remove"
        Remove-Item -Recurse -Force -LiteralPath $cpanCacheDir
    }

    if ( ! $MergeLibs ) {
        Write-Host ''
        Write-Host -ForegroundColor Green 'NO MergeLibs given - SKIP'
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

    if ( ! $RemoveBuildTools ) {
        Write-Host ''
        Write-Host -ForegroundColor Green 'NO RemoveBuildTools given - SKIP'
    }
    else {
        Write-Host ''
        Write-Host -ForegroundColor Green 'remove strawberry perl module build tools'

        Write-Host ''
        $cDir = "$StrawberryDir\c"
        if ( ! ( Test-Path -LiteralPath $cDir ) ) {
            Write-Host -ForegroundColor Green "no C found '$cDir' -> SKIP"
        }
        else {
            Write-Host -ForegroundColor Green "C found '$cDir' -> clean it"
            Get-ChildItem -LiteralPath $cDir -Directory | Where-Object {
                $_.Name -ne 'bin'
            } | ForEach-Object {
                $sname = $_.Name
                $sfullname = $_.FullName

                Write-Host "subdir $sname clean"
                Get-ChildItem -LiteralPath $sfullname -Recurse -File | ForEach-Object {
                    $fullname = $_.FullName
                    Write-Host "remove file: '$fullname'"
                    Remove-Item -LiteralPath $fullname -Force
                }
                Get-ChildItem -LiteralPath $sfullname -Recurse | Sort-Object -Property FullName -Descending | ForEach-Object {
                    $fullname = $_.FullName
                    Write-Host "remove dir: '$fullname'"
                    Remove-Item -LiteralPath $fullname -Force -Recurse
                }

                Write-Host "remove dir: '$sfullname'"
                Remove-Item -LiteralPath $sfullname -Force -Recurse
            }
        }

        Write-Host ''
        $cbinDir = "$StrawberryDir\c\bin"
        if ( ! ( Test-Path -LiteralPath $cbinDir ) ) {
            Write-Host -ForegroundColor Green "no C-BIN found '$cbinDir' -> SKIP"
        }
        else {
            Write-Host -ForegroundColor Green "C-BIN found '$cbinDir' -> clean it"
            Get-ChildItem -LiteralPath $cbinDir -Recurse -File | Where-Object {
                $_.Name -notlike '*-config' -and $_.Extension -ne '.dll'
            } | ForEach-Object {
                $fullname = $_.FullName
                Write-Host "remove: '$fullname'"
                Remove-Item -LiteralPath $fullname -Force
            }
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
    $ScriptEndTime = Get-Date
    $durationMinutes = (New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime).TotalMinutes
    Write-Host -ForegroundColor Green "Script '$ScriptPath' ended at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $ScriptEndTime ) - duration $durationMinutes minutes"
    Write-Host ''

    if ($transcript) {
        Stop-Transcript
    }

    $Global:ErrorActionPreference = $ori_ErrorActionPreference
}
