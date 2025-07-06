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
    [ValidateScript({ $_ -like '*strawberry*portable*' })]
    [string] $StrawberryDir,

    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf -IsValid })]
    [ValidateScript({ $_ -like '*.txt' })]
    [string] $ModuleListFileTxt
)

$ScriptPath = $MyInvocation.InvocationName
# Invoked wiht &
if ( $ScriptPath -eq '&' -and
    $null -ne $MyInvocation.MyCommand -and
    ! [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path) ) {
    $ScriptPath = $MyInvocation.MyCommand.Path
}

$ScriptItem = Get-Item -LiteralPath $ScriptPath -ErrorAction Stop
Start-Transcript -LiteralPath "$($ScriptItem.Directory.FullName)\log\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($ScriptItem.BaseName).log"

Write-Host ''
Write-Host -ForegroundColor Green "started '$ScriptPath' ..."
Write-Host ''

$PathExtends = "$($StrawberryDir)\perl\site\bin;$($StrawberryDir)\perl\bin;$($StrawberryDir)\c\bin"
if ( $env:Path -notlike "*$PathExtends*" ) {
    $Env:PATH = "$PathExtends;$Env:PATH"
}

$perlexe = $StrawberryDir + '\perl\bin\perl.exe'
$perlInfo = & $perlexe -MConfig -e 'printf(qq{Perl executable : %s\nPerl version    : %s / $Config{archname}}, $^X, $^V)' | Out-String
if ( 0 -ne $LASTEXITCODE) {
    Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
    exit
}

# perl -e "printf(qq{%s}, $^X)" = $perlexe
$perlVersion = & $perlexe -e 'print "$^V"' | Out-String # = eg. 5.40.2
# perl -MConfig -e "print $Config{archname}" = MSWin32-x64-multi-thread

$perlInfoList = $perlInfo.Split("`n") | Where-Object { ! [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | ForEach-Object { "$_" }
$perlInfo | Write-Host -ForegroundColor Green
Write-Host ''

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
    if ( $t -notmatch '^([\S]+)[\s]+([\S]+)$' ) {
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

        # some moule wrong listend => ignore?
        # if ( $m -match '^\d' -or $m -like ':*' ) {
        # Upper-Case defined as first character for none core / standard modules
        if ( $m -notmatch '^(([A-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
            Write-Host -ForegroundColor Red "    => ignore - no match '$m'"
        }
        else {
            # FIXME: what if module already there but other version ?

            # Write-Host -ForegroundColor Yellow "    => found $m"
            $modules[$m] = $v
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
Write-Host ''

Write-Host -ForegroundColor Green "write list file $ModuleListFileTxt"
$fileHeaders, $moduleNames, $fileFooters | Out-File -LiteralPath $ModuleListFileTxt -Encoding default -Force -Confirm:$false -Width 999
Write-Host ''

$ModuleListFileCsv = $ModuleListFileTxt.Replace('.txt', '.csv')
Write-Host -ForegroundColor Green "write csv file $ModuleListFileCsv"

$moduleLines = $moduleNames | ForEach-Object {
    $m = $_
    $v = $modules[$m]
    "$m;$v"
}

"# installed_modules_found;$perlVersion", $moduleLines | Out-File -LiteralPath $ModuleListFileCsv -Encoding default -Force -Confirm:$false -Width 999

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$ScriptPath' ended"
Write-Host ''

Stop-Transcript