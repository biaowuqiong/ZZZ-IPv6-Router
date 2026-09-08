[CmdletBinding()]
param(
    [switch]$ForceBenchmark,
    [switch]$DryRun,
    [string]$DataDirectory = (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'ZZZIPv6Router')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$systemHosts = Join-Path ([Environment]::GetFolderPath('System')) 'drivers\etc\hosts'
$settingsPath = Join-Path $DataDirectory 'settings.json'
$statusPath = Join-Path $DataDirectory 'status.json'
$previousHostsPath = Join-Path $DataDirectory 'hosts.previous'
$nextHostsPath = Join-Path $DataDirectory 'hosts.next'
$beginMarker = '# BEGIN ZZZ IPv6 Router'
$endMarker = '# END ZZZ IPv6 Router'
$legacyBeginMarker = '# BEGIN Codex ZZZ IPv6 Router'
$legacyEndMarker = '# END Codex ZZZ IPv6 Router'

New-Item -ItemType Directory -Path $DataDirectory -Force | Out-Null

if (-not (Test-Path -LiteralPath $settingsPath)) {
    throw "Settings file not found: $settingsPath"
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$targetHost = [string]$settings.targetHost
$probeUrl = [string]$settings.probeUrl
$benchmarkBytes = [int64]$settings.benchmarkBytes
$benchmarkIntervalDays = [double]$settings.benchmarkIntervalDays
$connectTimeoutSeconds = [int]$settings.connectTimeoutSeconds
$maximumProbeSeconds = [int]$settings.maximumProbeSeconds
$curl = Get-Command 'curl.exe' -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($targetHost) -or [string]::IsNullOrWhiteSpace($probeUrl)) {
    throw 'targetHost and probeUrl must be set in settings.json.'
}

if ($benchmarkBytes -lt 1 -or $benchmarkBytes -gt 16777216) {
    throw 'benchmarkBytes must be between 1 byte and 16 MiB.'
}

function Test-IsIPv6Address {
    param([Parameter(Mandatory)][string]$Address)

    $parsed = $null
    return [Net.IPAddress]::TryParse($Address, [ref]$parsed) -and
        $parsed.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6
}

function Invoke-CandidateProbe {
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][int64]$Bytes
    )

    if (-not (Test-IsIPv6Address -Address $Address)) {
        return $null
    }

    $lastByte = $Bytes - 1
    $resolve = "${targetHost}:443:[${Address}]"
    $writeOut = '%{http_code}|%{size_download}|%{speed_download}|%{ssl_verify_result}'
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell can promote native stderr to a terminating error when
        # ErrorActionPreference is Stop. A failed candidate must remain a normal
        # validation result so the next candidate and DNS fallback can run.
        $ErrorActionPreference = 'Continue'
        $output = & $curl.Source -q -sS --noproxy '*' --proto '=https' --tlsv1.2 `
            --range "0-$lastByte" --connect-timeout $connectTimeoutSeconds `
            --max-time $maximumProbeSeconds --max-filesize $Bytes -o NUL `
            -w $writeOut --resolve $resolve $probeUrl 2>$null
        $curlExit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($curlExit -ne 0) {
        return $null
    }

    $metricLine = @($output | ForEach-Object { [string]$_ } | Where-Object {
        $_ -match '^\d{3}\|[0-9.]+\|[0-9.]+\|\d+$'
    } | Select-Object -Last 1)

    if ($metricLine.Count -ne 1) {
        return $null
    }

    $parts = $metricLine[0] -split '\|'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $downloaded = [double]::Parse($parts[1], $culture)
    $speed = [double]::Parse($parts[2], $culture)

    if ($parts[0] -ne '206' -or $downloaded -lt 1 -or $parts[3] -ne '0') {
        return $null
    }

    [pscustomobject]@{
        address = $Address
        speedBytesPerSecond = [math]::Round($speed, 0)
        speedMbps = [math]::Round(($speed * 8 / 1000000), 2)
        bytesDownloaded = [int64]$downloaded
    }
}

function Add-UniqueIPv6Candidate {
    param(
        [Collections.Generic.List[string]]$List,
        [Parameter(Mandatory)][string]$Address
    )

    if ((Test-IsIPv6Address -Address $Address) -and -not $List.Contains($Address)) {
        [void]$List.Add($Address)
    }
}

function Find-DiscoveredCandidates {
    param([Collections.Generic.List[string]]$CandidateList)

    foreach ($domain in @($settings.discoveryDomains)) {
        try {
            $uri = 'https://dns.google/resolve?name=' + [Uri]::EscapeDataString([string]$domain) + '&type=AAAA'
            $answer = Invoke-RestMethod -Uri $uri -TimeoutSec 10
            foreach ($record in @($answer.Answer)) {
                if ($null -ne $record -and $record.type -eq 28) {
                    Add-UniqueIPv6Candidate -List $CandidateList -Address ([string]$record.data)
                }
            }
        }
        catch {
            Write-Verbose "Could not query AAAA records for $domain."
        }
    }
}

function Remove-ManagedRoute {
    param(
        [string[]]$Lines,
        [switch]$RemoveAllTargetEntries
    )

    $markerPairs = @(
        [pscustomobject]@{ Begin = $beginMarker; End = $endMarker },
        [pscustomobject]@{ Begin = $legacyBeginMarker; End = $legacyEndMarker }
    )
    $managedIndexes = [Collections.Generic.HashSet[int]]::new()
    foreach ($pair in $markerPairs) {
        $beginIndex = [Array]::IndexOf($Lines, [string]$pair.Begin)
        $endIndex = [Array]::IndexOf($Lines, [string]$pair.End)
        if ($beginIndex -ge 0 -and $endIndex -gt $beginIndex) {
            for ($index = $beginIndex; $index -le $endIndex; $index++) {
                [void]$managedIndexes.Add($index)
            }
        }
    }
    $knownMarkers = @($beginMarker, $endMarker, $legacyBeginMarker, $legacyEndMarker)
    $result = [Collections.Generic.List[string]]::new()

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        if ($managedIndexes.Contains($index)) {
            continue
        }
        if ($knownMarkers -contains $line) {
            continue
        }

        if ($RemoveAllTargetEntries) {
            $activePart = ($line -split '#', 2)[0]
            $targetPattern = '(?i)(?:^|\s)' + [regex]::Escape($targetHost) + '(?:\s|$)'
            if ($activePart -match $targetPattern) {
                continue
            }
        }

        [void]$result.Add($line)
    }

    return $result.ToArray()
}

function Set-HostsLines {
    param([string[]]$Lines)

    [IO.File]::WriteAllLines($nextHostsPath, $Lines, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $systemHosts -Destination $previousHostsPath -Force
    Copy-Item -LiteralPath $nextHostsPath -Destination $systemHosts -Force
    Remove-Item -LiteralPath $nextHostsPath -Force -ErrorAction SilentlyContinue
    Clear-DnsClientCache
}

$previousStatus = $null
if (Test-Path -LiteralPath $statusPath) {
    try {
        $previousStatus = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Verbose 'The previous status file could not be read; a fresh benchmark will run.'
    }
}

$now = Get-Date
$previousAddress = $null
$lastBenchmarkAt = $null
if ($null -ne $previousStatus) {
    if ($null -ne $previousStatus.PSObject.Properties['selectedIPv6']) {
        $previousAddress = [string]$previousStatus.selectedIPv6
    }
    if ($null -ne $previousStatus.PSObject.Properties['lastBenchmarkAt']) {
        $parsedDate = [datetimeoffset]::MinValue
        if ([datetimeoffset]::TryParse([string]$previousStatus.lastBenchmarkAt, [ref]$parsedDate)) {
            $lastBenchmarkAt = $parsedDate
        }
    }
}

$benchmarkDue = $ForceBenchmark -or $null -eq $lastBenchmarkAt -or
    $now -ge $lastBenchmarkAt.LocalDateTime.AddDays($benchmarkIntervalDays)
$selectedProbe = $null
$selectionReason = $null
$measurements = [Collections.Generic.List[object]]::new()
$tested = 0

if (-not $benchmarkDue -and -not [string]::IsNullOrWhiteSpace($previousAddress)) {
    $tested++
    $selectedProbe = Invoke-CandidateProbe -Address $previousAddress -Bytes 1
    if ($null -ne $selectedProbe) {
        $selectionReason = 'CachedCandidateStillHealthy'
        [void]$measurements.Add($selectedProbe)
    }
}

$benchmarkRan = $null -eq $selectedProbe
if ($benchmarkRan) {
    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($candidate in @($settings.knownCandidates)) {
        Add-UniqueIPv6Candidate -List $candidates -Address ([string]$candidate)
    }

    foreach ($candidate in $candidates) {
        $tested++
        $probe = Invoke-CandidateProbe -Address $candidate -Bytes $benchmarkBytes
        if ($null -ne $probe) {
            [void]$measurements.Add($probe)
        }
    }

    if ($measurements.Count -eq 0) {
        $knownCount = $candidates.Count
        Find-DiscoveredCandidates -CandidateList $candidates
        foreach ($candidate in @($candidates | Select-Object -Skip $knownCount)) {
            $tested++
            $probe = Invoke-CandidateProbe -Address $candidate -Bytes $benchmarkBytes
            if ($null -ne $probe) {
                [void]$measurements.Add($probe)
            }
        }
    }

    $selectedProbe = $measurements | Sort-Object speedBytesPerSecond -Descending | Select-Object -First 1
    if ($null -ne $selectedProbe) {
        $selectionReason = 'FastestValidatedCandidate'
    }
    $lastBenchmarkAt = [datetimeoffset]$now
}

$hostsLines = [IO.File]::ReadAllLines($systemHosts)
$changed = $false
$state = 'FallbackToDefaultDNS'
$selectedAddress = $null

if ($null -ne $selectedProbe) {
    $selectedAddress = [string]$selectedProbe.address
    $cleanLines = [Collections.Generic.List[string]]::new()
    foreach ($line in @(Remove-ManagedRoute -Lines $hostsLines -RemoveAllTargetEntries)) {
        [void]$cleanLines.Add($line)
    }
    while ($cleanLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($cleanLines[$cleanLines.Count - 1])) {
        $cleanLines.RemoveAt($cleanLines.Count - 1)
    }
    [void]$cleanLines.Add('')
    [void]$cleanLines.Add($beginMarker)
    [void]$cleanLines.Add("$selectedAddress $targetHost")
    [void]$cleanLines.Add($endMarker)
    $desiredLines = $cleanLines.ToArray()
    $state = 'IPv6Ready'
}
else {
    $desiredLines = @(Remove-ManagedRoute -Lines $hostsLines)
}

if (($hostsLines -join "`n") -ne ($desiredLines -join "`n")) {
    $changed = $true
    if (-not $DryRun) {
        Set-HostsLines -Lines $desiredLines
    }
}

$status = [pscustomobject]@{
    updatedAt = ([datetimeoffset]$now).ToString('o')
    state = $state
    selectedIPv6 = $selectedAddress
    selectionReason = $selectionReason
    candidatesTested = $tested
    hostsChanged = $changed -and -not $DryRun
    changeNeeded = $changed
    dryRun = [bool]$DryRun
    lastBenchmarkAt = if ($null -ne $lastBenchmarkAt) { $lastBenchmarkAt.ToString('o') } else { $null }
    measurements = @($measurements)
}
$status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statusPath -Encoding UTF8
$status

if ($null -eq $selectedProbe) {
    throw 'No compatible IPv6 CDN candidate passed TLS and HTTP range validation. The managed hosts entry was removed so Windows can use its default DNS route.'
}
