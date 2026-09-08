# Security policy

## What the project changes

The installer creates a scheduled task running as `SYSTEM`, copies one PowerShell
script under `Program Files`, stores settings and status under `ProgramData`, and
manages one clearly marked block in the Windows hosts file.

The updater accepts an IPv6 endpoint only after the original ZZZ CDN hostname
passes certificate verification and returns a valid HTTP partial-content response.
It does not install a certificate, proxy, driver, VPN, or background network service.

## Reporting a vulnerability

Please open a GitHub security advisory instead of a public issue when a report
contains an exploitable vulnerability or sensitive details.
