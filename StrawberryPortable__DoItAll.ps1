<#

.SYNOPSIS

extract strawberry portable, install module and package again as 7z

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
param ()

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
    $ScriptDir = $ScriptItem.Directory.FullName
    $PbmiDir = "$ScriptDir"

    $LogDir = "$PbmiDir\log"
    Start-Transcript -LiteralPath "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($ScriptItem.BaseName).log"
    $transcript = $true

    Write-Host ''
    Write-Host -ForegroundColor Green "Script '$ScriptPath' started at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $ScriptStartTime )"
    Write-Host ''

    $hasAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Write-Host ''
    if ( ! $hasAdmin ) {
        Write-Host -ForegroundColor Red 'ERROR: admin required for defender config!'
        exit 1
    }

    if ( ! ( Test-Path -LiteralPath "$PbmiDir\InstallCpanModules.pl" -PathType Leaf) ) {
        Write-Host -ForegroundColor Red 'ERROR: perl-bulk-module-installer (InstallCpanModules) not found!'
        exit 1
    }

    # strawberry-perl-5.14.4.1-64bit-portable
    # strawberry-perl-5.16.3.1-64bit-portable
    # strawberry-perl-5.18.4.1-64bit-portable
    # strawberry-perl-5.20.3.3-64bit-portable
    # strawberry-perl-5.22.3.1-64bit-portable

    # strawberry-perl-5.24.4.1-64bit-portable
    # strawberry-perl-5.26.3.1-64bit-portable
    # strawberry-perl-5.28.2.1-64bit-portable
    # strawberry-perl-5.30.3.1-64bit-portable
    # strawberry-perl-5.32.1.1-64bit-portable

    # strawberry-perl-5.34.3.1-64bit-portable
    # strawberry-perl-5.36.3.1-64bit-portable
    # strawberry-perl-5.38.4.1-64bit-portable
    # strawberry-perl-5.40.2.1-64bit-portable

    $portableBaseName = 'strawberry-perl-5.24.4.1-64bit-portable'
    $perlBuildDir = 'C:\perl-build'

    $StrawberryZip = "$perlBuildDir\$portableBaseName.zip"
    $StrawberryDir = "$perlBuildDir\$portableBaseName"

    if ( !( Test-Path -LiteralPath $StrawberryZip ) ) {
        throw "zip source $StrawberryZip not found"
    }

    if ( Test-Path -LiteralPath $StrawberryDir ) {
        throw "extraction target $StrawberryDir already exists"
    }

    $moduleListDirPath = "$PbmiDir\test-module-lists"
    if ( !( Test-Path -LiteralPath $moduleListDirPath -PathType Container ) ) {
        throw "list dir $moduleListDirPath not found"
    }

    $dontTryListFilePath = "$moduleListDirPath\_dont_try_modules.txt"
    if ( !( Test-Path -LiteralPath $dontTryListFilePath -PathType Leaf ) ) {
        throw "dont-try list file $dontTryListFilePath not found"
    }

    & "$PbmiDir\StrawberryPortable_a_Extract.ps1" -StrawberryZip $StrawberryZip -Destination $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_b_AddDefenderExclude.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_before.txt" | Write-Host

    # it's not recommended to update module if not needed

    # install all Updates before ?
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -OnlyAllUpdates -DontTryModuleListFile "$dontTryListFilePath"

    # install all Updates in same install run ?
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -AllUpdates -InstallModuleListFile "$moduleListDirPath\CoreCarpModuleExample.txt" -DontTryModuleListFile "$dontTryListFilePath"

    # install modules
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$moduleListDirPath\SingleModuleExample.txt" -DontTryModuleListFile "$dontTryListFilePath" | Write-Host

    # direct loop ?
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$moduleListDirPath\SingleModuleExample.txt", "$moduleListDirPath\SmallModuleExample.txt" -DontTryModuleListFile "$dontTryListFilePath" | Write-Host

    $ModuleListFiles = Get-ChildItem -LiteralPath "$moduleListDirPath\" -File | Where-Object {
        $_.Name -like '*.txt'
    } | Where-Object {
        $_.FullName -ne $dontTryListFilePath
    } | ForEach-Object {
        $item = $_
        $name = $item.Name
        $fullName = $item.FullName
        $m = Get-Content -LiteralPath $fullName | Where-Object { ! [string]::IsNullOrWhiteSpace($_) -and $_ -notlike '#*' }
        $moduleCount = @($m).Count

        [pscustomobject] @{
            Name        = $name
            FullName    = $fullName
            ModuleCount = $moduleCount
        } | Write-Output
    }

    $ModuleListCount = @($ModuleListFiles).Count
    $i = 0

    $ModuleListFiles | Sort-Object -Property ModuleCount, FullName | ForEach-Object {
        $i++

        $item = $_
        $name = $item.Name
        $fullName = $item.FullName

        Write-Host ''
        Write-Host -ForegroundColor Green "module installation ($i/$ModuleListCount) with list '$name' start at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ''

        & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$fullName" -DontTryModuleListFile "$dontTryListFilePath" | Write-Host

        Write-Host ''
        Write-Host -ForegroundColor Green "module installation ($i/$ModuleListCount) with list '$name' ended at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ''
    }

    & "$PbmiDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_after_install.txt" | Write-Host
    & "$PbmiDir\StrawberryPortable_e_RemoveDefenderExclude.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_f_RunDefenderScan.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_g_Optimize.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_after_optimize.txt" | Write-Host
    & "$PbmiDir\StrawberryPortable_h_Package.ps1" -StrawberryDir $StrawberryDir -DetectSevenZip -Use7zFormat | Write-Host

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
