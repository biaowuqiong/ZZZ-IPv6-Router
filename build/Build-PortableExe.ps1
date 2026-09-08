[CmdletBinding()]
param(
    [string]$Version = '0.2.1',
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot 'dist'
}
$compilerCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) {
    throw 'The .NET Framework C# compiler was not found. Build on Windows 10/11 with .NET Framework installed.'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputName = "ZZZ-IPv6-Router-v$Version-windows.exe"
$outputPath = Join-Path $OutputDirectory $outputName
$checksumPath = "$outputPath.sha256"

$compilerArguments = @(
    '/nologo',
    '/target:winexe',
    '/optimize+',
    '/platform:anycpu',
    ('/out:' + $outputPath),
    ('/win32manifest:' + (Join-Path $projectRoot 'gui\app.manifest')),
    '/reference:System.dll',
    '/reference:System.Core.dll',
    '/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll',
    '/reference:System.Web.Extensions.dll',
    ('/resource:' + (Join-Path $projectRoot 'Install.ps1') + ',ZZZIPv6Router.Install.ps1'),
    ('/resource:' + (Join-Path $projectRoot 'Uninstall.ps1') + ',ZZZIPv6Router.Uninstall.ps1'),
    ('/resource:' + (Join-Path $projectRoot 'Get-Status.ps1') + ',ZZZIPv6Router.GetStatus.ps1'),
    ('/resource:' + (Join-Path $projectRoot 'config.default.json') + ',ZZZIPv6Router.Config'),
    ('/resource:' + (Join-Path $projectRoot 'src\Update-ZZZIPv6Route.ps1') + ',ZZZIPv6Router.Update.ps1'),
    (Join-Path $projectRoot 'gui\Program.cs')
)

& $compiler @compilerArguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
    throw 'EXE compilation failed.'
}

$expectedResources = @(
    'ZZZIPv6Router.Install.ps1',
    'ZZZIPv6Router.Uninstall.ps1',
    'ZZZIPv6Router.GetStatus.ps1',
    'ZZZIPv6Router.Config',
    'ZZZIPv6Router.Update.ps1'
)
$assembly = [Reflection.Assembly]::ReflectionOnlyLoadFrom($outputPath)
$actualResources = @($assembly.GetManifestResourceNames())
foreach ($expected in $expectedResources) {
    if ($actualResources -notcontains $expected) {
        throw "Compiled EXE is missing embedded resource: $expected"
    }
}

$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($checksumPath, "$hash *$outputName`r`n", [Text.Encoding]::ASCII)

Get-Item -LiteralPath $outputPath, $checksumPath | Select-Object FullName, Length
