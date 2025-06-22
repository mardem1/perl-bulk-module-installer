
<#

DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

#>

[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            Test-Path -LiteralPath $_ -PathType Container
        })]
    [string] $LiteralPath
)

[hashtable] $modules = @{}

1..10 | ForEach-Object { Write-Host '' }
Write-Host "=> Search for modules in '$LiteralPath'"

1..10 | ForEach-Object { Write-Host '' }
Get-ChildItem -Recurse -File -Force -LiteralPath $LiteralPath | Where-Object {
    # BAT files for perl in batch wrapper
    $_.Name -match '\.(pl|pm|t|bat)$'
} | ForEach-Object  {
    1..2 | ForEach-Object { Write-Host '' }
    Write-Host "=> check file '$($_.FullName)'"
    
    $_
} | Get-Content | ForEach-Object {
    # Upper-Case defined as first character for none core / standard modules
    # should match => 'use XYZ...ABC;' 'use XYZ...ABC (..);'  'use XYZ...ABC qw(..);' 'use XYZ...ABC qw(' 'use XYZ...ABC'
    if ( $_ -cmatch "\buse\b\s+([A-Z][A-Za-z0-9:_]+)") {
        $text = $Matches[1]

        # add custom filter here - exclude own modules ?
        if ( $true ) {
            Write-Host "=> $text"
            $modules[$text] = $true
        }
    }
}

1..10 | ForEach-Object { Write-Host '' }
Write-Host "=> filter unique"
$modules2 = $($modules.Keys | Select-Object -Unique | Sort-Object )

1..10 | ForEach-Object { Write-Host '' }
Write-Host "=> found modules"
$modules2 | ForEach-Object { "$_" }
