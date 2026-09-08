$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scripts = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse
$failed = $false

foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failed = $true
        foreach ($parseError in $errors) {
            Write-Error "$($script.FullName): $($parseError.Message)"
        }
    }
}

if ($failed) {
    exit 1
}

Write-Host "Parsed $($scripts.Count) PowerShell scripts successfully."
