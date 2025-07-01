
<#

.SYNOPSIS

Browse one or more directories for perl files and search for used perl modules.

.PARAMETER SearchPath

Directories to search in.

.PARAMETER ModuleListFileTxt

Save result as List-File which can be used for PerlBulkModuleInstaller as Install-List.

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
    [ValidateScript({
            $notFound = $false
            $_ | ForEach-Object {
                if ( [string]::IsNullOrWhiteSpace( $_ ) ) {
                    $notFound = $true
                }
                elseif ( ! ( Test-Path -LiteralPath $_ -PathType Container ) ) {
                    $notFound = $true
                }
            }
            ! $notFound
        })]
    [string[]] $SearchPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            Test-Path -LiteralPath $_ -PathType Leaf -IsValid
        })]
    [ValidateScript({
            $_ -like '*.txt'
        })]
    [string] $ModuleListFileTxt
)

Write-Host ''
Write-Host -ForegroundColor Green "started '$($MyInvocation.InvocationName)' ..."
Write-Host ''

[hashtable] $modules = @{}

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished
$winUser = $env:USERNAME
$winHostName = $env:COMPUTERNAME
$winOs = ( Get-CimInstance Win32_OperatingSystem ).Caption

Write-Host -ForegroundColor Green '=> Search for modules in'
$SearchPath | ForEach-Object { "  - '$_'" }

Write-Host -ForegroundColor Green '=> search ...'
Get-ChildItem -Recurse -File -Force -LiteralPath $SearchPath | Where-Object {
    # BAT files for perl in batch wrapper
    $_.Name -match '\.(pl|pm|t|bat)$'
} | ForEach-Object {
    Write-Host -ForegroundColor DarkGray "=> check found file: '$($_.FullName)'"

    $_
} | Get-Content | ForEach-Object {
    # Upper-Case defined as first character for none core / standard modules
    # should match => 'use XYZ...ABC;' 'use XYZ...ABC (..);'  'use XYZ...ABC qw(..);' 'use XYZ...ABC qw(' 'use XYZ...ABC'
    # ending exclude ^: needed to exclude "use C:"
    if ( $_ -cmatch '\buse\b\s+(([A-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
        $text = $Matches[1]

        # add custom filter here - exclude own modules ?
        if ( $true ) {
            Write-Host -ForegroundColor Yellow "  => found module: '$text'"
            $modules[$text] = $true
        }
    }
}

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' # renewed at searched finished

Write-Host ''
Write-Host -ForegroundColor Green '=> filter unique'
$moduleNames = $($modules.Keys | Select-Object -Unique | Sort-Object )
Write-Host ''
Write-Host -ForegroundColor Green '=> found modules'
$moduleNames | ForEach-Object { "$_" }

$fileHeaders = (
    '#',
    '# perl modules searched in:'
)

$fileHeaders += $SearchPath | ForEach-Object {
    "# - $_"
}

$fileHeaders += (
    '#',
    "# Win-User     : $winUser",
    "# Win-Host     : $winHostName",
    "# Win-OS       : $winOs"
)

$fileHeaders += (
    '#',
    "# search done at '$now'"
)

$fileHeaders += (
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

Write-Host ''
Write-Host -ForegroundColor Green "=> generate module list file '$ModuleListFileTxt'"
$fileHeaders, $moduleNames, $fileFooters | Out-File -LiteralPath $ModuleListFileTxt

Write-Host ''
Write-Host -ForegroundColor Green 'done'
Write-Host ''
Write-Host -ForegroundColor Green "... '$($MyInvocation.InvocationName)' ended"
Write-Host ''
