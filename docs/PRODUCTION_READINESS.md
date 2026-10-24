# Production readiness — bootstrap-dev

Audit of the `audit/production-readiness` branch. Evidence only; the
classification at the end is a proposal for the maintainer to confirm.

- Tested commit: `4295456c86420038cdba5a902f8e14c7ef032df5` (this file was
  added in the next commit and changes no code)
- Date: 2026-10-22
- Host: macOS 27 (Apple Silicon). Tools: ShellCheck 0.11.0, bats 1.14.0
  (inside the `bats/bats:latest` container), shfmt v3.9.0 (the version CI
  pins, inside `mvdan/shfmt:v3.9.0`), Docker 29.5.2.

## Safety rule followed

The tool installs packages and edits dotfiles, so it was **never run in apply
mode on the audit host**. On the host, only `--dry-run`, `--list-*` and
`--help` were run, with the HOME listing and checksums of `~/.bashrc`,
`~/.zshrc` and `~/.gitconfig` compared before and after (unchanged). The bats
suite and every real run happened in throwaway `docker run --rm` containers
with the repository mounted read-only.

## Scope

A bash bootstrapper: profiles list steps; each step has
`check`/`apply`/`verify` (+ optional describe/rollback hint); `run_step`
drives resume-skip → check → apply → verify → record. Libraries: package
manager abstraction (apt/dnf/pacman/brew), managed-block dotfile editor,
state file, preflight checks, logging. Six steps, four profiles.

## Clean-clone verification

Fresh clone of the branch into an empty scratch directory, README followed
literally (apply-mode commands are replaced by `--dry-run` on the host and run
for real only in containers, below):

| Command | Exit | Result |
|---|---|---|
| `chmod +x bootstrap.sh` | 0 | |
| `./bootstrap.sh --profile web --dry-run` (scratch state/log paths) | 0 | plan printed; no state file; HOME unchanged |
| `./bootstrap.sh --list-steps`, `--list-profiles`, `--help` | 0 | 6 steps, 4 profiles |
| `docker run --rm -v "$PWD:/w:ro" -w /w bats/bats:latest tests/` | 0 | 69 passed, 0 failed, 0 skipped |

## Real runs in throwaway containers (after the fixes)

`docker run --rm` as root, repository mounted read-only and copied inside,
`BOOTSTRAP_SKIP_NETWORK_CHECK=1` (see bug 7):

| Scenario | `ubuntu:24.04`, profile `ops` | `fedora:41`, profile `minimal` |
|---|---|---|
| `--dry-run` on a fresh system | exit 0, no state file, no `~/.bashrc` | same |
| run 1 (fresh system, no manual `apt-get update`) | exit 0, changed 4 | exit 0, changed 3 |
| run 2 (idempotency) | exit 0, changed 0, skipped 4, one managed block | exit 0, changed 0, skipped 3, one block |
| `--force shell-profile` (README example) | exit 0 | exit 0 |
| symlinked `~/.bashrc`, mode 644, block edited | stays a symlink, mode 644 | same |
| block with missing end marker + user lines | exit 1, both user lines kept | same |
| run interrupted at `shell-profile`, then `--resume` | state had the earlier steps; resume exit 0, changed 1, skipped the rest | same |

On the macOS host, `--dry-run` for all four profiles: exit 0, HOME unchanged.

## Commands executed (working clone)

| Command | Exit | Outcome |
|---|---|---|
| `shellcheck bootstrap.sh lib/*.sh steps/*.sh` (as CI) | 0 | clean, before and after |
| `shfmt -d .` (v3.9.0 container) | 0 | clean, before and after |
| bats in container, baseline `35f1d05` | 0 | 58 passed, 0 failed |
| baseline container probes (`ubuntu:24.04`) | — | bugs 1-6 reproduced (see below) |
| new tests against baseline sources (`git stash` of `bootstrap.sh lib steps`) | 1 | 10 of the new tests fail |
| bats in container, after | 0 | 69 passed, 0 failed, 0 skipped |
| history secret scan (`git grep` over every commit) | — | no hits |

No dependency audit applies: the tool has no package dependencies (it calls
the system package manager and coreutils). CI installs `shfmt` with a pinned
`go install …@v3.9.0`.

## Bugs found and fixed

