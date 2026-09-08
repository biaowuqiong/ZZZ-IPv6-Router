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

function ConvertTo-NormalizedText {
    param([Parameter(Mandatory)][string]$Text)

    if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xfeff) {
        $Text = $Text.Substring(1)
    }
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
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
            $embeddedText = [Text.Encoding]::UTF8.GetString($memory.ToArray())
        }
        finally {
            $memory.Dispose()
        }
    }
    finally {
        $resourceStream.Dispose()
    }

    $sourceText = [IO.File]::ReadAllText($entry.Value, [Text.Encoding]::UTF8)
    if ((ConvertTo-NormalizedText $embeddedText) -cne (ConvertTo-NormalizedText $sourceText)) {
        throw "Embedded resource differs from source: $($entry.Key)"
    }
}

$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedExe).FileVersion
if ($version -ne '0.2.1.0') {
    throw "Unexpected EXE version: $version"
}

Write-Host "Validated version $version and $($expected.Count) embedded resources."
