$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$updater = Join-Path $projectRoot 'src\Update-ZZZIPv6Route.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ZZZIPv6Router-Fallback-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $settings = [ordered]@{
        targetHost = 'autopatchcn.juequling.com'
        probeUrl = 'https://autopatchcn.juequling.com/intentional-test-path'
        knownCandidates = @('::1')
        discoveryDomains = @()
        benchmarkBytes = 1
        benchmarkIntervalDays = 7
        connectTimeoutSeconds = 1
        maximumProbeSeconds = 1
    }
    $settings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'settings.json') -Encoding UTF8

    try {
        & $updater -DryRun -ForceBenchmark -DataDirectory $testRoot | Out-Null
        throw 'The updater unexpectedly accepted an invalid candidate.'
    }
    catch {
        if ($_.Exception.Message -eq 'The updater unexpectedly accepted an invalid candidate.') {
            throw
        }
    }

    $status = Get-Content -LiteralPath (Join-Path $testRoot 'status.json') -Raw | ConvertFrom-Json
    if ($status.state -ne 'FallbackToDefaultDNS' -or $null -ne $status.selectedIPv6 -or -not $status.dryRun) {
        throw 'The updater did not enter its safe default-DNS fallback state.'
    }

    Write-Host 'Validated safe fallback with an unreachable IPv6 candidate.'
}
finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot) -like 'ZZZIPv6Router-Fallback-*') {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
