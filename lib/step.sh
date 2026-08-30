#!/usr/bin/env bash
# lib/step.sh - the step framework
#
# A step named "foo" is a shell file defining some of these functions:
#   step_foo_describe        (optional) one-line human description
#   step_foo_check            required - exit 0 if already applied
#   step_foo_apply            required - make the change (idempotent)
#   step_foo_verify           required - exit 0 only if the change actually worked
#   step_foo_rollback_hint    (optional) prints how to undo the step
#
# run_step drives one step through: resume-skip -> check -> apply -> verify,
# recording state and updating the run summary as it goes.

if [ -n "${BOOTSTRAP_STEP_SH_LOADED:-}" ]; then
	return
fi
BOOTSTRAP_STEP_SH_LOADED=1

STEP_CHANGED=()
STEP_SKIPPED=()
STEP_FAILED=()

step_exists() {
	local id="$1"
	declare -F "step_${id}_check" >/dev/null && declare -F "step_${id}_apply" >/dev/null && declare -F "step_${id}_verify" >/dev/null
}

_step_describe() {
	local id="$1"
	if declare -F "step_${id}_describe" >/dev/null; then
		"step_${id}_describe"
	else
		printf '%s' "$id"
	fi
}

_step_rollback_hint() {
	local id="$1"
	if declare -F "step_${id}_rollback_hint" >/dev/null; then
		"step_${id}_rollback_hint"
	fi
}

# run_step <id>
# Honors globals: DRY_RUN=1, RESUME_MODE=1, FORCE_STEP=<id>
run_step() {
	local id="$1"
	local desc
	desc="$(_step_describe "$id")"

	if ! step_exists "$id"; then
		log_error "step '$id' is not defined (missing check/apply/verify)"
		STEP_FAILED+=("$id")
		return 1
	fi

	log_step "$id - $desc"

	local force=0
	if [ "${FORCE_STEP:-}" = "$id" ]; then
		force=1
		state_clear "$id"
	fi

	if [ "$force" -ne 1 ] && [ "${RESUME_MODE:-0}" = "1" ] && state_is_done "$id"; then
		log_info "skip: '$id' already completed (resumed from state)"
		STEP_SKIPPED+=("$id")
		return 0
	fi

	if [ "$force" -ne 1 ] && "step_${id}_check"; then
		log_info "skip: '$id' already satisfied"
		[ "${DRY_RUN:-0}" = "1" ] || state_mark_done "$id"
		STEP_SKIPPED+=("$id")
		return 0
	fi

	if [ "${DRY_RUN:-0}" = "1" ]; then
		log_info "[dry-run] '$id' would be applied"
		DRY_RUN=1 "step_${id}_apply" || true
		STEP_SKIPPED+=("$id")
		return 0
	fi

	if ! "step_${id}_apply"; then
		log_error "step '$id' failed to apply"
		local hint
		hint="$(_step_rollback_hint "$id")"
		[ -n "$hint" ] && log_error "rollback hint for '$id': $hint"
		STEP_FAILED+=("$id")
		return 1
	fi

	if ! "step_${id}_verify"; then
		log_error "step '$id' applied but verification failed"
		local hint2
		hint2="$(_step_rollback_hint "$id")"
		[ -n "$hint2" ] && log_error "rollback hint for '$id': $hint2"
		STEP_FAILED+=("$id")
		return 1
	fi

	state_mark_done "$id"
	log_info "done: '$id'"
	STEP_CHANGED+=("$id")
	return 0
}

step_summary_print() {
	log_step "summary"
	log_info "changed: ${#STEP_CHANGED[@]} (${STEP_CHANGED[*]:-none})"
	log_info "skipped: ${#STEP_SKIPPED[@]} (${STEP_SKIPPED[*]:-none})"
	if [ "${#STEP_FAILED[@]}" -gt 0 ]; then
		log_error "failed: ${#STEP_FAILED[@]} (${STEP_FAILED[*]})"
	else
		log_info "failed: 0"
	fi
}
