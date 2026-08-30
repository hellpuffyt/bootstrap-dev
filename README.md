# bootstrap-dev

Bootstrap a development machine reproducibly — verifying each step instead
of assuming it worked.

## What

`bootstrap-dev` is a shell tool that sets up a development machine: core
command line tools, language runtimes for a given profile (web, data, ops),
sane git defaults, and a managed block of shell configuration. It is driven
by `bootstrap.sh` and a small library in `lib/`, with the actual work broken
into independent, declarative steps in `steps/`.

## Why

Most bootstrap scripts are written once, run once, and rot:

- They `apt-get install` something and never check the binary actually
  appeared.
- They append a line to `.bashrc` on every run, so after a year you have the
  same `export PATH=...` line fifteen times.
- They fail halfway through and leave the machine in a state nobody can
  reason about, with no record of what happened.

`bootstrap-dev` is built around three guarantees instead:

- **Idempotent** — running it twice does nothing the second time.
- **Verified** — every step proves it worked; a step that silently fails to
  take effect fails the run loudly instead of continuing.
- **Resumable** — an interrupted run can be picked back up without redoing
  finished work.

## How the step framework works

A step is a shell file in `steps/` that declares up to five functions for a
step id `foo`:

| Function                    | Required | Purpose                                             |
|------------------------------|:--------:|------------------------------------------------------|
| `step_foo_check`             | yes      | Exit 0 if the step's effect is already in place.     |
| `step_foo_apply`             | yes      | Make the change. Must be safe to run more than once. |
| `step_foo_verify`            | yes      | Exit 0 only if the change actually took effect.      |
| `step_foo_describe`          | no       | One-line description shown in the log.               |
| `step_foo_rollback_hint`     | no       | Printed on failure: how to undo this step by hand.   |

`run_step` (in `lib/step.sh`) drives each step through:

1. **Resume skip** — if `--resume` is set and the step is recorded as done
   in the state file, skip immediately without calling anything.
2. **Check** — if `step_foo_check` passes, the step is already satisfied;
   record it done and move on.
3. **Apply** — otherwise call `step_foo_apply`. In `--dry-run` mode, steps
   are called with `DRY_RUN=1` and expected to only print what they would
   do.
4. **Verify** — call `step_foo_verify`. If it fails, the step (and the run)
   fails loudly, and the step's rollback hint is printed. A step that
   "applies successfully" but doesn't verify is treated as a failure, not a
   success — that's the whole point of separating the two.
5. **Record** — on success, the step id is appended to the state file.

A run walks the step ids listed in a profile file (`profiles/*.conf`) in
order, stopping at the first failure, then prints a changed/skipped/failed
summary.

## Features

- Step framework with `check`/`apply`/`verify` and rollback hints.
- Idempotent managed-block dotfile editor (`lib/editfile.sh`): a block
  delimited by `# >>> bootstrap-dev:<id> >>>` / `# <<< bootstrap-dev:<id> <<<`
  markers is replaced in place, not appended — ten runs leave one block.
  See `steps/shell-profile.sh` for a working example.
- Resumable runs via a plain state file (`~/.bootstrap-dev/state` by
  default): `--resume` skips completed steps, `--force <step>` re-runs one.
  See `lib/state.sh`.
  `--dry-run` prints exactly what would change and creates no state file,
  no log directory changes beyond the log itself, and no dotfile edits.
- Package manager abstraction (`lib/pkg.sh`): detects `apt`, `dnf`, `pacman`,
  or `brew` and dispatches to it; fails with a clear error on an unsupported
  platform rather than guessing.
- Profiles (`profiles/*.conf`): a profile is a plain list of step ids,
  selected with `--profile`.
- Preflight checks (`lib/preflight.sh`) that run before anything changes:
  disk space, network reachability, sudo availability, and any
  caller-declared conflicting binaries.
- Structured logging to a file (`lib/log.sh`) plus a colorized console
  summary of changed/skipped/failed steps.

## Profiles

| Profile   | Steps                                                        |
|-----------|---------------------------------------------------------------|
| `minimal` | `base-packages`, `git-defaults`, `shell-profile`              |
| `web`     | `base-packages`, `web-packages`, `git-defaults`, `shell-profile` |
| `data`    | `base-packages`, `data-packages`, `git-defaults`, `shell-profile` |
| `ops`     | `base-packages`, `ops-packages`, `git-defaults`, `shell-profile` |

List them at any time with `--list-profiles`; list every known step with
`--list-steps`.

## Installation

```sh
git clone https://example.com/bootstrap-dev.git
cd bootstrap-dev
chmod +x bootstrap.sh
```

No install step beyond cloning — `bootstrap.sh` sources everything it needs
from `lib/` and `steps/` relative to its own location.

## Usage

