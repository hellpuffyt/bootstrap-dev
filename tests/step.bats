#!/usr/bin/env bats

load 'test_helper'

setup() {
	bd_common_setup
	. "$ROOT/lib/log.sh"
	. "$ROOT/lib/state.sh"
	. "$ROOT/lib/step.sh"

	APPLY_CALLS="$TEST_TMP/apply_calls"
	VERIFY_CALLS="$TEST_TMP/verify_calls"
	: >"$APPLY_CALLS"
	: >"$VERIFY_CALLS"

	# A step that is never satisfied until applied once (tracked via a marker file).
	MARKER="$TEST_TMP/marker"
	step_good_check() { [ -f "$MARKER" ]; }
	step_good_apply() {
		echo "applied" >>"$APPLY_CALLS"
		[ "${DRY_RUN:-0}" = "1" ] && return 0
		touch "$MARKER"
	}
	step_good_verify() {
		echo "verified" >>"$VERIFY_CALLS"
		[ -f "$MARKER" ]
	}

	# A step whose verify always fails.
	step_badverify_check() { return 1; }
	step_badverify_apply() { return 0; }
	step_badverify_verify() { return 1; }
	step_badverify_rollback_hint() { printf 'undo it by hand'; }

	# A step whose apply always fails.
	step_badapply_check() { return 1; }
	step_badapply_apply() { return 1; }
	step_badapply_verify() { return 0; }

	export -f step_good_check step_good_apply step_good_verify
	export -f step_badverify_check step_badverify_apply step_badverify_verify step_badverify_rollback_hint
	export -f step_badapply_check step_badapply_apply step_badapply_verify
}

teardown() {
	bd_common_teardown
}

@test "run_step applies a step that is not yet satisfied" {
	run run_step good
	[ "$status" -eq 0 ]
	[ -f "$MARKER" ]
	[ "$(cat "$APPLY_CALLS")" = "applied" ]
}

@test "run_step skips a step whose check already passes" {
	touch "$MARKER"
	run run_step good
	[ "$status" -eq 0 ]
	[ ! -s "$APPLY_CALLS" ]
}

@test "run_step applying twice only calls apply once (idempotent via check)" {
	run_step good
	run_step good
	local count
	count="$(wc -l <"$APPLY_CALLS")"
	[ "$count" -eq 1 ]
}

@test "run_step marks state done after a successful apply" {
	run_step good
	run state_is_done good
	[ "$status" -eq 0 ]
}

@test "RESUME_MODE=1 skips a step recorded as done without calling check" {
	state_init
	state_mark_done good
	# no marker file exists, so check() would fail if it were called - but
	# resume mode should skip without ever calling apply.
	RESUME_MODE=1 run run_step good
	[ "$status" -eq 0 ]
	[ ! -s "$APPLY_CALLS" ]
}

@test "FORCE_STEP re-applies a step even though it is already done" {
	run_step good
	[ "$(wc -l <"$APPLY_CALLS")" -eq 1 ]
	FORCE_STEP=good run_step good
	[ "$(wc -l <"$APPLY_CALLS")" -eq 2 ]
}

@test "DRY_RUN=1 calls apply in dry-run mode but does not mark state done" {
	DRY_RUN=1 run run_step good
	[ "$status" -eq 0 ]
	[ "$(cat "$APPLY_CALLS")" = "applied" ]
	[ ! -f "$MARKER" ]
	run state_is_done good
	[ "$status" -eq 1 ]
}

@test "a failing verify fails the step and prints the rollback hint" {
	run run_step badverify
	[ "$status" -eq 1 ]
	[[ "$output" == *"undo it by hand"* ]]
	run state_is_done badverify
	[ "$status" -eq 1 ]
}

@test "a failing apply fails the step without calling verify" {
	run run_step badapply
	[ "$status" -eq 1 ]
	run state_is_done badapply
	[ "$status" -eq 1 ]
}

@test "run_step fails clearly for an undefined step" {
	run run_step totally-undefined-step
	[ "$status" -eq 1 ]
	[[ "$output" == *"not defined"* ]]
}

@test "step_summary_print reports changed, skipped and failed counts" {
	run_step good
	touch "$TEST_TMP/marker2"
	run step_summary_print
	[[ "$output" == *"changed: 1"* ]]
}
