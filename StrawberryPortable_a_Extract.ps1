<#

.SYNOPSIS

Extracts the Strawberry ZIP

.PARAMETER StrawberryZip

Path to Strawberry ZIP portable.

.PARAMETER Destination

Optional path where extracted. If not given, extracted directory name is file name.

.PARAMETER SevenZipPath

Optional path to 7z.exe

.PARAMETER DetectSevenZip

Optional auto detect 7z path

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
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*strawberry*portable*.zip' })]
    [string] $StrawberryZip,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf -IsValid })]
    [ValidateScript({ $_ -like '*strawberry*portable*' })]
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $Destination,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*7z.exe' })]
    [string] $SevenZipPath,

    [switch] $DetectSevenZip
)

$ScriptPath = ''
$transcript = $false

try {
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
    Write-Host -ForegroundColor Green "started '$ScriptPath' ..."
    Write-Host ''

    $zip = Get-Item -LiteralPath $StrawberryZip
    if ( [string]::IsNullOrWhiteSpace($Destination) ) {
        $targetPath = "$($zip.Directory.FullName)\$($zip.BaseName)"
    }
    else {
        $targetPath = $Destination
    }

    if ( Test-Path -LiteralPath $targetPath ) {
        throw "extraction target $targetPath already exists"
    }

    if ( $DetectSevenZip -and [string]::IsNullOrWhiteSpace($SevenZipPath) ) {
        Write-Host -ForegroundColor Green 'search for 7z'

        $sz_pf64 = "$($Env:ProgramFiles)\7-Zip\7z.exe"
        $sz_pf32 = "$(${env:ProgramFiles(x86)})\7-Zip\7z.exe"

        $sz = Get-Command 7z -ErrorAction SilentlyContinue
        if ( $sz ) {
            $SevenZipPath = $sz.Source
        }
        elseif ( Test-Path -LiteralPath $sz_pf64 -PathType Leaf) {
            $SevenZipPath = $sz_pf64
        }
        elseif ( Test-Path -LiteralPath $sz_pf32 -PathType Leaf) {
            $SevenZipPath = $sz_pf32
        }
        else {
            throw '7z not found!'
        }

        Write-Host -ForegroundColor Green "found at '$SevenZipPath'"
    }

    Write-Host ''
    Write-Host -ForegroundColor Green "unzip '$StrawberryZip' to '$targetPath'"

    $failed = $false

    $zipStartTIme = Get-Date
    Write-Host "unzip start time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipStartTIme )"

    if ( [string]::IsNullOrWhiteSpace($SevenZipPath) ) {
        try {
            # Expand-Archive is really slow
            # Expand-Archive -LiteralPath $StrawberryZip -DestinationPath $targetPath
            # use .Net direct
            Add-Type -Assembly System.IO.Compression.Filesystem
            [IO.Compression.ZipFile]::ExtractToDirectory( $StrawberryZip, $targetPath )
        }
        catch {
            $failed = $true
            Write-Host -ForegroundColor Red "ERROR: unzip '$StrawberryZip' to '$targetPath' - FAILED ! msg: $_"
        }
    }
    else {
        # 7z is faster
        & "$SevenZipPath" 'x' '-bt' '-spe' '-aoa' '-bb0' '-bd' "-o$targetPath" "$StrawberryZip"
        if ( 0 -ne $LASTEXITCODE ) {
            $failed = $true
            Write-Host -ForegroundColor Red "ERROR: unzip '$StrawberryZip' to '$targetPath' - FAILED ! LASTEXITCODE: $LASTEXITCODE"
        }
    }

    if ( ! $failed ) {
        $zipEndTime = Get-Date
        Write-Host "unzip end time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipEndTime)"
        Write-Host "unzip duration $( (New-TimeSpan -Start $zipStartTIme -End $zipEndTime).TotalSeconds )"
        exit 0
    }
    else {
        exit 1
    }
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
}