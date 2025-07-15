
<#

.SYNOPSIS

Compare two module list files (CSV) an generate a result CSV

.PARAMETER ListA

First list

.PARAMETER ListB

Second list

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
    [string] $ListA,

    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.csv' })]
    [string] $ListB,

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

    $allLists = @()

    $lists = @{
        "$ListA" = 'ListA'
        "$ListB" = 'ListB'
    }

    $ListA, $ListB | ForEach-Object {
        $file = $_

        Write-Host ''
        Write-Host -ForegroundColor Green "analyze '$file' ..."

        $lines = Get-Content -LiteralPath $file
        $list = $lines | Where-Object { $_ -like '# *' } | ForEach-Object {
            $t = $_.Split(';')

            if ([string]::IsNullOrWhiteSpace($t[0])) {
                throw "perl title in CSV file not found - $file"
            }

            if ([string]::IsNullOrWhiteSpace($t[1])) {
                throw "perl verison in CSV file not found - $file"
            }

            $t[1]
        }

        if ($null -eq $list) {
            throw "perl info in CSV file not found - $file"
        }

        $list = "$($lists[$file])-$list "

        $allLists += $list

        # https://github.com/PowerShell/PowerShell/blob/744a53a2038056467b6ddeb2045336d79480c4c0/src/Microsoft.PowerShell.Commands.Utility/commands/utility/CsvCommands.cs#L1362
        # ConvertFrom-Csv - ignores lines which start wiht #
        $modules = $lines | ConvertFrom-Csv -Delimiter ';' -Header 'Module', 'Version'

        $modules | ForEach-Object {
            $module = $_
            if ( ! $combinedModules.ContainsKey($module.Module) ) {
                $combinedModules[$module.Module] = @{}
            }

            $combinedModules[$module.Module][$list] = $module.Version
        }
    }

    Write-Host ''
    Write-Host -ForegroundColor Green 'init moudule not found in verison'
    Write-Host ''

    $keys = $combinedModules.Keys | Sort-Object -Unique
    $allLists | ForEach-Object {
        $list = $_

        $keys | ForEach-Object {
            $module = $_
            if ( ! $combinedModules.ContainsKey($module) ) {
                # ignore already deleted
            }
            elseif ( $combinedModules[$module].Count -eq 2) {
                $moduleVersions = $combinedModules[$module].Values | Sort-Object -Unique
                if ( @($moduleVersions).Count -eq 1 ) {
                    Write-Host -ForegroundColor Green "remove $module - version equal"
                    $combinedModules.Remove($module)
                }
            }
            elseif ( ! $combinedModules[$module].ContainsKey($list)) {
                $combinedModules[$module][$list] = 'not-installed'
            }
        }
    }

    $moduleLines = $combinedModules.Keys | Sort-Object -Unique | ForEach-Object {
        $m = $_
        $a = $combinedModules[$m]["$($allLists[0])"]
        $b = $combinedModules[$m]["$($allLists[1])"]
        "$m;$a;$b"
    }

    Write-Host ''
    Write-Host -ForegroundColor Green "write csv file $CompareResultList"
    "Module;$($allLists[0]);$($allLists[1])" , $moduleLines | Out-File -LiteralPath $CompareResultList -Encoding default -Force -Confirm:$false -Width 999

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
