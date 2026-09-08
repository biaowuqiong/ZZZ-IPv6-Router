# ZZZ IPv6 Router

ZZZ IPv6 Router selects and persists a validated IPv6 download route for the
mainland China PC launcher of Zenless Zone Zero. It is intended for Windows
networks where IPv4 downloads are heavily rate-limited while native IPv6 is
substantially faster.

This is not a proxy, VPN, or IPv4-to-IPv6 tunnel. It benchmarks candidate IPv6
CDN endpoints and updates one Windows hosts entry only after the original
download hostname passes TLS certificate validation and a valid HTTP Range
request. An existing VPN/TUN mode can remain enabled.

## Highlights

- Benchmarks validated IPv6 candidates on first run and picks the fastest one
- Runs a lightweight health check every 6 hours and re-benchmarks every 7 days
- Falls back to normal DNS automatically when no compatible IPv6 route remains
- Manages only `autopatchcn.juequling.com`
- Installs no driver, certificate, proxy, or third-party binary
- Includes a scoped uninstaller that preserves unrelated hosts-file changes

## Requirements

- Windows 10 or Windows 11
- Working native IPv6 connectivity
- Windows PowerShell 5.1 or PowerShell 7
- Administrator rights to edit the hosts file and create a scheduled task

## Install

Download or clone this repository, inspect the scripts, open PowerShell as
Administrator in the project directory, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

View the latest status:

```powershell
powershell -ExecutionPolicy Bypass -File .\Get-Status.ps1
```

Force a fresh benchmark:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Program Files\ZZZIPv6Router\Update-ZZZIPv6Route.ps1" -ForceBenchmark
```

## Uninstall

Run from the repository directory in an elevated PowerShell window:

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

The uninstaller removes only this project's marked hosts block, scheduled task,
and installed files. It does not overwrite the entire hosts file with an old
backup.

## Configuration and safety model

`config.default.json` is copied to
`C:\ProgramData\ZZZIPv6Router\settings.json` during installation. Reinstalling
keeps local settings unless `Install.ps1 -ReplaceSettings` is used.

For every candidate, the updater connects to the candidate IPv6 address while
retaining the official HTTPS hostname, verifies the certificate, and requests a
small byte range from a public official download object. Only candidates that
return a valid `206 Partial Content` response are eligible. If every candidate
fails, the managed mapping is removed and Windows returns to its normal DNS
route.

Actual speed depends on the ISP, campus or enterprise network, Wi-Fi, CDN load,
and local storage. The download hostname and object path may change in a future
launcher release.

Please follow your network's acceptable-use rules. This project changes an IPv6
route choice; it does not bypass authentication, billing, or access controls.

## Privacy

The tool uploads no logs, device identifiers, or account data. It contacts the
official game download object and, only when all static candidates fail, Google
Public DNS for public AAAA-record discovery.

## Disclaimer

This project is not affiliated with miHoYo, HoYoverse, or Zenless Zone Zero.
All referenced product names and trademarks belong to their respective owners.

## License

[MIT](LICENSE)
