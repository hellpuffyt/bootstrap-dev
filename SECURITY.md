# Security policy

## Supported versions

Only the latest commit on `main` is supported.

## Reporting a vulnerability

Please report security issues privately through GitHub:
https://github.com/hellpuffyt/bootstrap-dev/security/advisories/new

Do not open a public issue for a vulnerability.

## Scope

bootstrap-dev installs packages and edits dotfiles on the machine it runs on,
using `sudo` only for the package-manager call. In scope: anything that makes
it change more than its steps declare, run during `--dry-run`, lose or corrupt
user data in edited files, escalate privileges beyond the package-manager
call, or fetch and execute unverified content.