```sh
# See what a profile would do without changing anything.
./bootstrap.sh --profile web --dry-run

# Actually run it.
./bootstrap.sh --profile web

# An interrupted run can be resumed; completed steps are skipped.
./bootstrap.sh --profile web --resume

# Re-run one step even though it is marked done.
./bootstrap.sh --profile web --force git-defaults

# List available steps and profiles.
./bootstrap.sh --list-steps
./bootstrap.sh --list-profiles
```

```
Usage: bootstrap.sh [options]

Options:
  --profile <name>     Profile to run (default: minimal). See profiles/*.conf.
  --dry-run            Print what would change; touch nothing.
  --resume             Skip steps already recorded as done in the state file.
  --force <step>       Re-run a single step even if it is marked done.
  --state-file <path>  Override the state file location.
  --log-file <path>    Override the log file location.
  --skip-preflight     Skip preflight checks (for local testing only).
  --list-steps         List all known steps and exit.
  --list-profiles      List all known profiles and exit.
  -h, --help           Show this help.
```

Exit codes: `0` success, `1` a step failed, `2` preflight failed, `3` a bad
argument or unknown profile.

## Writing a step

Create `steps/my-step.sh`:

```sh
#!/usr/bin/env bash
# steps/my-step.sh - one-line summary

step_my-step_describe() {
	printf 'what this step does, in one line'
}

step_my-step_check() {
	# Exit 0 if already done.
	command -v mytool >/dev/null 2>&1
}

step_my-step_apply() {
	if [ "${DRY_RUN:-0}" = "1" ]; then
		log_info "[dry-run] would install mytool"
		return 0
	fi
	pkg_detect || return 1
	pkg_install mytool
}

step_my-step_verify() {
	step_my-step_check
}

step_my-step_rollback_hint() {
	printf 'remove it with your package manager, e.g. "apt-get remove mytool"'
}
```

Then add `my-step` to a profile file in `profiles/`. `bootstrap.sh` sources
every file in `steps/` automatically, so no registration step is needed.

Rules for a good step:

- `apply` must be idempotent — running it when `check` already passed should
  never be attempted (the framework won't call it), but running `apply`
  twice back to back must still be safe, since `--force` can trigger that.
- `verify` must actually re-check reality, not just return the exit code of
  `apply`. If `apply` can silently no-op without effect, `verify` is what
  catches it.
- Respect `DRY_RUN=1`: print what would happen, change nothing.
- If you edit a dotfile, use `managed_block_apply` from `lib/editfile.sh`
  rather than `>>` appending.

## Safety and idempotency

- Every step's `apply` is expected to be idempotent; the test suite enforces
  this for the shipped steps (apply twice, assert the second run is a
  no-op).
- Dotfile edits go through managed blocks, never raw appends: the marker
  comments make the boundary of what `bootstrap-dev` owns explicit and
  removable.
- A failing `verify` fails the whole run immediately rather than continuing
  past a step that silently didn't take effect.
- `--dry-run` never calls a step's real `apply` path — steps receive
  `DRY_RUN=1` and are expected to only print.

## Examples

```sh
# Preview a full ops setup.
./bootstrap.sh --profile ops --dry-run

# Run it for real, resuming later if interrupted.
./bootstrap.sh --profile ops
# ...machine reboots partway through...
./bootstrap.sh --profile ops --resume

# Something about the shell profile step needs redoing after editing steps/shell-profile.sh.
./bootstrap.sh --profile ops --force shell-profile
```

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core). The package
manager is always stubbed — a fake `apt-get`/`brew`/etc. is placed ahead of
`PATH` in `tests/test_helper.bash`'s `stub_pkg_manager`, so the test suite
never installs anything real. `git` and `curl` are stubbed unconditionally
for the same reason: the suite does not depend on what happens to be
installed on the machine running it.

```sh
bats tests/

# or, with nothing installed locally:
docker run --rm -v "$PWD:/w" -w /w bats/bats:latest tests/
```

Coverage includes: the check/apply/verify lifecycle (success, failing apply,
failing verify), idempotency (apply twice → one change), the managed-block
editor (ten runs → one block), state file resume and force, dry-run touching
nothing, package manager detection and dispatch with a stubbed `command -v`,
and preflight checks including their failure paths.

## Security

- `bootstrap-dev` never pipes a fetched script straight into a shell
  (`curl ... | bash`) from an unpinned URL. If a step needs to fetch
  something, the rule is: pin the URL to a specific version and verify a
  checksum before using the downloaded artifact — the same policy this
  repository's own CI applies when installing `shfmt`.
- All destructive actions require an explicit run (`--dry-run` is the
  default-safe way to inspect a profile first).
- Elevated privileges are only used when required (`lib/pkg.sh` runs as the
  current user unless root, using `sudo` only for the actual package manager
  invocation) — never blanket `sudo` for the whole script.
- `set -euo pipefail` throughout, all variable expansions quoted, no `eval`
  of untrusted input anywhere in the codebase.

## License

MIT, see [LICENSE](LICENSE).
