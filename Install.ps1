[CmdletBinding()]
param(
    [switch]$ReplaceSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Please run PowerShell as Administrator, then run Install.ps1 again.'
    }
}

function Test-ActiveTargetEntry {
    param(
        [string]$Line,
        [Parameter(Mandatory)][string]$TargetHost
    )

    $activePart = ($Line -split '#', 2)[0]
    $pattern = '(?i)(?:^|\s)' + [regex]::Escape($TargetHost) + '(?:\s|$)'
    return $activePart -match $pattern
}

Assert-Administrator

$sourceUpdater = Join-Path $PSScriptRoot 'src\Update-ZZZIPv6Route.ps1'
$sourceSettings = Join-Path $PSScriptRoot 'config.default.json'
$installDirectory = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'ZZZIPv6Router'
$dataDirectory = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'ZZZIPv6Router'
$installedUpdater = Join-Path $installDirectory 'Update-ZZZIPv6Route.ps1'
$settingsPath = Join-Path $dataDirectory 'settings.json'
$originalHostsPath = Join-Path $dataDirectory 'hosts.original'
$originalTargetLinesPath = Join-Path $dataDirectory 'original-target-lines.txt'
$systemHosts = Join-Path ([Environment]::GetFolderPath('System')) 'drivers\etc\hosts'
$taskName = 'ZZZ-IPv6-Router'
$legacyTaskName = 'Codex-ZZZ-IPv6-Router'
$managedMarkerPairs = @(
    [pscustomobject]@{ Begin = '# BEGIN ZZZ IPv6 Router'; End = '# END ZZZ IPv6 Router' },
    [pscustomobject]@{ Begin = '# BEGIN Codex ZZZ IPv6 Router'; End = '# END Codex ZZZ IPv6 Router' }
)

if (-not (Test-Path -LiteralPath $sourceUpdater) -or -not (Test-Path -LiteralPath $sourceSettings)) {
    throw 'Required project files are missing. Keep the repository folder structure intact.'
}

New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null

if (-not (Test-Path -LiteralPath $originalHostsPath)) {
    Copy-Item -LiteralPath $systemHosts -Destination $originalHostsPath
}

if (-not (Test-Path -LiteralPath $originalTargetLinesPath)) {
    $targetHost = [string](Get-Content -LiteralPath $sourceSettings -Raw | ConvertFrom-Json).targetHost
    $hostLines = [IO.File]::ReadAllLines($systemHosts)
    $managedIndexes = [Collections.Generic.HashSet[int]]::new()
    foreach ($pair in $managedMarkerPairs) {
        $beginIndex = [Array]::IndexOf($hostLines, [string]$pair.Begin)
        $endIndex = [Array]::IndexOf($hostLines, [string]$pair.End)
        if ($beginIndex -ge 0 -and $endIndex -gt $beginIndex) {
            for ($index = $beginIndex; $index -le $endIndex; $index++) {
                [void]$managedIndexes.Add($index)
            }
        }
    }
    $originalTargetLines = @(
        for ($index = 0; $index -lt $hostLines.Count; $index++) {
            if (-not $managedIndexes.Contains($index) -and
                (Test-ActiveTargetEntry -Line $hostLines[$index] -TargetHost $targetHost)) {
                $hostLines[$index]
            }
        }
    )
    [IO.File]::WriteAllLines($originalTargetLinesPath, $originalTargetLines, [Text.UTF8Encoding]::new($false))
}

Copy-Item -LiteralPath $sourceUpdater -Destination $installedUpdater -Force
if ($ReplaceSettings -or -not (Test-Path -LiteralPath $settingsPath)) {
    Copy-Item -LiteralPath $sourceSettings -Destination $settingsPath -Force
}

$powerShellExe = Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $installedUpdater + '"'
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $arguments
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$periodicTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
    -RepetitionInterval (New-TimeSpan -Hours 6) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$task = New-ScheduledTask -Action $action -Trigger @($logonTrigger, $periodicTrigger) `
    -Principal $principal -Settings $settings `
    -Description 'Selects a TLS-validated IPv6 CDN route for Zenless Zone Zero CN downloads.'
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

# Migrate the private prototype task, if present. Its data backup is retained.
Unregister-ScheduledTask -TaskName $legacyTaskName -Confirm:$false -ErrorAction SilentlyContinue

try {
    & $installedUpdater -ForceBenchmark
}
catch {
    Write-Warning $_.Exception.Message
    Write-Warning 'Installation completed, but no compatible IPv6 CDN is currently available. The scheduled task will retry later.'
}

Write-Host 'ZZZ IPv6 Router installed successfully.'
Write-Host "Settings: $settingsPath"
Write-Host "Status:   $(Join-Path $dataDirectory 'status.json')"
