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

Write-Host ''
Write-Host -ForegroundColor Green "started '$($MyInvocation.InvocationName)' ..."
Write-Host ''

$PathExtends = "$($StrawberryDir)\perl\site\bin;$($StrawberryDir)\perl\bin;$($StrawberryDir)\c\bin"
if ( $env:Path -notlike "*$PathExtends*" ) {
    $Env:PATH = "$PathExtends;$Env:PATH"
}

$perlexe = $StrawberryDir + '\perl\bin\perl.exe'
$perlInfo = & $perlexe -MConfig -e 'printf(qq{Perl executable : %s\nPerl version    : %vd / $Config{archname}}, $^X, $^V)' | Out-String
if ( 0 -ne $LASTEXITCODE) {
    Write-Host -ForegroundColor Red "FATAL ERROR: 'perl' failed with '$LASTEXITCODE' - abort!"
    exit
}

$perlInfoList = $perlInfo.Split("`n") | Where-Object { ! [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | ForEach-Object { "$_" }
$perlInfo | Write-Host -ForegroundColor Green

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
$modules = $generatedList | Where-Object {
    ! [string]::IsNullOrWhiteSpace( $_ )
} | ForEach-Object {
    ( $_ | Out-String ).Trim( )
} | Where-Object {
    ! [string]::IsNullOrWhiteSpace( $_ )
} | Sort-Object -Unique | ForEach-Object {
    $t = $_
    # Write-Host -ForegroundColor DarkGray "  => check $t"
    # line = modulename version
    if ( $t -match '^([\S]+)' ) {
        $m = $Matches[1]
        # some moule wrong listend => ignore?
        # if ( $m -match '^\d' -or $m -like ':*' ) {
        # Upper-Case defined as first character for none core / standard modules
        if ( $_ -notmatch '^(([A-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
            Write-Host -ForegroundColor Red "    => ignore - Match '$m'"
        }
        else {
            # Write-Host -ForegroundColor Yellow "    => found $m"
            $m
        }
    }
}

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewd finished search

$modules = $modules | Sort-Object -Unique

0..10 | ForEach-Object { Write-Host '' }
Write-Host -ForegroundColor Green '=> found modules:'
$modules | Write-Host
0..10 | ForEach-Object { Write-Host '' }

Write-Host -ForegroundColor Green "write list file $ModuleListFileTxt"
$fileHeaders, $modules, $fileFooters | Out-File -LiteralPath $ModuleListFileTxt -Encoding default -Force -Confirm:$false -Width 999

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$($MyInvocation.InvocationName)' ended"
Write-Host ''
