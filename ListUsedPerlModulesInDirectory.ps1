
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

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            Test-Path -LiteralPath $_ -PathType Leaf -IsValid
        })]
    [ValidateScript({
            $_ -like '*.txt'
        })]
    [string] $ModuleListFileTxt   
)

[hashtable] $modules = @{}

1..10 | ForEach-Object { Write-Host '' }
Write-Host "=> Search for modules in"
$SearchPath | ForEach-Object { "  - '$_'" }

1..10 | ForEach-Object { Write-Host '' }
Get-ChildItem -Recurse -File -Force -LiteralPath $SearchPath | Where-Object {
    # BAT files for perl in batch wrapper
    $_.Name -match '\.(pl|pm|t|bat)$'
} | ForEach-Object {
    1..2 | ForEach-Object { Write-Host '' }
    Write-Host "=> check file '$($_.FullName)'"
    
    $_
} | Get-Content | ForEach-Object {
    # Upper-Case defined as first character for none core / standard modules
    # should match => 'use XYZ...ABC;' 'use XYZ...ABC (..);'  'use XYZ...ABC qw(..);' 'use XYZ...ABC qw(' 'use XYZ...ABC'
    # ending exclude ^: needed to exclude "use C:"
    if ( $_ -cmatch '\buse\b\s+(([A-Z][a-zA-Z0-9_]*)([:][:][a-zA-Z0-9_]+)*)[^:]' ) {
        $text = $Matches[1]

        # add custom filter here - exclude own modules ?
        if ( $true ) {
            Write-Host "=> $text"
            $modules[$text] = $true
        }
    }
}

1..10 | ForEach-Object { Write-Host '' }
Write-Host '=> filter unique'
$modules2 = $($modules.Keys | Select-Object -Unique | Sort-Object )

1..10 | ForEach-Object { Write-Host '' }
Write-Host '=> found modules'
$modules2 | ForEach-Object { "$_" }

if ( ! [string]::IsNullOrWhiteSpace($ModuleListFileTxt) ) {
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K' 
    $SearchPath
    $modules2
    
    Write-Host "=> generate module list file '$ModuleListFileTxt'"
    '#', "# perl modules searched in '$SearchPath'", "# search done at '$now'", '# modules found:', '#', $modules2, '#', '# list ended', '#' | Out-File -LiteralPath $ModuleListFileTxt
}
