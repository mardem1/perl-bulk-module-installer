<#

.SYNOPSIS

List all installed modules via cpan -l

.PARAMETER StrawberryDir

Dir for strawberry dir to install the modules

.PARAMETER ModuleListFileTxt

Save list in text file

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

    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf -IsValid })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $ModuleListFileTxt
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

    $PathExtends = "$($StrawberryDir)\perl\site\bin;$($StrawberryDir)\perl\bin;$($StrawberryDir)\c\bin"
    if ( $env:Path -notlike "*$PathExtends*" ) {
        $Env:PATH = "$PathExtends;$Env:PATH"
    }

    $perlexe = $StrawberryDir + '\perl\bin\perl.exe'
    $perlInfo = & $perlexe -MConfig -e 'printf(qq{Perl executable : %s\nPerl version    : %s / $Config{archname}}, $^X, $^V)' | Out-String
    if ( 0 -ne $LASTEXITCODE) {
        Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
        throw 'perl not working'
    }

    # perl -e "printf(qq{%s}, $^X)" = $perlexe
    $perlVersion = & $perlexe -e 'print "$^V"' | Out-String # = eg. 5.40.2
    # perl -MConfig -e "print $Config{archname}" = MSWin32-x64-multi-thread

    $perlInfoList = $perlInfo.Split("`n") | Where-Object { ! [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | ForEach-Object { "$_" }
    $perlInfo | Write-Host -ForegroundColor Green
    Write-Host ''

    $ModuleListFileCsv = $ModuleListFileTxt.Replace('.txt', '.csv')
    $ModuleExportLog = $ModuleListFileTxt.Replace('.txt', '.log')

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished
    $winUser = $env:USERNAME
    $winHostName = $env:COMPUTERNAME
    $winOs = ( Get-CimInstance Win32_OperatingSystem ).Caption

    $fileHeaders = (
        '#',
        '# list perl module via cpan -l',
        '#',
        "# StrawberryDir   : $StrawberryDir",
        "# $($perlInfoList[0])",
        "# $($perlInfoList[1])",
        '#',
        "# Win-User        : $winUser",
        "# Win-Host        : $winHostName",
        "# Win-OS          : $winOs",
        '#'
    )

    # INFO: add custom header here ?

    $fileHeaders += (
        "# search done at  : '$now'",
        '#',
        '# modules found:',
        '#',
        '' # empty line before list
    )

    $fileFooters = (
        '', # empty line after list
        '#',
        '# list ended',
        '#'
    )

    Write-Host -ForegroundColor Green '=> search modules via cpan -l ...'
    # TODO: replace with Start-Process and created ARGV
    $generatedList = ( & cmd.exe '/c' 'cpan.bat' '-l' '2>&1' )
    Write-Host -ForegroundColor Green '=> ... module list generated'

    if ( 0 -ne $LASTEXITCODE) {
        Write-Host -ForegroundColor Red "FATAL ERROR: '$InstallCpanModules' with '$LASTEXITCODE' failed?"
    }

    Write-Host -ForegroundColor Green '=> check modules ...'
    [hashtable] $modules = @{}

    $generatedList | ForEach-Object {
        ( $_ | Out-String ).Trim( )
    } | Where-Object {
        ! [string]::IsNullOrWhiteSpace( $_ )
    } | ForEach-Object {
        $line = $_
        # Write-Host -ForegroundColor DarkGray "  => check $line"
        # line = modulename version
        if ( $line -notmatch '^([\S]+)[\s]+([\S]+)$' ) {
            Write-Host -ForegroundColor Red "    => ignore - unknown line format '$line'"
        }
        else {
            $m = $Matches[1]
            $m = "$m".Trim()

            $v = $Matches[2]
            $v = "$v".Trim()
            if ( '' -eq $v ) {
                $v = 'undef'; # as perl verison
            }

            # some moule wrong listed - end with : ? => ignore?
            # if ( $m -match '^\d' -or $m -like ':*' ) {
            # Upper-Case defined as first character for none core / standard modules
            if ( $line -notmatch '^(([A-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
                Write-Host -ForegroundColor Red "    => ignore - no match '$m'"
            }
            elseif ( ! $modules.ContainsKey($m) ) {
                # Write-Host  "    => unknown module save it - '$m'"
                $modules[$m] = $v
            }
            elseif ( 'undef' -eq $modules[$m] -and 'undef' -eq $v ) {
                # Write-Host  "    => both modules undefined number, do nothing - '$m'"
            }
            elseif ( 'undef' -ne $modules[$m] -and 'undef' -eq $v ) {
                # Write-Host  "    => already known number, keep it - '$m'"
            }
            elseif ( 'undef' -eq $modules[$m] -and 'undef' -ne $v ) {
                # Write-Host  "    => replace undefined with defined version number - '$m'"
                $modules[$m] = $v
            }
            else {
                # elseif ( 'undef' -ne $modules[$m] -and 'undef' -ne $v ) {
                $version_m = $null
                $version_v = $null

                try {
                    $version_m = [version]::new($modules[$m] -replace '^v', '') # if starting wiht v remove it
                }
                catch {
                    Write-Host -ForegroundColor Red "ERROR: can't parse Version $($modules[$m]) - $_"
                }

                try {
                    $version_v = [version]::new($v -replace '^v', '')
                }
                catch {
                    Write-Host -ForegroundColor Red "ERROR: can't parse Version $($v) - $_"
                }

                if ( $null -eq $version_m) {
                    # TODO: what to do ?
                }
                elseif ( $null -eq $version_v ) {
                    # TODO: what to do ?
                }
                elseif ( $version_m -ge $version_v) {
                    Write-Host "    => known module equal or newer '$m' $($modules[$m]) vs. $v"
                }
                else {
                    Write-Host "    => found module newer, replace '$m' $($modules[$m]) vs. $v"
                    $modules[$m] = $v
                }
            }
        }
    }

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewd finished search

    $moduleNames = $($modules.Keys | Select-Object -Unique | Sort-Object )

    # 0..10 | ForEach-Object { Write-Host '' }
    # Write-Host -ForegroundColor Green '=> found modules:'
    # $moduleNames | Write-Host
    # 0..10 | ForEach-Object { Write-Host '' }

    Write-Host ''
    Write-Host -ForegroundColor Green "=> found modules: $($moduleNames.Count)"

    if ( ! $moduleNames ) {
        if ( Test-Path -LiteralPath $ModuleExportLog ) {
            Write-Host "remove log file $ModuleExportLog"
            Remove-Item -LiteralPath $ModuleExportLog
        }

        if ( Test-Path -LiteralPath $ModuleListFileTxt ) {
            Write-Host "remove txt file $ModuleListFileTxt"
            Remove-Item -LiteralPath $ModuleListFileTxt
        }

        if ( Test-Path -LiteralPath $ModuleListFileCsv ) {
            Write-Host "remove csv file $ModuleListFileCsv"
            Remove-Item -LiteralPath $ModuleListFileCsv
        }
    }
    else {
        Write-Host ''
        Write-Host -ForegroundColor Green "write log file $ModuleExportLog"
        $generatedList | Out-File -LiteralPath $ModuleExportLog -Encoding default -Force -Confirm:$false -Width 999

        Write-Host ''
        Write-Host -ForegroundColor Green "write list file $ModuleListFileTxt"
        $fileHeaders, $moduleNames, $fileFooters | Out-File -LiteralPath $ModuleListFileTxt -Encoding default -Force -Confirm:$false -Width 999

        $moduleLines = $moduleNames | ForEach-Object {
            $m = $_
            $v = $modules[$m]
            "$m;$v"
        }

        Write-Host ''
        Write-Host -ForegroundColor Green "write csv file $ModuleListFileCsv"
        "# installed_modules_found;$perlVersion", $moduleLines | Out-File -LiteralPath $ModuleListFileCsv -Encoding default -Force -Confirm:$false -Width 999
    }

    Write-Host ''
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
