
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
        $perlVerison = $lines | Where-Object { $_ -like '# *' } | ForEach-Object {
            $t = $_.Split(';')

            if ([string]::IsNullOrWhiteSpace($t[0])) {
                throw 'perl title in CSV file not found'
            }

            if ([string]::IsNullOrWhiteSpace($t[1])) {
                throw 'perl verison in CSV file not found'
            }

            $t[1]
        }

        if ($null -eq $perlVerison) {
            throw 'perl info in CSV file not found'
        }

        Write-Host -ForegroundColor Green "perl info detected: $perlVerison"
        $shortNameVersionInfo[$shotName] = $perlVerison

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
    Write-Host -ForegroundColor Green 'init moudules not found or empty in verison'
    Write-Host ''

    $version_not_installed = 'not-installed'
    $version_not_defined = 'undef' # saved by export

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

    # Sorting:
    # 10 | not-installed | not-installed
    # 20 | any version   | not-installed (removed)
    # 30 | undef | undef
    # 40 | v* | undef
    # 50 | vU | vL (downgraded-lower?)
    # 60 | vE | vE (equal)
    # 70 | vL | vU (updated)
    # 80 | undef | v*
    # 90 | not-installed | any version (new)

    $moduleLines = $combinedModules.Keys | Sort-Object -Unique -CaseSensitive -Property {
        $m = $_
        $a = $combinedModules[$m]['ListA'] # old
        $b = $combinedModules[$m]['ListB'] # new

        if ( $version_not_installed -eq $a ) {
            if ( $version_not_installed -eq $b ) {
                # 10 | not-installed | not-installed
                10
            }
            else {
                # 90 | not-installed | any version (new)
                90
            }
        }
        else {
            if ( $version_not_installed -eq $b ) {
                # 20 | any version   | not-installed (removed)
                20
            }
            else {
                # changed installed versions ?
                if ( $version_not_defined -eq $a ) {
                    if ( $version_not_defined -eq $b ) {
                        # 30 | undef | undef
                        30
                    }
                    else {
                        # 80 | undef | v*
                        80
                    }
                }
                else {
                    if ( $version_not_defined -eq $b ) {
                        # 40 | v* | undef
                        40
                    }
                    else {
                        # version number diff
                        $version_a = $null
                        $version_b = $null

                        try {
                            # if starting wiht v remove it & if ending wiht _0123 remove -> v5.4.3_21 -> 5.4.3
                            $t = [string] (($a -replace '^v', '') -replace '_\d+$', '')
                            $dotCount = ([regex]::Matches($t, '\.' )).Count
                            if (  $dotCount -gt 3 ) {
                                # to long version more than 4 sections
                                # keep new() exception
                            }
                            elseif ($dotCount -lt 1 ) {
                                # only number no .
                                $t = "$($t).0" # [version]::new()  needs 2a
                            }

                            $version_a = [version]::new($t)
                        }
                        catch {
                            Write-Host -ForegroundColor Red "ERROR: can't parse Version '$m' -> '$a' - $_"
                        }

                        try {
                            # if starting wiht v remove it & if ending wiht _0123 remove -> v5.4.3_21 -> 5.4.3
                            $t = [string] (($b -replace '^v', '') -replace '_\d+$', '')
                            $dotCount = ([regex]::Matches($t, '\.' )).Count
                            if (  $dotCount -gt 3 ) {
                                # to long version more than 4 sections
                                # keep new() exception
                            }
                            elseif ($dotCount -lt 1 ) {
                                # only number no .
                                $t = "$($t).0" # [version]::new()  needs 2a
                            }

                            $version_b = [version]::new($t)
                        }
                        catch {
                            Write-Host -ForegroundColor Red "ERROR: can't parse Version '$m' -> '$b' - $_"
                        }


                        if ( $null -eq $version_a) {
                            if ( $null -eq $version_b) {
                                # TODO: what to do ?

                                # 60 | vE | vE (equal) - Both unknowd = Equal :)
                                60
                            }
                            else {
                                # TODO: what to do ?
                                # 70 | vL | vU (updated) - new known => Newer :)
                                30
                            }
                        }
                        else {
                            if ( $null -eq $version_b) {
                                # TODO: what to do ?
                                # 50 | vU | vL (downgraded-lower?)    - new unknowd => Lower :)
                                50
                            }
                            else {
                                if ( $version_a -lt $version_b) {
                                    # 70 | vL | vU (updated)
                                    30
                                }
                                elseif ( $version_a -gt $version_b) {
                                    # 50 | vU | vL (downgraded-lower?)
                                    50
                                }
                                else {
                                    # 60 | vE | vE (equal)
                                    60
                                }
                            }
                        }
                    }
                }
            }
        }
    }, {
        $_
    } | ForEach-Object {
        $m = $_
        $a = $combinedModules[$m]['ListA']
        $b = $combinedModules[$m]['ListB']
        "$m;$a;$b"
    }

    Write-Host ''
    Write-Host -ForegroundColor Green "write csv file $CompareResultList"
    "Module;ListA-$($shortNameVersionInfo['ListA']);ListB-$($shortNameVersionInfo['ListB'])" , $moduleLines | Out-File -LiteralPath $CompareResultList -Encoding default -Force -Confirm:$false -Width 999

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
