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
    $LogDir = "$ScriptDir\log"
    Start-Transcript -LiteralPath "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($ScriptItem.BaseName).log"
    $transcript = $true

    Write-Host ''
    Write-Host -ForegroundColor Green "started '$ScriptPath' ..."
    Write-Host ''

    $hasAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Write-Host ''
    if ( ! $hasAdmin ) {
        Write-Host -ForegroundColor Red 'ERROR: admin required for defender config!'
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
    $portableDir = 'C:\perl-build'

    $StrawberryZip = "$portableDir\$portableBaseName.zip"
    $StrawberryDir = "$portableDir\$portableBaseName"

    if ( !( Test-Path -LiteralPath $StrawberryZip ) ) {
        throw "zip source $StrawberryZip not found"
    }

    if ( Test-Path -LiteralPath $StrawberryDir ) {
        throw "extraction target $StrawberryDir already exists"
    }

    & "$ScriptDir\StrawberryPortable_a_Extract.ps1" -StrawberryZip $StrawberryZip -Destination $StrawberryDir | Write-Host
    & "$ScriptDir\StrawberryPortable_b_AddDefenderExclude.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$ScriptDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_before.txt" | Write-Host

    # it's not recommended to update module if not needed
    # install all Updates before ?
    # & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -OnlyAllUpdates -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt"
    # install all Updates in same install run ?
    # & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -AllUpdates -InstallModuleListFile "$ScriptDir\test-module-lists\CoreCarpModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt"

    # install modules
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\CoreCarpModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\SingleModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\SmallModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\MediumModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host

    # direct loop ?
    # & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\SingleModuleExample.txt", "$ScriptDir\test-module-lists\SmallModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host

    # other lists
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\perl_module_rperl.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\MojoliciusTest.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host

    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_learning_perl.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_perl_testing_a_developers_notebook.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_effective_perl_512.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_modern_perl_512.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_intermediate_perl.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_perl_best_practices.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\perl_modules_win32.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_modern_perl_522.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_programming_perl.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\book_mastering_perl.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host

    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\perl_critic_modules.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\perl_modules_other.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\ReallyLargeModuleExample.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir $StrawberryDir -InstallModuleListFile "$ScriptDir\test-module-lists\perl_modules.txt" -DontTryModuleListFile "$ScriptDir\test-module-lists\_dont_try_modules.txt" | Write-Host

    & "$ScriptDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_after_install.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_e_RemoveDefenderExclude.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$ScriptDir\StrawberryPortable_f_RunDefenderScan.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$ScriptDir\StrawberryPortable_g_Optimize.ps1" -StrawberryDir $StrawberryDir | Write-Host
    & "$ScriptDir\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir $StrawberryDir -ModuleListFileTxt "$LogDir\$(Get-Date -Format 'yyyyMMdd_HHmmss')_list_after_optimize.txt" | Write-Host
    & "$ScriptDir\StrawberryPortable_h_Package.ps1" -StrawberryDir $StrawberryDir -DetectSevenZip -Use7zFormat | Write-Host

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
    Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
    Write-Host ''

    if ($transcript) {
        Stop-Transcript
    }

    $Global:ErrorActionPreference = $ori_ErrorActionPreference
}
