# Contributing

## Getting set up

You need `bash` 4+, `bats-core`, `shellcheck`, and `shfmt`. On a Debian-family
system:

```sh
sudo apt-get install -y bats shellcheck
go install mvdan.cc/sh/v3/cmd/shfmt@latest   # or: brew install shfmt
```

Or run everything through Docker, which needs nothing installed locally:

```sh
docker run --rm -v "$PWD:/w" -w /w bats/bats:latest tests/
docker run --rm -v "$PWD:/w" -w /w koalaman/shellcheck:stable bootstrap.sh lib/*.sh steps/*.sh
docker run --rm -v "$PWD:/w" -w /w mvdan/shfmt:latest -d .
```

## Before you send a change

1. `bats tests/` — all tests pass.
2. `shellcheck` on every changed `.sh` file — zero warnings. Fix the warning
   properly; do not add a blanket `# shellcheck disable`.
3. `shfmt -d .` — no diff.
4. If you touched `lib/` or `steps/`, add or update tests. New steps need at
   minimum a check/apply/verify round trip test and an idempotency test
   (apply twice, assert the second is a no-op).

## Writing a step

See the "Writing a step" section of the README. In short: a step is a file in
`steps/` defining `step_<id>_check`, `step_<id>_apply`, `step_<id>_verify`,
and ideally `step_<id>_describe` and `step_<id>_rollback_hint`. `apply` must
be safe to run twice. Never `curl | bash` an unpinned URL; if a step fetches
something, it must verify a checksum before using it.

## Commit style

Small, focused commits. Explain *why* a change was made when it is not
obvious from the diff alone.
