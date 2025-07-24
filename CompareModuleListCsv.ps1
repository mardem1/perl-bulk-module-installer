
<#

.SYNOPSIS

Compare two module list files (CSV) an generate a result CSV

.PARAMETER ListA

First list (old list)

.PARAMETER ListB

Second list (new list)

.PARAMETER CompareResultList

csv file with all direrences

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
    [ValidateScript({ $_ -like '*.csv' })]
    [string] $ListA, # old

    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.csv' })]
    [string] $ListB, # new

    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf -IsValid })]
    [ValidateScript({ $_ -like '*.csv' })]
    [string] $CompareResultList
)

# Sorting:
$compare_value_10_not_installed = 10 # | not-installed | not-installed
$compare_value_20_removed = 20 # | any version   | not-installed (removed)
$compare_value_30_undef = 30 # | undef | undef
$compare_value_40_v_undef = 40 # | v* | undef
$compare_value_50_downgrade = 50 # | vU | vL (downgraded-lower?)
$compare_value_60_same = 60 # | vE | vE (equal)
$compare_value_70_update = 70 # | vL | vU (updated)
$compare_value_80_undef_v = 80 # | undef | v*
$compare_value_90_new = 90 # | not-installed | any version (new)
$compare_value_99_unknown_format = 99 # | unknown format for compare

$compare_text = @{
    "$compare_value_10_not_installed"  = 'not installed'
    "$compare_value_20_removed"        = 'removed'
    "$compare_value_30_undef"          = 'undefined'
    "$compare_value_40_v_undef"        = 'defined to undefined'
    "$compare_value_50_downgrade"      = 'downgraded'
    "$compare_value_60_same"           = 'equal'
    "$compare_value_70_update"         = 'updated'
    "$compare_value_80_undef_v"        = 'undefined to defined'
    "$compare_value_90_new"            = 'added'
    "$compare_value_99_unknown_format" = 'unknown version format'
}

$version_not_installed = 'not-installed'
$version_not_defined = 'undef' # saved by export

