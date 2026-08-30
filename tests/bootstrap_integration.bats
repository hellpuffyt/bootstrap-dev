#!/usr/bin/env bats

load 'test_helper'

setup() {
	bd_common_setup
}

teardown() {
	bd_common_teardown
}

run_bootstrap() {
	bash "$ROOT/bootstrap.sh" --skip-preflight --state-file "$STATE_FILE" --log-file "$LOG_FILE" "$@"
}

@test "--help exits 0 and prints usage" {
	run bash "$ROOT/bootstrap.sh" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

@test "--list-profiles lists the shipped profiles" {
	run bash "$ROOT/bootstrap.sh" --list-profiles
	[ "$status" -eq 0 ]
	[[ "$output" == *"minimal"* ]]
	[[ "$output" == *"web"* ]]
	[[ "$output" == *"data"* ]]
	[[ "$output" == *"ops"* ]]
}

@test "--list-steps lists the shipped steps" {
	run bash "$ROOT/bootstrap.sh" --list-steps
	[ "$status" -eq 0 ]
	[[ "$output" == *"base-packages"* ]]
	[[ "$output" == *"shell-profile"* ]]
	[[ "$output" == *"git-defaults"* ]]
}

@test "an unknown profile exits with an error and does not run" {
	run run_bootstrap --profile does-not-exist
	[ "$status" -eq 3 ]
	[[ "$output" == *"unknown profile"* ]]
}

@test "--dry-run creates no state file and no log content marking changes" {
	run run_bootstrap --dry-run --profile minimal
	[ "$status" -eq 0 ]
	[ ! -f "$STATE_FILE" ]
}

@test "--dry-run does not touch the shell profile file" {
	export BOOTSTRAP_SHELL_PROFILE_FILE="$HOME/.bashrc"
	run run_bootstrap --dry-run --profile minimal
	[ "$status" -eq 0 ]
	[ ! -e "$BOOTSTRAP_SHELL_PROFILE_FILE" ]
}

@test "a real run applies steps and records state" {
	export BOOTSTRAP_SHELL_PROFILE_FILE="$HOME/.bashrc"
	run run_bootstrap --profile minimal
	[ "$status" -eq 0 ]
	[ -f "$STATE_FILE" ]
	grep -q 'shell-profile' "$STATE_FILE"
	grep -q 'git-defaults' "$STATE_FILE"
	[ -f "$BOOTSTRAP_SHELL_PROFILE_FILE" ]
}

@test "running the minimal profile twice is idempotent for git-defaults" {
	run_bootstrap --profile minimal
	run run_bootstrap --profile minimal
	[ "$status" -eq 0 ]
	[[ "$output" == *"skip: 'git-defaults' already satisfied"* ]]
}

@test "--resume skips steps already recorded in the state file" {
	run_bootstrap --profile minimal
	run run_bootstrap --profile minimal --resume
	[ "$status" -eq 0 ]
	[[ "$output" == *"already completed (resumed from state)"* ]]
}

@test "--force re-applies a single step" {
	export BOOTSTRAP_SHELL_PROFILE_FILE="$HOME/.bashrc"
	run_bootstrap --profile minimal
	run run_bootstrap --profile minimal --force git-defaults
	[ "$status" -eq 0 ]
	[[ "$output" == *"done: 'git-defaults'"* ]]
}

@test "the summary reports failed: 0 on a clean run" {
	run run_bootstrap --profile minimal
	[[ "$output" == *"failed: 0"* ]]
}
