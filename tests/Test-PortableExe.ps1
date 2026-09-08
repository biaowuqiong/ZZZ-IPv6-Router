[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedExe = (Resolve-Path -LiteralPath $Path).Path
$assembly = [Reflection.Assembly]::LoadFile($resolvedExe)
$expected = @{
    'ZZZIPv6Router.Install.ps1' = (Join-Path $projectRoot 'Install.ps1')
    'ZZZIPv6Router.Uninstall.ps1' = (Join-Path $projectRoot 'Uninstall.ps1')
    'ZZZIPv6Router.GetStatus.ps1' = (Join-Path $projectRoot 'Get-Status.ps1')
    'ZZZIPv6Router.Config' = (Join-Path $projectRoot 'config.default.json')
    'ZZZIPv6Router.Update.ps1' = (Join-Path $projectRoot 'src\Update-ZZZIPv6Route.ps1')
}

function Get-ByteHash {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

foreach ($entry in $expected.GetEnumerator()) {
    $resourceStream = $assembly.GetManifestResourceStream($entry.Key)
    if ($null -eq $resourceStream) {
        throw "Missing embedded resource: $($entry.Key)"
    }
    try {
        $memory = [IO.MemoryStream]::new()
        try {
            $resourceStream.CopyTo($memory)
            $embeddedHash = Get-ByteHash -Bytes $memory.ToArray()
        }
        finally {
            $memory.Dispose()
        }
    }
    finally {
        $resourceStream.Dispose()
    }

    $sourceHash = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($embeddedHash -ne $sourceHash) {
        throw "Embedded resource differs from source: $($entry.Key)"
    }
}

$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedExe).FileVersion
if ($version -ne '0.2.0.0') {
    throw "Unexpected EXE version: $version"
}

Write-Host "Validated version $version and $($expected.Count) embedded resources."
