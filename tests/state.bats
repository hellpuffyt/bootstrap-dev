#!/usr/bin/env bats

load 'test_helper'

setup() {
	bd_common_setup
	. "$ROOT/lib/log.sh"
	. "$ROOT/lib/state.sh"
}

teardown() {
	bd_common_teardown
}

@test "state_init creates the state file and its parent dir" {
	STATE_FILE="$TEST_TMP/nested/dir/state"
	run state_init
	[ "$status" -eq 0 ]
	[ -f "$STATE_FILE" ]
}

@test "state_is_done is false for an unknown step" {
	state_init
	run state_is_done "never-run"
	[ "$status" -eq 1 ]
}

@test "state_mark_done then state_is_done returns true" {
	state_init
	state_mark_done "step-a"
	run state_is_done "step-a"
	[ "$status" -eq 0 ]
}

@test "state_mark_done is idempotent (one line after repeated calls)" {
	state_init
	state_mark_done "step-a"
	state_mark_done "step-a"
	state_mark_done "step-a"
	local count
	count="$(grep -c '^step-a$' "$STATE_FILE")"
	[ "$count" -eq 1 ]
}

@test "state_clear removes only the named step" {
	state_init
	state_mark_done "step-a"
	state_mark_done "step-b"
	state_clear "step-a"
	run state_is_done "step-a"
	[ "$status" -eq 1 ]
	run state_is_done "step-b"
	[ "$status" -eq 0 ]
}

@test "state_reset removes the state file entirely" {
	state_init
	state_mark_done "step-a"
	state_reset
	[ ! -f "$STATE_FILE" ]
}

@test "state_list_done lists all recorded steps" {
	state_init
	state_mark_done "step-a"
	state_mark_done "step-b"
	run state_list_done
	[ "$status" -eq 0 ]
	[[ "$output" == *"step-a"* ]]
	[[ "$output" == *"step-b"* ]]
}