function Compare-PerlModuleVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ ! [string]::IsNullOrWhiteSpace(( $_ )) })]
        [string] $ModuleName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({ ! [string]::IsNullOrWhiteSpace(( $_ )) })]
        [string] $VersionA,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({ ! [string]::IsNullOrWhiteSpace(( $_ )) })]
        [string] $VersionB
    )

    $m = $ModuleName
    $a = $VersionA
    $b = $VersionB

    $cmpv = if ( $version_not_installed -eq $a ) {
        if ( $version_not_installed -eq $b ) {
            $compare_value_10_not_installed
        }
        else {
            $compare_value_90_new
        }
    }
    else {
        if ( $version_not_installed -eq $b ) {
            $compare_value_20_removed
        }
        else {
            # changed installed versions ?
            if ( $version_not_defined -eq $a ) {
                if ( $version_not_defined -eq $b ) {
                    $compare_value_30_undef
                }
                else {
                    $compare_value_80_undef_v
                }
            }
            else {
                # 1
                # v1
                # 1.0
                # v1.0
                # 1_alpha
                # v1_alpha
                # 0.904.0
                # v0.904.0
                $aIsVersion = $a -match '^[v]?\d+(\.\d+){0,4}(_.+)?$'
                $bIsVersion = $b -match '^[v]?\d+(\.\d+){0,4}(_.+)?$'

                if ( !$aIsVersion -or !$bIsVersion ) {
                    # https://metacpan.org/release/DCONWAY/Contextual-Return-0.004014/source/lib/Contextual/Return/Failure.pm
                    # our $VERSION = 0.000_003;
                    # cpan.bat -l >c:\temp\out.log 2>&1
                    # Contextual::Return	0.004014
                    # Contextual::Return::Failure	3e-006 # ERROR - exported by cpan -l !
                    $compare_value_99_unknown_format
                }
                else {
                    # Perl Module Version can be double value or version number value
                    # check https://metacpan.org/release/LEONT/version-0.9933/view/lib/version.pm

                    $aIsDouble = "$a" -match '^\d+([.]\d+)?$'
                    $bIsDouble = "$b" -match '^\d+([.]\d+)?$'

                    if ($version_not_defined -eq $b) {
                        $compare_value_40_v_undef
                    }
                    elseif ( "$a" -eq "$b" ) {
                        # fast check
                        $compare_value_60_same
                    }
                    elseif ( $aIsDouble -and $bIsDouble ) {
                        # both double value
                        if ($a -eq $b) {
                            $compare_value_60_same
                        }
                        elseif ($b -gt $a) {
                            $compare_value_70_update
                        }
                        else {
                            $compare_value_50_downgrade
                        }
                    }
                    else {
                        # One is Version-Number not only Double

                        # version number diff
                        $version_a = $null
                        $version_b = $null

                        try {
                            # if starting wiht v remove it & if ending wiht _0123 remove -> v5.4.3_21 -> 5.4.3
                            $t = [string](($a -replace '^v', '') -replace '_.+$', '')
                            $dotCount = ([regex]::Matches($t, '\.')).Count
                            if ($dotCount -gt 3) {
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
                            $version_a = [version]::new($sections[0], $sections[1], $sections[2], $sections[3])
                        }
                        catch {
                            Write-Host -ForegroundColor Red "ERROR: can't parse Version '$m' -> '$a' - $_"
                        }

                        try {
                            # if starting wiht v remove it & if ending wiht _0123 remove -> v5.4.3_21 -> 5.4.3
                            $t = [string](($b -replace '^v', '') -replace '_.+$', '')
                            $dotCount = ([regex]::Matches($t, '\.')).Count
                            if ($dotCount -gt 3) {
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
                            $version_b = [version]::new($sections[0], $sections[1], $sections[2], $sections[3])
                        }
                        catch {
                            Write-Host -ForegroundColor Red "ERROR: can't parse Version '$m' -> '$b' - $_"
                        }

                        if ($null -eq $version_a) {
                            if ($null -eq $version_b) {
                                # TODO: what to do ? - Both unknown = Equal :)
                                $compare_value_60_same
                            }
                            else {
                                # TODO: what to do ? - new known vs. old unknown => Newer :)
                                $compare_value_70_update
                            }
                        }
                        else {
                            if ($null -eq $version_b) {
                                # TODO: what to do ? - new unknown vs. old known => Lower :)
                                $compare_value_50_downgrade
                            }
                            else {
                                if ($version_a -lt $version_b) {
                                    $compare_value_70_update
                                }
                                elseif ( $version_a -gt $version_b) {
                                    $compare_value_50_downgrade
                                }
                                else {
                                    $compare_value_60_same # difference after _ possible - not checked jet TODO: implement ?
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    # Write-Host -ForegroundColor Darkgray "Version-Check - '$m' -> '$a' vs. '$b' -> $($compare_text["$cmpv"]) ($cmpv)"
    return $cmpv
}

function Invoke-TestComparePerlModuleVersion {
    $tests = @(
        @{
            'A'        = $version_not_installed
            'B'        = $version_not_installed
            'expected' = $compare_value_10_not_installed
        },
        @{
            'A'        = $version_not_defined
            'B'        = $version_not_defined
            'expected' = $compare_value_30_undef
        },
        @{
            'A'        = $version_not_installed
            'B'        = $version_not_defined
            'expected' = $compare_value_90_new
        },
        @{
            'A'        = $version_not_installed
            'B'        = '1.1'
            'expected' = $compare_value_90_new
        },
        @{
            'A'        = $version_not_installed
            'B'        = '1.1.1'
            'expected' = $compare_value_90_new
        },
        @{
            'A'        = $version_not_installed
            'B'        = 'v1.1.1'
            'expected' = $compare_value_90_new
        },
        @{
            'A'        = $version_not_defined
            'B'        = $version_not_installed
            'expected' = $compare_value_20_removed
        },
        @{
            'A'        = '1.1'
            'B'        = $version_not_installed
            'expected' = $compare_value_20_removed
        },
        @{
            'A'        = '1.1.1'
            'B'        = $version_not_installed
            'expected' = $compare_value_20_removed
        },
        @{
            'A'        = 'v1.1.1'
            'B'        = $version_not_installed
            'expected' = $compare_value_20_removed
        },
        @{
            'A'        = '1.1'
            'B'        = $version_not_defined
            'expected' = $compare_value_40_v_undef
        },
        @{
            'A'        = '1.1.1'
            'B'        = $version_not_defined
            'expected' = $compare_value_40_v_undef
        },
        @{
            'A'        = 'v1.1.1'
            'B'        = $version_not_defined
            'expected' = $compare_value_40_v_undef
        }
        @{
            'A'        = $version_not_defined
            'B'        = '1.1'
            'expected' = $compare_value_80_undef_v
        },
        @{
            'A'        = $version_not_defined
            'B'        = '1.1.1'
            'expected' = $compare_value_80_undef_v
        },
        @{
            'A'        = $version_not_defined
            'B'        = 'v1.1.1'
            'expected' = $compare_value_80_undef_v
        }
        @{
            'A'        = '1'
            'B'        = '1'
            'expected' = $compare_value_60_same
        }
        @{
            'A'        = '1.1'
            'B'        = '1.1'
            'expected' = $compare_value_60_same
        }
        @{
            'A'        = 'v1.1.1'
            'B'        = 'v1.1.1'
            'expected' = $compare_value_60_same
        }
        @{
            'A'        = '1.1'
            'B'        = '1.1.0'
            'expected' = $compare_value_60_same
        }
        @{
            'A'        = '1.1'
            'B'        = '1.1_x'
            'expected' = $compare_value_60_same
        },
        @{
            'A'        = '2'
            'B'        = '1'
            'expected' = $compare_value_50_downgrade
        },
        @{
            'A'        = '1.3'
            'B'        = '1.2'
            'expected' = $compare_value_50_downgrade
        },
        @{
            'A'        = '1.3.1'
            'B'        = 'v1.3.0'
            'expected' = $compare_value_50_downgrade
        },

        @{
            'A'        = '1'
            'B'        = '2'
            'expected' = $compare_value_70_update
        },
        @{
            'A'        = '1.2'
            'B'        = '1.3'
            'expected' = $compare_value_70_update
        },
        @{
            'A'        = '1.50'
            'B'        = '1.60'
            'expected' = $compare_value_70_update
        },
        @{
            'A'        = '1.801'
            'B'        = '1.823'
            'expected' = $compare_value_70_update
        },
        @{
            'A'        = 'v1.3.0'
            'B'        = '1.3.1'
            'expected' = $compare_value_70_update
        }
    )

    $tests | ForEach-Object {
        $cmp = Compare-PerlModuleVersion -ModuleName "Compre-$($_['expected'])" -VersionA $_['A'] -VersionB $_['B']
        if ($_['expected'] -ne $cmp) {
            Write-Host -ForegroundColor Red 'mismatch'
        }
    }

    exit
}

# Invoke-TestComparePerlModuleVersion

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

    [hashtable]$combinedModules = @{}

    $fileToShortName = @{
        "$ListA" = 'ListA'
        "$ListB" = 'ListB'
    }

    $shortNameToFile = @{
        'ListA' = "$ListA"
        'ListB' = "$ListB"
    }

    $shortNameVersionInfo = @{
        'ListA' = ''
        'ListB' = ''
    }

    $ListA, $ListB | ForEach-Object {
        $file = $_
        $shotName = $fileToShortName[$file]

        Write-Host ''
        Write-Host -ForegroundColor Green "load $shotName '$file'"
        $lines = Get-Content -LiteralPath $file -ErrorAction Stop

        Write-Host -ForegroundColor Green 'analyze perl version'
        $perlVersion = $lines | Where-Object { $_ -like '# *' } | ForEach-Object {
            $t = $_.Split(';')

            if ([string]::IsNullOrWhiteSpace($t[0])) {
                throw 'perl title in CSV file not found'
            }

            if ([string]::IsNullOrWhiteSpace($t[1])) {
                throw 'perl version in CSV file not found'
            }

            $t[1]
        }

        if ($null -eq $perlVersion) {
            throw 'perl info in CSV file not found'
        }

        Write-Host -ForegroundColor Green "perl info detected: $perlVersion"
        $shortNameVersionInfo[$shotName] = $perlVersion

        Write-Host -ForegroundColor Green 'analyze module infos'
        # https://github.com/PowerShell/PowerShell/blob/744a53a2038056467b6ddeb2045336d79480c4c0/src/Microsoft.PowerShell.Commands.Utility/commands/utility/CsvCommands.cs#L1362
        # ConvertFrom-Csv - ignores lines which start wiht #
        $modules = $lines | ConvertFrom-Csv -Delimiter ';' -Header 'Module', 'Version'

        $modules | ForEach-Object {
            $module = $_
            if ( ! $combinedModules.ContainsKey($module.Module) ) {
                $combinedModules[$module.Module] = @{}
            }

            $combinedModules[$module.Module][$shotName] = $module.Version
        }

        Write-Host -ForegroundColor Green "$shotName '$file' completed"
    }

    Write-Host ''
    Write-Host -ForegroundColor Green 'init moudules not found or empty in version'
    Write-Host ''

    $moduleNames = $combinedModules.Keys
    $moduleNames | ForEach-Object {
        $module = $_

        $shortNameToFile.Keys | ForEach-Object {
            $shotName = $_
            if ( ! $combinedModules[$module].ContainsKey($shotName)) {
                $combinedModules[$module][$shotName] = $version_not_installed
            }
            elseif ( '' -eq $combinedModules[$module][$shotName] ) {
                # should not be needed but be safe
                $combinedModules[$module][$shotName] = $version_not_defined
            }
        }
    }

    Write-Host ''
    Write-Host -ForegroundColor Green 'sort an prepare csv'
    Write-Host ''

    $combinedModules.Keys | ForEach-Object {
        $m = $_
        $a = $combinedModules[$m]['ListA'] # old
        $b = $combinedModules[$m]['ListB'] # new
        $combinedModules[$m]['CompareValue'] = 0

        $combinedModules[$m]['CompareValue'] = Compare-PerlModuleVersion -ModuleName $m -VersionA $a -VersionB $b
    }

    $moduleLines = $combinedModules.Keys | Sort-Object -Property {
        $combinedModules[$_]['CompareValue']
    }, { $_
    } | ForEach-Object {
        $m = $_
        $a = $combinedModules[$m]['ListA']
        $b = $combinedModules[$m]['ListB']
        $c = $combinedModules[$m]['CompareValue']
        $txt = $compare_text["$($combinedModules[$m]['CompareValue'])"]
        "$m;$a;$b;$txt;$c"
    }

    Write-Host ''
    Write-Host -ForegroundColor Green "write csv file $CompareResultList"
    "Module;ListA-$($shortNameVersionInfo['ListA']);ListB-$($shortNameVersionInfo['ListB']);CompareText;CompareValue" , $moduleLines | Out-File -LiteralPath $CompareResultList -Encoding utf8 -Force -Confirm:$false -Width 999

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
