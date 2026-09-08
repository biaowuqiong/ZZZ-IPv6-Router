# Contributing

Issues and pull requests are welcome. Please do not include account information,
launcher logs containing tokens, subscription URLs, VPN configuration, or other
private network data.

When proposing a new candidate IPv6 endpoint, include only reproducible public
evidence:

- the candidate IPv6 address and how its public AAAA record was discovered;
- confirmation that the original target hostname passes TLS verification;
- confirmation that the probe returns HTTP `206 Partial Content`;
- an approximate benchmark result and network region, without a precise address.

Before submitting a pull request, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Test-ScriptSyntax.ps1
```

Keep hosts-file changes restricted to the project's marked block, and preserve
the default-DNS fallback when no compatible candidate is available.
