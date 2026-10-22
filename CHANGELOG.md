# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Fixed

- The managed-block editor replaced the dotfile with a new file via `mv`,
  which turned a symlinked `~/.bashrc` (e.g. from a dotfiles manager) into a
  regular file and reset its mode to 0600. It now rewrites the file in place.
- With the block's end marker missing, every line after the start marker was
  treated as block content and deleted. Damaged markers (missing, duplicated
  or out-of-order) now fail the step and leave the file untouched
  (`managed_block_apply` returns 2).
- `--force shell-profile` (a README example) failed whenever the block was
  already up to date, because the editor's "unchanged" status was treated as
  an apply failure.
- `--dry-run --force <step>` removed the step from the state file.
- On a fresh Debian/Ubuntu system every package install failed with "Unable
  to locate package": the `apt` backend now runs `apt-get update` once per
  run (non-interactively) before installing.
- A missing option value exited 1 instead of the documented 3; profile names
  are validated (letters, digits, `-`, `_`); `--force` with a step that is not
  in the profile is an error (3) instead of a silent no-op. All are rejected
  before the log or state file is written.
- README: the clone URL pointed at `example.com`.

### Added

- Regression tests for each fix; `SECURITY.md`, `.editorconfig`,
  `docs/PRODUCTION_READINESS.md`; CI `permissions: contents: read`; README
  environment-variable table and limitations.

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
