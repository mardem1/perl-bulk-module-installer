
<#

.SYNOPSIS

Browse one or more directories for perl files and search for used perl modules.

.PARAMETER SearchPath

Directories to search in.

.PARAMETER ModuleListFileTxt

Save result as List-File which can be used for PerlBulkModuleInstaller as Install-List.

Also generates similar named PL file wich can be used for a compile check "perl -c".

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
    [ValidateScript({
            $notFound = $false
            $_ | ForEach-Object {
                if ( [string]::IsNullOrWhiteSpace( $_ ) ) {
                    $notFound = $true
                }
                elseif ( ! ( Test-Path -LiteralPath $_ -PathType Container ) ) {
                    $notFound = $true
                }
            }
            ! $notFound
        })]
    [string[]] $SearchPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf -IsValid })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $ModuleListFileTxt
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

    # BAT files for perl in batch wrapper
    $extensions = ( '.pl', '.pm', '.bat', '.t' )

    [hashtable] $modules = @{}
    [hashtable] $foundPerlFiles = @{}

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished
    $winUser = $env:USERNAME
    $winHostName = $env:COMPUTERNAME
    $winOs = ( Get-CimInstance Win32_OperatingSystem ).Caption
    $ModuleListFilePl = $ModuleListFileTxt.Replace('.txt', '.pl')
    $PerlFilesListFileTxt = $ModuleListFileTxt.Replace('.txt', '.perlfiles.txt')

    Write-Host -ForegroundColor Green '=> search for files ...'
    Write-Host -ForegroundColor Green '  => with extensions:'
    $extensions | ForEach-Object {
        Write-Host -ForegroundColor Green "    => $_"
    }
    Write-Host -ForegroundColor Green '  => in directories:'
    $SearchPath | ForEach-Object {
        Write-Host -ForegroundColor Green "    => $_"
    }

    $files = Get-ChildItem -Recurse -File -Force -LiteralPath $SearchPath -ErrorAction Continue | Where-Object {
        $_.Extension -in $extensions
    } | Where-Object {
        $_.FullName -ne $ModuleListFilePl # exclude self generated list
    } | Where-Object {
        $true
        # INFO: add custom filter here - exclude ?
    }

    Write-Host -ForegroundColor Green '=> matching files found - analyze ...'
    $files | ForEach-Object {
        $FullName = $_.FullName
        Write-Host -ForegroundColor DarkGray "=> check found file: '$FullName'"

        $_ | Get-Content | ForEach-Object {
            # Upper-Case defined as first character for none core / standard modules
            # should match => 'use XYZ...ABC;' 'use XYZ...ABC (..);'  'use XYZ...ABC qw(..);' 'use XYZ...ABC qw(' 'use XYZ...ABC'
            # ending exclude ^: needed to exclude "use C:"
            if ( $_ -cmatch '\buse\b\s+(([A-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
                $text = $Matches[1]

                # INFO: add custom filter here - exclude own modules ?
                if ( $true ) {
                    Write-Host -ForegroundColor Yellow "  => found module: '$text'"
                    $modules[$text] = $true
                    if ( ! $foundPerlFiles.ContainsKey( $FullName ) ) {
                        Write-Host -ForegroundColor Yellow "  => add new perl file with used module: '$FullName'"
                        $foundPerlFiles[$FullName] = $null # add
                    }
                }
            }
        }
    }

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished

    Write-Host ''
    Write-Host -ForegroundColor Green '=> filter unique'
    $moduleNames = $($modules.Keys | Select-Object -Unique | Sort-Object )

    Write-Host '=> create Modules use'
    $modulesUse = $moduleNames | ForEach-Object { "use $_ qw();" }
    Write-Host ''

    Write-Host ''
    Write-Host -ForegroundColor Green '=> Modules plain'
    $moduleNames | ForEach-Object { "$_" }

    Write-Host ''
    Write-Host -ForegroundColor Green '=> filter unique files'
    $perlFilePaths = $($foundPerlFiles.Keys | Select-Object -Unique | Sort-Object )

    Write-Host ''
    Write-Host -ForegroundColor Green '=> Perl-Files'
    $perlFilePaths | ForEach-Object { "$_" }

    $fileHeaders = (
        '#',
        '# => search for files',
        '#  => with extensions:'
    )
    $fileHeaders += $extensions | ForEach-Object { "#   - $_" }

    $fileHeaders += (
        '#  => in directories:'
    )
    $fileHeaders += $SearchPath | ForEach-Object { "#   - $_" }

    $fileHeaders += (
        '#',
        "# Win-User     : $winUser",
        "# Win-Host     : $winHostName",
        "# Win-OS       : $winOs"
    )

    $fileHeaders += (
        '#',
        "# search done at '$now'"
    )

    $modulesHeaders = (
        '#',
        '# modules found:',
        '#',
        '' # empty line before list
    )

    $perlFilesHeaders = (
        '#',
        '# found in perl files:',
        '#',
        '' # empty line before list
    )

    $fileFooters = (
        '', # empty line after list
        '#',
        '# list ended',
        '#'
    )

    if ( ! $moduleNames ) {
        if ( Test-Path -LiteralPath $ModuleListFileTxt ) {
            Write-Host "remove modules txt file $ModuleListFileTxt"
            Remove-Item -LiteralPath $ModuleListFileTxt
        }

        if ( Test-Path -LiteralPath $ModuleListFilePl ) {
            Write-Host "remove modules pl file $ModuleListFilePl"
            Remove-Item -LiteralPath $ModuleListFilePl
        }

        if ( Test-Path -LiteralPath $PerlFilesListFileTxt ) {
            Write-Host "remove perlfiles txt file $PerlFilesListFileTxt"
            Remove-Item -LiteralPath $PerlFilesListFileTxt
        }
    }
    else {
        Write-Host ''
        Write-Host -ForegroundColor Green "=> generate module list file '$ModuleListFileTxt'"
        $fileHeaders, $modulesHeaders, $moduleNames, $fileFooters | Out-File -LiteralPath $ModuleListFileTxt

        Write-Host ''
        Write-Host -ForegroundColor Green "=> generate module compile check (perl -c) file '$ModuleListFilePl'"
        $fileHeaders, $modulesHeaders, $modulesUse, $fileFooters | Out-File -LiteralPath $ModuleListFilePl

        Write-Host ''
        Write-Host -ForegroundColor Green "=> generate perl files list file '$PerlFilesListFileTxt'"
        $fileHeaders, $perlFilesHeaders, $perlFilePaths, $fileFooters | Out-File -LiteralPath $PerlFilesListFileTxt
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

    if ( $ori_Location -ne (Get-Location ).Path) {
        Set-Location $ori_Location
    }

    if ($transcript) {
        Stop-Transcript
    }

    $Global:ErrorActionPreference = $ori_ErrorActionPreference
}
