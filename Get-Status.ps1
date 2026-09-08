[CmdletBinding()]
param()

$statusPath = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'ZZZIPv6Router\status.json'
if (-not (Test-Path -LiteralPath $statusPath)) {
    throw 'No status file was found. Install the router or wait for its first scheduled run.'
}

$status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
$status | Format-List updatedAt, state, selectedIPv6, selectionReason, candidatesTested, hostsChanged, lastBenchmarkAt

if (@($status.measurements).Count -gt 0) {
    Write-Host 'Validated candidates:'
    $status.measurements | Format-Table address, speedMbps, bytesDownloaded -AutoSize
}
