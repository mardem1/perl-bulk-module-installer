
<#

.SYNOPSIS

extract strawberry portable, install module and package again as 7z

.PARAMETER StrawberryVersionNumber

Version-Number eg. 5.14.4.1

.PARAMETER StrawberryZipBaseName

Full basename for ZIP file if not given generated via Version-Number

.PARAMETER BuildDir

Basedir of all Operations - search for ZIP and Sub-Folder for extraction

.PARAMETER StrawberryZip

Path to ZIP, if not given generated based on Strawberry infos above and in BuilDir

.PARAMETER StrawberryDir

Path in which the zip will be extracted, if not given generated based on Strawberry infos above and in BuilDir

.PARAMETER PbmiDir

Path to perl-bulk-module-installer directory, generated if empty

.PARAMETER LogDir

Path to log directory, generated if empty

.PARAMETER ModuleListsDirPath

Path which contains the module install/dont-try lists, generated if empty

.PARAMETER DontTryListFilePath

Path for the Dont-Try-List, generated if empty

.PARAMETER InstallListFilePath

Explicit List-File for installation, if not given, all files in ModuleListsDirPath (except DontTryListFilePath) will be used.

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

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ ! [string]::IsNullOrWhiteSpace( $_ ) })]
    [ValidateScript({ $_ -match '^5[.]\d+[.]\d+[.]\d+$' })]
    [string] $StrawberryVersionNumber = '5.24.4.1',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ ! [string]::IsNullOrWhiteSpace( $_ ) })]
    [ValidateScript({ $_ -like '*strawberry*' })]
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $StrawberryZipBaseName = "strawberry-perl-$($StrawberryVersionNumber)-64bit-portable",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ ! [string]::IsNullOrWhiteSpace( $_ ) })]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container -IsValid })]
    [string] $BuildDir = 'C:\perl-build',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ ! [string]::IsNullOrWhiteSpace( $_ ) })]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $StrawberryZip = "$BuildDir\$StrawberryZipBaseName.zip",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ ! [string]::IsNullOrWhiteSpace( $_ ) })]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container -IsValid })]
    [string] $StrawberryDir = "$BuildDir\$StrawberryZipBaseName",

    [Parameter(Mandatory = $false)]
    [string] $PbmiDir = '', # based on Script-Dir if empty

    [Parameter(Mandatory = $false)]
    [string] $LogDir = '',  # based on Pbmi-Dir if empty

    [Parameter(Mandatory = $false)]
    [string] $ModuleListsDirPath = '',  # based on Pbmi-Dir if empty

    [Parameter(Mandatory = $false)]
    [string] $DontTryListFilePath = '', # based on ModuleListsDirPath if empty

    [Parameter(Mandatory = $false)]
    [string] $InstallListFilePath = '' # unused if empty
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
    $ScriptDir = $ScriptItem.Directory.FullName

    if ( [string]::IsNullOrWhiteSpace($PbmiDir) ) {
        $PbmiDir = "$ScriptDir"
    }
    elseif ( ! ( Test-Path -LiteralPath "$PbmiDir\InstallCpanModules.pl" -PathType Leaf) ) {
        Write-Host -ForegroundColor Red 'ERROR: perl-bulk-module-installer (InstallCpanModules) not found!'
        exit 1
    }

    if ( [string]::IsNullOrWhiteSpace($LogDir) ) {
        $LogDir = "$PbmiDir\log"
    }
    elseif ( ! ( Test-Path -LiteralPath "$LogDir" -PathType Container -IsValid) ) {
        Write-Host -ForegroundColor Red 'ERROR: LogDir not valid!'
        exit 1
    }

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

    if ( !( Test-Path -LiteralPath $StrawberryZip ) ) {
        throw "zip source $StrawberryZip not found"
    }

    if ( Test-Path -LiteralPath $StrawberryDir ) {
        throw "extraction target $StrawberryDir already exists"
    }

    if ( [string]::IsNullOrWhiteSpace($ModuleListsDirPath) ) {
        $ModuleListsDirPath = "$PbmiDir\test-module-lists"
    }

    if ( !( Test-Path -LiteralPath $ModuleListsDirPath -PathType Container ) ) {
        throw "list dir $ModuleListsDirPath not found"
    }

    if ( [string]::IsNullOrWhiteSpace($DontTryListFilePath) ) {
        $DontTryListFilePath = "$ModuleListsDirPath\_dont_try_modules.txt"
    }

    if ( !( Test-Path -LiteralPath $DontTryListFilePath -PathType Leaf ) ) {
        throw "dont-try list file $DontTryListFilePath not found"
    }

    if ( ![string]::IsNullOrWhiteSpace($InstallListFilePath) ) {
        if ( !( Test-Path -LiteralPath $InstallListFilePath -PathType Leaf ) ) {
            throw "install list file $InstallListFilePath not found"
        }
    }

    & "$PbmiDir\StrawberryPortable_a_Extract.ps1" -StrawberryZip $StrawberryZip -Destination $StrawberryDir | Write-Host

    & "$PbmiDir\StrawberryPortable_b_AddDefenderExclude.ps1" -StrawberryDir $StrawberryDir | Write-Host

    # elevate ?
    # Start-Process -Verb RunAs -FilePath "$(Get-Process -PID $PID | Select-Object -ExpandProperty Path)" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PbmiDir\StrawberryPortable_b_AddDefenderExclude.ps1`" -StrawberryDir `"$StrawberryDir`""

    & "$PbmiDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_before.txt" | Write-Host

    # it's not recommended to update module if not needed

    # install all Updates before ?
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -OnlyAllUpdates -DontTryModuleListFile "$DontTryListFilePath"

    # install all Updates in same install run ?
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -AllUpdates -InstallModuleListFile "$ModuleListsDirPath\CoreCarpModuleExample.txt" -DontTryModuleListFile "$DontTryListFilePath"

    # install modules
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ModuleListsDirPath\SingleModuleExample.txt" -DontTryModuleListFile "$DontTryListFilePath" | Write-Host

    # direct loop ?
    # & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ModuleListsDirPath\SingleModuleExample.txt", "$ModuleListsDirPath\SmallModuleExample.txt" -DontTryModuleListFile "$DontTryListFilePath" | Write-Host

    if (![string]::IsNullOrWhiteSpace($InstallListFilePath)) {
        $tmpList = Get-Item -LiteralPath "$InstallListFilePath"
    }
    else {
        $tmpList = Get-ChildItem -LiteralPath "$ModuleListsDirPath\" -File
    }

    $ModuleListFiles = $tmpList | Where-Object {
        $_.Name -like '*.txt'
    } | Where-Object {
        $_.FullName -ne $DontTryListFilePath
    } | ForEach-Object {
        $item = $_
        $name = $item.Name
        $fullName = $item.FullName
        $m = Get-Content -LiteralPath $fullName | Where-Object { ! [string]::IsNullOrWhiteSpace( $_ ) -and $_ -notlike '#*' } | Sort-Object -Unique
        $moduleCount = @($m).Count

        [pscustomobject] @{
            Name        = $name
            FullName    = $fullName
            ModuleCount = $moduleCount
        } | Write-Output
    }

    $ModuleListCount = @($ModuleListFiles).Count
    if ( 0 -eq $ModuleListCount -or !$ModuleListFiles ) {
        throw 'no useable install list-file found'
    }

    $i = 0

    $ModuleListFiles | Sort-Object -Property ModuleCount, FullName | ForEach-Object {
        $i++

        $item = $_
        $name = $item.Name
        $fullName = $item.FullName

        # Workaround ?

        Write-Host ''
        Write-Host -ForegroundColor Green "module installation ($i/$ModuleListCount) with list '$name' (1/2) start at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ''

        & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$fullName" -DontTryModuleListFile "$DontTryListFilePath" | Write-Host

        Write-Host ''
        Write-Host -ForegroundColor Green "module installation ($i/$ModuleListCount) with list '$name' (1/2) ended at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ''

        # ToDo: use of updated core-modules need #2 run to detect change ?

        Write-Host ''
        Write-Host -ForegroundColor Green "module installation ($i/$ModuleListCount) with list '$name' (2/2) start at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ''

        & "$PbmiDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$fullName" -DontTryModuleListFile "$DontTryListFilePath" | Write-Host

        Write-Host ''
        Write-Host -ForegroundColor Green "module installation ($i/$ModuleListCount) with list '$name' (2/2) ended at $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ''
    }

    & "$PbmiDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_after_install.txt" | Write-Host
    & "$PbmiDir\StrawberryPortable_e_RemoveDefenderExclude.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_f_RunDefenderScan.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$PbmiDir\StrawberryPortable_g_Optimize.ps1" -StrawberryDir $StrawberryDir -MergeLibs -RemoveBuildTools | Write-Host
    & "$PbmiDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_after_optimize.txt" | Write-Host
    & "$PbmiDir\StrawberryPortable_h_Package.ps1" -StrawberryDir $StrawberryDir -DetectSevenZip -Use7zFormat -RemoveStrawberryDirOnFinish | Write-Host

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
