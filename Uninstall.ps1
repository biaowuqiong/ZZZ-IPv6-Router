[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$KeepData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Please run PowerShell as Administrator, then run Uninstall.ps1 again.'
    }
}

Assert-Administrator

$taskName = 'ZZZ-IPv6-Router'
$installDirectory = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'ZZZIPv6Router'
$dataDirectory = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'ZZZIPv6Router'
$settingsPath = Join-Path $dataDirectory 'settings.json'
$originalTargetLinesPath = Join-Path $dataDirectory 'original-target-lines.txt'
$systemHosts = Join-Path ([Environment]::GetFolderPath('System')) 'drivers\etc\hosts'
$beginMarker = '# BEGIN ZZZ IPv6 Router'
$endMarker = '# END ZZZ IPv6 Router'
$targetHost = 'autopatchcn.juequling.com'

if (Test-Path -LiteralPath $settingsPath) {
    try {
        $targetHost = [string](Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).targetHost
    }
    catch {
        Write-Warning 'settings.json could not be read; the default target hostname will be used for cleanup.'
    }
}

if ($PSCmdlet.ShouldProcess($taskName, 'Unregister scheduled task')) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

$lines = [IO.File]::ReadAllLines($systemHosts)
$beginIndex = [Array]::IndexOf($lines, $beginMarker)
$endIndex = [Array]::IndexOf($lines, $endMarker)
$hasValidBlock = $beginIndex -ge 0 -and $endIndex -gt $beginIndex
$cleanLines = [Collections.Generic.List[string]]::new()

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($hasValidBlock -and $index -ge $beginIndex -and $index -le $endIndex) {
        continue
    }
    if ($lines[$index] -eq $beginMarker -or $lines[$index] -eq $endMarker) {
        continue
    }
    [void]$cleanLines.Add($lines[$index])
}

$activeTargetPattern = '(?i)(?:^|\s)' + [regex]::Escape($targetHost) + '(?:\s|$)'
$hasCurrentTargetEntry = @($cleanLines | Where-Object {
    (($_ -split '#', 2)[0]) -match $activeTargetPattern
}).Count -gt 0

if (-not $hasCurrentTargetEntry -and (Test-Path -LiteralPath $originalTargetLinesPath)) {
    foreach ($line in [IO.File]::ReadAllLines($originalTargetLinesPath)) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            [void]$cleanLines.Add($line)
        }
    }
}

if ($PSCmdlet.ShouldProcess($systemHosts, 'Remove managed IPv6 hosts block')) {
    [IO.File]::WriteAllLines($systemHosts, $cleanLines.ToArray(), [Text.UTF8Encoding]::new($false))
    Clear-DnsClientCache
}

if ($PSCmdlet.ShouldProcess($installDirectory, 'Remove installed program files')) {
    Remove-Item -LiteralPath $installDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not $KeepData -and $PSCmdlet.ShouldProcess($dataDirectory, 'Remove saved settings and status')) {
    Remove-Item -LiteralPath $dataDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'ZZZ IPv6 Router uninstalled. Windows is using its normal DNS route again.'
