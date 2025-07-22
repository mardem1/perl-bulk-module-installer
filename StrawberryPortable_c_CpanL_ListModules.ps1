
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

    $PathExtends = "$($StrawberryDir)\perl\site\bin;$($StrawberryDir)\perl\bin;$($StrawberryDir)\c\bin"
    if ( $env:Path -notlike "*$PathExtends*" ) {
        $Env:PATH = "$PathExtends;$Env:PATH"
    }

    $perlexe = $StrawberryDir + '\perl\bin\perl.exe'
    $perlVersionInfoStr = & $perlexe -MConfig -e 'printf(qq{Perl executable : %s\nPerl version    : %s / $Config{archname}\n\n}, $^X, $^V)' | Out-String
    $perlVersionInfoStr | Write-Host -ForegroundColor Green
    Write-Host ''

    if ( 0 -ne $LASTEXITCODE) {
        Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
        throw 'perl not working'
    }

    $perlVersion = & $perlexe -e 'print "$^V"' | Out-String # = eg. 5.40.2

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished
    $winUser = $env:USERNAME
    $winHostName = $env:COMPUTERNAME
    $winOs = ( Get-CimInstance Win32_OperatingSystem ).Caption
    $psVersion = $PSVersionTable.PSVersion.ToString()
    $wcs = Get-CimInstance -ClassName Win32_ComputerSystem
    $hwModel = "$($wcs.Model) $($wcs.Manufacturer)"
    $hwRam = "$([System.Math]::Round( [double] $wcs.TotalPhysicalMemory / 1GB , 2)) GByte" # ( Get-CimInstance Win32_OperatingSystem ).TotalVisibleMemorySize
    $wp = Get-CimInstance -ClassName Win32_Processor | Sort-Object -Property NumberOfLogicalProcessors -Descending | Select-Object -First 1 # TODO: dual socket system support ?
    $hwCpu = "$($($wp.Name).Trim()) ($($wp.NumberOfCores)C / $($wp.NumberOfLogicalProcessors)T)" # ( Get-CimInstance Win32_OperatingSystem ).TotalVisibleMemorySize
    $isVm = if ( $wcs.HypervisorPresent ) {
        'Hypervisor present'
    }
    else {
        'no hypervisor found'
    }

    $fileHeaders = (
        '#',
        '# list perl module via cpan -l',
        '#',
        "# StrawberryDir   : $StrawberryDir"
    )

    $perlVersionInfoStr.Split("`n") | Where-Object {
        ! [string]::IsNullOrWhiteSpace( $_ )
    } | ForEach-Object {
        $fileHeaders += (
            "# $("$_".Trim())"
        )
    }

    $fileHeaders += (
        '#',
        "# Device-Model    : $hwModel",
        "# CPU             : $hwCpu",
        "# RAM             : $hwRam",
        "# VM Check        : $isVm",
        "# Win-OS          : $winOs",
        "# Win-Host        : $winHostName",
        "# Win-User        : $winUser",
        "# PS-Version      : $psVersion"
    )

    # ADD CUSTOM HEADERS HERE

    $fileHeaders += (
        '#'
    )

    Write-Host ''
    Write-Host '# FILE-HEADERS-START'
    $fileHeaders | ForEach-Object {
        Write-Host $_
    }
    Write-Host '# FILE-HEADERS-END'
    Write-Host ''

    Write-Host -ForegroundColor Green '=> search modules via cpan -l ...'
    # TODO: replace with Start-Process and created ARGV
    $Env:PERL5LIB = '' # reset
    $generatedList = ( & 'cmd.exe' '/c' 'cpan.bat' '-l' '2>nul' ) # ignore error lines, wrong version format or version var not set.
    Write-Host -ForegroundColor Green '=> ... module list generated'

    if ( 0 -ne $LASTEXITCODE) {
        Write-Host -ForegroundColor Red "FATAL ERROR: '$InstallCpanModules' with '$LASTEXITCODE' failed?"
    }

    Write-Host -ForegroundColor Green '=> check modules ...'
    [hashtable] $modules = @{}

    $version_not_installed = 'not-installed'
    $version_not_defined = 'undef' # saved by export

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
                $v = $version_not_defined # as perl version
            }

            # some modules wrong listed - end with : ? => ignore?
            # Upper-Case defined as first character for none core / standard modules
            # but we need all modules for dependency check here so also lower case start allowed
            if ( $line -notmatch '^(([a-zA-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
                Write-Host -ForegroundColor Red "    => ignore - no match '$m'"
            }
            elseif ( ! $modules.ContainsKey($m) ) {
                # Write-Host  "    => unknown module save it - '$m'"
                $modules[$m] = $v
            }
            elseif ( $version_not_defined -eq $modules[$m] -and $version_not_defined -eq $v ) {
                # Write-Host  "    => both modules undefined number, do nothing - '$m'"
            }
            elseif ( $version_not_defined -ne $modules[$m] -and $version_not_defined -eq $v ) {
                # Write-Host  "    => already known number, keep it - '$m'"
            }
            elseif ( $version_not_defined -eq $modules[$m] -and $version_not_defined -ne $v ) {
                # Write-Host  "    => replace undefined with defined version number - '$m'"
                $modules[$m] = $v
            }
            else {
                # elseif ( $version_not_defined -ne $modules[$m] -and $version_not_defined -ne $v ) {

                # Perl Module Version can be double value or version number value
                # check https://metacpan.org/release/LEONT/version-0.9933/view/lib/version.pm

                $aIsDouble = "$($modules[$m])" -match '^\d+([.]\d+)?$'
                $bIsDouble = "$v" -match '^\d+([.]\d+)?$'

                if ( "$($modules[$m])" -eq "$v" ) {
                    # fast check
                    Write-Host "    => known module equal (1) '$m' $($modules[$m]) vs. $v"
                }
                elseif ( $aIsDouble -and $bIsDouble ) {
                    # both double value
                    if ( $modules[$m] -eq $v ) {
                        Write-Host "    => known module equal (2) '$m' $($modules[$m]) vs. $v"
                        $compare_value_60_same
                    }
                    elseif ( $modules[$m] -gt $v) {
                        Write-Host "    => known module newer (2) '$m' $($modules[$m]) vs. $v"
                    }
                    else {
                        Write-Host "    => found module newer, replace (2) '$m' $($modules[$m]) vs. $v"
                        $modules[$m] = $v
                    }
                }
                else {
                    # One is Version-Number not only Double

                    # version number diff
                    $version_m = $null
                    $version_v = $null

                    try {
                        # if starting wiht v remove it & if ending wiht _0123 remove -> v5.4.3_21 -> 5.4.3
                        $t = [string] (($modules[$m] -replace '^v', '') -replace '_.+$', '')
                        $dotCount = ([regex]::Matches($t, '\.' )).Count
                        if (  $dotCount -gt 3 ) {
                            # to long version more than 4 sections
                            # keep new() exception
                        }

                        # [version]::new(1,1) -eq  [version]::new(1,1,0) # false => lower -lt ? -> not set values are -1
                        $sections = @(0, 0, 0, 0)
                        $i = 0
                        $t.Split('.') | ForEach-Object {
                            $sections[$i] = $_
                            $i++
                        }
                        $version_m = [version]::new($sections[0] , $sections[1], $sections[2], $sections[3])
                    }
                    catch {
                        Write-Host -ForegroundColor Red "ERROR: can't parse Version '$m' -> '$($modules[$m])' - $_"
                    }

                    try {
                        # if starting wiht v remove it & if ending wiht _0123 remove -> v5.4.3_21 -> 5.4.3
                        $t = [string] (($v -replace '^v', '') -replace '_.+$', '')
                        $dotCount = ([regex]::Matches($t, '\.' )).Count
                        if (  $dotCount -gt 3 ) {
                            # to long version more than 4 sections
                            throw "invalid version '$t'"
                        }

                        # [version]::new(1,1) -eq  [version]::new(1,1,0) # false => lower -lt ? -> not set values are -1
                        $sections = @(0, 0, 0, 0)
                        $i = 0
                        $t.Split('.') | ForEach-Object {
                            $sections[$i] = $_
                            $i++
                        }
                        $version_v = [version]::new($sections[0] , $sections[1], $sections[2], $sections[3])
                    }
                    catch {
                        Write-Host -ForegroundColor Red "ERROR: can't parse Version '$m' -> '$v' - $_"
                    }

                    if ( $null -eq $version_m) {
                        # TODO: what to do ?
                    }
                    elseif ( $null -eq $version_v ) {
                        # TODO: what to do ?
                    }
                    elseif ( $version_m -eq $version_v) {
                        Write-Host "    => known module equal (3) '$m' $($modules[$m]) vs. $v"
                    }
                    elseif ( $version_m -gt $version_v) {
                        Write-Host "    => known module newer (3) '$m' $($modules[$m]) vs. $v"
                    }
                    else {
                        Write-Host "    => found module newer, replace (3) '$m' $($modules[$m]) vs. $v"
                        $modules[$m] = $v
                    }
                }
            }
        }
    }

    $allModuleNames = $($modules.Keys | Select-Object | Sort-Object )

    # for module list txt files reduce to Upper-Case start - see above
    $ucModuleNames = $($modules.Keys | Where-Object { $_ -cmatch '^[A-Z]' } | Select-Object | Sort-Object )

    # 0..10 | ForEach-Object { Write-Host '' }
    # Write-Host -ForegroundColor Green '=> found modules:'
    # allModuleNames | Write-Host
    # 0..10 | ForEach-Object { Write-Host '' }

    Write-Host ''
    Write-Host -ForegroundColor Green "=> found modules: $($modules.Count)"

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished
    $fileHeaders += (
        '#',
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

    $ModuleListFileCsv = $ModuleListFileTxt.Replace('.txt', '.csv')
    $ModuleExportLog = $ModuleListFileTxt.Replace('.txt', '.log')

    if ( ! $allModuleNames ) {
        if (Test-Path -LiteralPath $ModuleExportLog) {
            Write-Host "remove log file $ModuleExportLog"
            Remove-Item -LiteralPath $ModuleExportLog
        }
        if ( Test-Path -LiteralPath $ModuleListFileCsv ) {
            Write-Host "remove csv file $ModuleListFileCsv"
            Remove-Item -LiteralPath $ModuleListFileCsv
        }
    }
    else {
        Write-Host ''
        Write-Host -ForegroundColor Green "write log file $ModuleExportLog"
        $generatedList | Out-File -LiteralPath $ModuleExportLog -Encoding utf8 -Force -Confirm:$false -Width 999

        $moduleLines = $allModuleNames | ForEach-Object {
            $m = $_
            $v = $modules[$m]
            "$m;$v"
        }

        Write-Host ''
        Write-Host -ForegroundColor Green "write csv file $ModuleListFileCsv"
        "# installed_modules_found;$perlVersion", $moduleLines | Out-File -LiteralPath $ModuleListFileCsv -Encoding utf8 -Force -Confirm:$false -Width 999
    }

    if ( ! $ucModuleNames ) {
        if ( Test-Path -LiteralPath $ModuleListFileTxt ) {
            Write-Host "remove txt file $ModuleListFileTxt"
            Remove-Item -LiteralPath $ModuleListFileTxt
        }
    }
    else {

        Write-Host ''
        Write-Host -ForegroundColor Green "write list file $ModuleListFileTxt"
        $fileHeaders, $ucModuleNames, $fileFooters | Out-File -LiteralPath $ModuleListFileTxt -Encoding utf8 -Force -Confirm:$false -Width 999
    }

    Write-Host ''
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
