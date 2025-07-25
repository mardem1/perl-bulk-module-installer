﻿
<#

.SYNOPSIS

Wrapper for InstallCpanModules.pl as PowerShell

Install perl modules in bulk with some logic to make this more efficient,
details can be found in the C<README.md>

.PARAMETER StrawberryDir

Dir for strawberry dir to install the modules

.PARAMETER InstallModuleListFile

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) to
install. One Name per Line, # marks a comment line Linux-Line-Ends preferred but all work's.

.PARAMETER DontTryModuleListFIle

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) which will not be installed.
One Name per Line, # marks a comment line, Linux-Line-Ends preferred but all work's.

.PARAMETER NoTestsModuleListFile

Filepath to a text file which contains Perl-Module-Names (eg. Perl::Critic) which will be installed without execution of tests.
One Name per Line, # marks a comment line, Linux-Line-Ends preferred but all work's.

.PARAMETER OnlyAllUpdates

Only update installed modules, no modules from a given filelist will be
installed.

Attention: If a new module version has a additional dependency, this dependency
will be installed!

.PARAMETER AllUpdates

Do not install updates for modules, exception a new module require a module
update as dependency.

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
    [Parameter(ParameterSetName = 'StandardA', Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'StandardB', Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'OnlyAllUpdatesA', Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'OnlyAllUpdatesB', Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    # [ValidateScript({ $_ -like '*strawberry*portable*' })]
    # better test perl.exe location, path name not the point
    [ValidateScript({ $_ -like '*strawberry*' })]
    [ValidateScript({ Test-Path -LiteralPath "$_\perl\bin\perl.exe" -PathType Leaf })]
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $StrawberryDir,

    [Parameter(ParameterSetName = 'StandardA', Mandatory = $true, Position = 1)]
    [Parameter(ParameterSetName = 'StandardB', Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            $notFound = $false
            $_ | ForEach-Object {
                if ( [string]::IsNullOrWhiteSpace( $_ ) ) {
                    $notFound = $true
                }
                elseif ( $_ -notlike '*.txt' ) {
                    $notFound = $true
                }
                elseif ( ! ( Test-Path -LiteralPath $_ -PathType Leaf ) ) {
                    $notFound = $true
                }
            }
            ! $notFound
        })]
    [string[]] $InstallModuleListFile,

    [Parameter(ParameterSetName = 'StandardA', Mandatory = $false, Position = 2)]
    [Parameter(ParameterSetName = 'StandardB', Mandatory = $true, Position = 2)]
    [Parameter(ParameterSetName = 'OnlyAllUpdatesA', Mandatory = $false, Position = 1)]
    [Parameter(ParameterSetName = 'OnlyAllUpdatesB', Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $DontTryModuleListFile,

    [Parameter(ParameterSetName = 'StandardB', Mandatory = $false, Position = 3)]
    [Parameter(ParameterSetName = 'OnlyAllUpdatesB', Mandatory = $false, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $NoTestsModuleListFile,

    [Parameter(ParameterSetName = 'OnlyAllUpdatesA')]
    [Parameter(ParameterSetName = 'OnlyAllUpdatesB')]
    [switch] $OnlyAllUpdates,

    [Parameter(ParameterSetName = 'StandardB')]
    [switch] $AllUpdates
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
        '# install modules ...',
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

    # for PerlBulkModuleInstaller
    # $Env:PERL5LIB = "$((Get-Item -LiteralPath $InstallCpanModules).Directory.FullName)\lib".Replace('\', '/')

    $InstallCpanModules = "$($ScriptItem.Directory.FullName)\InstallCpanModules.pl"

    Write-Host "Set-Location $($ScriptItem.Directory.FullName)"
    Set-Location -LiteralPath "$($ScriptItem.Directory.FullName)"

    0..25 | ForEach-Object { Write-Host '' }

    # TODO: replace with Start-Process and created ARGV

    if ( $OnlyAllUpdates) {
        if ( [string]::IsNullOrWhiteSpace($DontTryModuleListFile)) {
            Write-Host -ForegroundColor Green "start '$InstallCpanModules' with --only-all-updates"
            Write-Host ''
            & $perlexe $InstallCpanModules '--only-all-updates' | Write-Host
        }
        if ( [string]::IsNullOrWhiteSpace($NoTestsModuleListFile)) {
            Write-Host -ForegroundColor Green "start '$InstallCpanModules' with --only-all-updates and '$DontTryModuleListFile'"
            Write-Host ''
            & $perlexe $InstallCpanModules '--only-all-updates' $DontTryModuleListFile | Write-Host
        }
        else {
            Write-Host -ForegroundColor Green "start '$InstallCpanModules' with --only-all-updates and '$DontTryModuleListFile' and '$NoTestsModuleListFile'"
            Write-Host ''
            & $perlexe $InstallCpanModules '--only-all-updates' $DontTryModuleListFile $NoTestsModuleListFile | Write-Host
        }

        if (0 -ne $LASTEXITCODE) {
            Write-Host -ForegroundColor Red "FATAL ERROR: '$InstallCpanModules' with '$LASTEXITCODE' failed?"
            throw 'InstallCpanModules failed'
        }
    }
    else {
        $InstallModuleListFile | ForEach-Object {
            $listfile = $_

            if ( $AllUpdates ) {
                if ( [string]::IsNullOrWhiteSpace($DontTryModuleListFile)) {
                    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with -all-updates and '$listfile'"
                    Write-Host ''
                    & $perlexe $InstallCpanModules '-all-updates' $listfile | Write-Host
                }
                if ( [string]::IsNullOrWhiteSpace($NoTestsModuleListFile)) {
                    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with -all-updates and '$listfile' and '$DontTryModuleListFile'"
                    Write-Host ''
                    & $perlexe $InstallCpanModules '-all-updates' $listfile $DontTryModuleListFile | Write-Host
                }
                else {
                    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with -all-updates and '$listfile' and '$DontTryModuleListFile' and '$NoTestsModuleListFile'"
                    Write-Host ''
                    & $perlexe $InstallCpanModules '-all-updates' $listfile $DontTryModuleListFile $NoTestsModuleListFile | Write-Host
                }
            }
            else {
                if ( [string]::IsNullOrWhiteSpace($DontTryModuleListFile)) {
                    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with '$listfile'"
                    Write-Host ''
                    & $perlexe $InstallCpanModules $listfile | Write-Host
                }
                if ( [string]::IsNullOrWhiteSpace($NoTestsModuleListFile)) {
                    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with '$listfile' and '$DontTryModuleListFile'"
                    Write-Host ''
                    & $perlexe $InstallCpanModules $listfile $DontTryModuleListFile | Write-Host
                }
                else {
                    Write-Host -ForegroundColor Green "start '$InstallCpanModules' with '$listfile' and '$DontTryModuleListFile' and '$NoTestsModuleListFile'"
                    Write-Host ''
                    & $perlexe $InstallCpanModules $listfile $DontTryModuleListFile $NoTestsModuleListFile | Write-Host
                }
            }

            if (0 -ne $LASTEXITCODE) {
                Write-Host -ForegroundColor Red "FATAL ERROR: '$InstallCpanModules' with '$LASTEXITCODE' failed?"
                throw 'InstallCpanModules failed'
            }
        }
    }

    0..25 | ForEach-Object { Write-Host '' }

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