| # | Bug (reproduced how) | Fix | Regression test |
|---|---|---|---|
| 1 | **Data loss**: with the end marker missing, every line after the start marker was deleted (container: 2 user lines → 0). | Exactly one start then one end marker required; otherwise the file is left untouched and the step fails (`managed_block_apply` returns 2). | `editfile.bats`: missing end marker, duplicate/out-of-order markers; integration: damaged block keeps user lines |
| 2 | The dotfile was replaced via `mv` of a `mktemp` file: a symlinked `~/.bashrc` became a regular file, and mode 644 became 600 (container). | Rewrite in place. | `editfile.bats`: symlink kept, permissions kept |
| 3 | `--force shell-profile` (README example) failed whenever the block was already current: "unchanged" (1) was treated as an apply failure (container, exit 1). | The step accepts 0/1, fails on 2. | integration: `--force shell-profile on an up-to-date block succeeds` |
| 4 | `--dry-run --force <step>` removed the step from the state file (container: state diff). | No state writes in dry-run. | `step.bats`, integration |
| 5 | Fresh Debian/Ubuntu: `apt-get install` failed with "Unable to locate package"; no `apt-get update` (container, exit 1). | `apt-get update` once per run, noninteractive. | `pkg.bats`: update once, before first install |
| 6 | A missing option value exited 1, not the documented 3; `--profile ../x` reached outside `profiles/`; `--force no-such-step` silently did nothing (exit 0). | Validated before the log/state are written; exit 3. | integration: `bad arguments exit 3 before anything is written` |
| 7 | Preflight network check downloaded the whole github.com page with `--max-time 5`; on a slow link it reported "unreachable" (exit 2): reproduced on the host and in the container. | HEAD request, `--connect-timeout 5 --max-time 15`. | `preflight.bats`: HEAD with connect timeout |
| 8 | README clone URL was `example.com`. | Real URL. | clean clone |

## Security review

- No `eval`, no `curl | sh`; variables quoted; `set -euo pipefail`.
- `sudo` is used only for the package-manager command (`env
  DEBIAN_FRONTEND=noninteractive apt-get …` under sudo for apt).
- Profile names are restricted to `[A-Za-z0-9_-]`; step ids from profiles are
  only used as quoted parts of function names.
- Dotfile edits can no longer destroy user content (bug 1) or replace links
  (bug 2).
- CI now declares `permissions: contents: read`; action references are tag
  pins (`@v4`), left as they were. `SECURITY.md` added.

## Limitations and unresolved risks

- `pacman` and `brew` dispatch are covered only by stubbed tests; no real
  Arch or macOS apply run was performed (macOS: dry-run only, by rule).
- `shell-profile` targets `~/.bashrc` by default, which zsh (macOS default)
  does not read; documented with the override.
- Steps run inside `if`, so `set -e` does not apply inside `apply`; `verify`
  is the safety net (documented).
- No locking against concurrent runs.

## CI status

- Default branch (`35f1d05`): success.
- Audit branch: pending until pushed.

## Acceptance checklist

| Item | Expected behavior | Command / test | Result | Actual | Reference |
|---|---|---|---|---|---|
| Lint | shellcheck + shfmt clean | CI commands locally | pass | 0 findings | ci.yml |
| Unit/integration tests | all pass | bats (container) | pass | 69/69 | tests/ |
| Idempotent | second run changes nothing; one managed block | container run 2 | pass | changed 0 (Ubuntu, Fedora) | lib/step.sh |
| Verified | a step that does not take effect fails the run | `step.bats` failing-verify test | pass | exit 1 + rollback hint | lib/step.sh |
| Resumable | interrupted run resumes, skipping finished steps | container interrupt + `--resume` | pass | skipped done steps | lib/state.sh |
| Dry-run touches nothing | no state, no dotfile edits, HOME unchanged | host (4 profiles) + containers + CI smoke | pass | unchanged | bootstrap.sh |
| Fresh distro install | works without manual prep | `ubuntu:24.04`, `fedora:41` | pass | exit 0 | bug 5 |
| User data safety | damaged markers, symlinks, modes preserved | containers + `editfile.bats` | pass | preserved | bugs 1, 2 |
| `--force` | re-runs one step, including an up-to-date one | containers + integration | pass | exit 0 | bug 3 |
| Exit codes | 0/1/2/3 as documented | integration tests | pass | — | bug 6 |

## Classification proposal

**Partially Verified**: lint, the full test suite and real apply runs on fresh
Ubuntu and Fedora containers pass, including the idempotency, resume and
dry-run guarantees. Arch (`pacman`) and macOS (`brew`) apply paths are only
covered by stubbed tests (macOS was dry-run only by design), and the CI legs
have not run on this branch.
