
<#

.SYNOPSIS

create a ZIP for the Strawberry directory

.PARAMETER StrawberryDir

Path to Strawberry directory for zipping

.PARAMETER SevenZipPath

Optional path to 7z.exe

.PARAMETER DetectSevenZip

Optional auto detect 7z path

.PARAMETER Use7zFormat

Optional pack as 7z instead of zip

.PARAMETER RemoveStrawberryDirOnFinish

removes packaged dir

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
    [Parameter(ParameterSetName = 'OnlyZip', Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'SevenZipPath', Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'DetectSevenZip', Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    # [ValidateScript({ $_ -like '*strawberry*portable*' })]
    # better test perl.exe location, path name not the point
    [ValidateScript({ $_ -like '*strawberry*' })]
    [ValidateScript({ Test-Path -LiteralPath "$_\perl\bin\perl.exe" -PathType Leaf })]
    [ValidateScript({ $_ -notlike '*\' })]
    [string] $StrawberryDir,

    [Parameter(ParameterSetName = 'SevenZipPath', Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [ValidateScript({ $_ -like '*7z.exe' })]
    [string] $SevenZipPath,

    [Parameter(ParameterSetName = 'DetectSevenZip', Mandatory = $true, Position = 1)]
    [switch] $DetectSevenZip,

    [Parameter(ParameterSetName = 'SevenZipPath')]
    [Parameter(ParameterSetName = 'DetectSevenZip')]
    [switch] $Use7zFormat,

    [Parameter(ParameterSetName = 'SevenZipPath')]
    [Parameter(ParameterSetName = 'DetectSevenZip')]
    [switch] $RemoveStrawberryDirOnFinish
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

    $dir = Get-Item -LiteralPath $StrawberryDir

    $packagedTimestmp = Get-Date -Format 'yyyyMMdd_HHmmss'

    $targetPath = "$($dir.FullName)-packaged-$($packagedTimestmp)"
    if ( $Use7zFormat ) {
        $targetPath = "$($targetPath).7z"
    }
    else {
        $targetPath = "$($targetPath).zip"
    }

    if ( Test-Path -LiteralPath $targetPath ) {
        throw "compress target $targetPath already exists"
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
    Write-Host -ForegroundColor Green "zip '$StrawberryDir' as '$targetPath'"

    $failed = $false

    $zipStartTIme = Get-Date
    Write-Host "zip start time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipStartTIme )"

    if ( [string]::IsNullOrWhiteSpace($SevenZipPath) ) {
        try {
            # Compress-Archive is really slow
            # Compress-Archive -LiteralPath $StrawberryDir -DestinationPath $targetPath -CompressionLevel Fastest
            # use .Net direct
            Add-Type -Assembly System.IO.Compression.Filesystem
            [IO.Compression.ZipFile]::CreateFromDirectory(
                $StrawberryDir,
                $targetPath,
                [System.IO.Compression.CompressionLevel]::Optimal, # Fastest
                $false)
        }
        catch {
            $failed = $true
            Write-Host -ForegroundColor Red "ERROR: zip '$StrawberryDir' as '$targetPath' - FAILED ! msg: $_"
        }
    }
    else {
        # 7z is faster
        if ( $Use7zFormat ) {
            & "$SevenZipPath" 'a' '-t7z' '-mx=1' '-stl' '-bt' '-aoa' '-bb0' '-bd' "$targetPath" "$StrawberryDir\*"
        }
        else {
            # 'x=5' # default | 'x=1' # fasterst |'x=9' # Ultra
            & "$SevenZipPath" 'a' '-tzip' '-mx=9' '-stl' '-bt' '-aoa' '-bb0' '-bd' "$targetPath" "$StrawberryDir\*"
        }

        if ( 0 -ne $LASTEXITCODE ) {
            $failed = $true
            Write-Host -ForegroundColor Red "ERROR: zip '$StrawberryDir' as '$targetPath' - FAILED ! LASTEXITCODE: $LASTEXITCODE"
        }
    }

    if ( ! $failed ) {
        $zipEndTime = Get-Date
        Write-Host "zip end time $( Get-Date -Format 'yyyy-MM-dd HH:mm:ss' -Date $zipEndTime )"
        Write-Host "zip duration $( (New-TimeSpan -Start $zipStartTIme -End $zipEndTime).TotalSeconds )"

        if (! $RemoveStrawberryDirOnFinish ) {
            Write-Host -ForegroundColor Green "no RemoveStrawberryDirOnFinish keep '$StrawberryDir'"
        }
        else {
            Write-Host -ForegroundColor Green "RemoveStrawberryDirOnFinish remove '$StrawberryDir'"
            Remove-Item -LiteralPath $StrawberryDir -Recurse -Force -Confirm:$false -ErrorAction Stop
        }

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
