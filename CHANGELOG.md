# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] - 2026-08-30

### Added

- Step framework (`lib/step.sh`) with `check` / `apply` / `verify` lifecycle,
  loud failure on a failing `verify`, and rollback hints on failure.
- Resumable runs via a plain-text state file (`lib/state.sh`), `--resume` and
  `--force <step>`.
- `--dry-run` that prints planned changes and touches nothing on disk.
- Idempotent managed-block dotfile editor (`lib/editfile.sh`): repeated runs
  leave exactly one block.
- Package manager abstraction (`lib/pkg.sh`) detecting apt, dnf, pacman, and
  brew, failing clearly on unsupported platforms.
- Preflight checks (`lib/preflight.sh`): disk space, network reachability,
  sudo availability, conflicting installs.
- Structured logging with a run summary (`lib/log.sh`).
- Steps: `base-packages`, `web-packages`, `data-packages`, `ops-packages`,
  `git-defaults`, `shell-profile`.
- Profiles: `minimal`, `web`, `data`, `ops`.
- bats-core test suite covering the framework, package manager stubbing, and
  full-CLI integration behavior.
- CI: bats, shellcheck, shfmt, and a `--dry-run` smoke job on ubuntu and macos.
