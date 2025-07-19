
<#

.SYNOPSIS

.PARAMETER StrawberryDir

Dir for strawberry

.PARAMETER PerlFilesListFileTxt

Perlfiles listfile generated with ListUsedPerlModulesInDirectory.ps1

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

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*.perlfiles.txt' })]
    [string] $PerlFilesListFileTxt
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
    & $perlexe -MConfig -e 'printf(qq{Perl executable: %s\nPerl version   : %s / $Config{archname}\n\n}, $^X, $^V)' | Out-String | Write-Host -ForegroundColor Green

    if ( 0 -ne $LASTEXITCODE) {
        Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
        throw 'perl not working'
    }

    [hashtable] $testPerlFile = @{}

    $PerlFilesCheckNotFoundListFileTxt = $PerlFilesListFileTxt.Replace('.txt', '.notfound.perlfiles.txt')
    $PerlFilesCheckFailedListFileTxt = $PerlFilesListFileTxt.Replace('.txt', '.failed.perlfiles.txt')
    $PerlFilesCheckSuccessListFileTxt = $PerlFilesListFileTxt.Replace('.txt', '.success.perlfiles.txt')

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished
    $winUser = $env:USERNAME
    $winHostName = $env:COMPUTERNAME
    $winOs = ( Get-CimInstance Win32_OperatingSystem ).Caption

    $fileHeaders = (
        '#',
        '# => do perl check wiht files',
        '#'
    )

    $fileHeaders += (
        '#',
        "# Win-User     : $winUser",
        "# Win-Host     : $winHostName",
        "# Win-OS       : $winOs"
    )

    $fileHeaders += (
        '#',
        "# check done at '$now'"
    )

    $fileFooters = (
        '', # empty line after list
        '#',
        '# list ended',
        '#'
    )

    $filesToCheck = Get-Content -LiteralPath $PerlFilesListFileTxt | Where-Object { ! [string]::IsNullOrWhiteSpace( $_ ) -and $_ -notlike '#*' } | Sort-Object -Unique
    if ( ! $filesToCheck ) {
        Write-Host -ForegroundColor Red "given list '$PerlFilesListFileTxt' is empty"

        if ( Test-Path -LiteralPath $PerlFilesCheckFailedListFileTxt ) {
            Write-Host "remove perlfiles txt file $PerlFilesCheckFailedListFileTxt"
            Remove-Item -LiteralPath $PerlFilesCheckFailedListFileTxt
        }

        if ( Test-Path -LiteralPath $PerlFilesCheckSuccessListFileTxt ) {
            Write-Host "remove perlfiles txt file $PerlFilesCheckSuccessListFileTxt"
            Remove-Item -LiteralPath $PerlFilesCheckSuccessListFileTxt
        }
    }
    else {
        Write-Host ''
        Write-Host 'check...'
        Write-Host ''

        $filesToCheck | Sort-Object | Where-Object {
            $FullName = $_
            $found = Test-Path -LiteralPath $FullName -PathType Leaf
            if ( ! $found ) {
                Write-Host -ForegroundColor Red "file not found '$FullName'"
            }

            $found
        } | ForEach-Object {
            $FullName = $_
            $CheckOk = $false

            $Env:PERL5LIB = switch -Wildcard ($FullName) {
                '*\perl-bulk-module-installer\*.t' {
                    if ($FullName -match '^(.+\\perl-bulk-module-installer\\).+$') {
                        '' # "$($Matches[1])\lib;$($Matches[1])\t"
                    }
                    else {
                        ''
                    }
                    break
                }
                '*\perl-bulk-module-installer\*' {
                    if ($FullName -match '^(.+\\perl-bulk-module-installer\\).+$') {
                        '' # "$($Matches[1])\lib"
                    }
                    else {
                        ''
                    }
                    break
                }
                #
                # add custom PerlLib if needed here
                #
                default {
                    ''
                }
            }

            Write-Host -ForegroundColor DarkGray "set Env:PERL5LIB: '$($Env:PERL5LIB)' ..."
            Write-Host -ForegroundColor DarkGray "start Check: '$FullName' ..."

            Push-Location -LiteralPath ((Get-Item -LiteralPath $FullName).Directory.FullName)
            $start_time = [datetime]::Now

            try {
                # output to stderr so redirect
                & 'cmd.exe' '/c' "$perlexe" '-c' "$FullName" '2>&1' | Write-Host -ForegroundColor DarkCyan
            }
            catch {
                Write-Host -ForegroundColor Red "ERROR: msg: $_"
            }

            $end_time = [datetime]::Now
            Pop-Location

            if ( $null -ne $LASTEXITCODE -and 0 -eq $LASTEXITCODE ) {
                $CheckOk = $true
            }

            $time_diff = New-TimeSpan -Start $start_time -End $end_time
            $diff_sec = [System.Math]::Round($time_diff.TotalSeconds, 3)

            $color = [ConsoleColor]::Green
            if ( ! $CheckOk ) {
                $color = [ConsoleColor]::Red
            }

            Write-Host -ForegroundColor $color "CheckOk '$CheckOk' in '$diff_sec' sec - '$FullName'"
            $testPerlFile[$FullName] = $CheckOk
        }

        $success = $testPerlFile.Keys | Where-Object {
            $null -ne $testPerlFile[$_] -and $testPerlFile[$_]
        }

        $failed = $testPerlFile.Keys | Where-Object {
            $null -ne $testPerlFile[$_] -and ! $testPerlFile[$_]
        }

        $notFound = $testPerlFile.Keys | Where-Object {
            $null -eq $testPerlFile[$_]
        }

        Write-Host ''
        Write-Host 'files not-found summary:'
        if (!$notFound) {
            Write-Host '- no not-found files'

            if ( Test-Path -LiteralPath $PerlFilesCheckNotFoundListFileTxt ) {
                Write-Host "remove notfound txt file $PerlFilesCheckNotFoundListFileTxt"
                Remove-Item -LiteralPath $PerlFilesCheckNotFoundListFileTxt
            }
        }
        else {
            $notFound | Sort-Object | ForEach-Object {
                Write-Host "- '$_'"
            }

            $perlNotFoundHeaders = (
                '#',
                '# files not found:',
                '#',
                '' # empty line before list
            )

            Write-Host ''
            Write-Host -ForegroundColor Green "=> generate perl found files list file '$PerlFilesCheckNotFoundListFileTxt'"
            $fileHeaders, $perlNotFoundHeaders, $notFound, $fileFooters | Out-File -LiteralPath $PerlFilesCheckNotFoundListFileTxt
        }

        Write-Host ''
        Write-Host 'files check failed summary:'
        if (!$failed) {
            Write-Host '- no failed files'

            if ( Test-Path -LiteralPath $PerlFilesCheckFailedListFileTxt ) {
                Write-Host "remove failed txt file $PerlFilesCheckFailedListFileTxt"
                Remove-Item -LiteralPath $PerlFilesCheckFailedListFileTxt
            }
        }
        else {
            $failed | Sort-Object | ForEach-Object {
                Write-Host "- '$_'"
            }

            $perlFailedHeaders = (
                '#',
                '# perl -c failed for files:',
                '#',
                '' # empty line before list
            )

            Write-Host ''
            Write-Host -ForegroundColor Green "=> generate perl failed files list file '$PerlFilesCheckFailedListFileTxt'"
            $fileHeaders, $perlFailedHeaders, $failed, $fileFooters | Out-File -LiteralPath $PerlFilesCheckFailedListFileTxt
        }
    }

    Write-Host ''
    Write-Host 'files check success summary:'
    if (!$success) {
        Write-Host '- no successed files'

        if ( Test-Path -LiteralPath $PerlFilesCheckSuccessListFileTxt ) {
            Write-Host "remove success txt file $PerlFilesCheckSuccessListFileTxt"
            Remove-Item -LiteralPath $PerlFilesCheckSuccessListFileTxt
        }
    }
    else {
        $success | Sort-Object | ForEach-Object {
            Write-Host "- '$_'"
        }

        $perlSuccessHeaders = (
            '#',
            '# perl -c succeeded for files:',
            '#',
            '' # empty line before list
        )

        Write-Host ''
        Write-Host -ForegroundColor Green "=> generate perl success files list file '$PerlFilesCheckSuccessListFileTxt'"
        $fileHeaders, $perlSuccessHeaders, $success, $fileFooters | Out-File -LiteralPath $PerlFilesCheckSuccessListFileTxt
    }

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished

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
