#!/usr/bin/env bash
# lib/state.sh - resumable run state
#
# The state file is a plain text file, one completed step id per line,
# so it can be inspected and edited by hand if needed:
#   git-defaults
#   shell-profile
#
# Public API:
#   state_init                  - ensure the state file and its dir exist
#   state_is_done <step_id>     - 0 if the step is recorded as done
#   state_mark_done <step_id>   - record a step as done (idempotent)
#   state_clear <step_id>       - remove a step from the state file
#   state_reset                 - remove the entire state file

if [ -n "${BOOTSTRAP_STATE_SH_LOADED:-}" ]; then
	return
fi
BOOTSTRAP_STATE_SH_LOADED=1

STATE_FILE="${STATE_FILE:-}"

state_init() {
	if [ -z "$STATE_FILE" ]; then
		log_error "state_init: STATE_FILE is not set"
		return 1
	fi
	mkdir -p "$(dirname -- "$STATE_FILE")"
	touch "$STATE_FILE"
}

state_is_done() {
	local step_id="$1"
	[ -f "$STATE_FILE" ] || return 1
	grep -Fxq -- "$step_id" "$STATE_FILE"
}

state_mark_done() {
	local step_id="$1"
	state_init
	if ! state_is_done "$step_id"; then
		printf '%s\n' "$step_id" >>"$STATE_FILE"
	fi
}

state_clear() {
	local step_id="$1"
	[ -f "$STATE_FILE" ] || return 0
	local tmp
	tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
	grep -Fxv -- "$step_id" "$STATE_FILE" >"$tmp" || true
	mv "$tmp" "$STATE_FILE"
}

state_reset() {
	[ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
	return 0
}

state_list_done() {
	[ -f "$STATE_FILE" ] || return 0
	cat -- "$STATE_FILE"
}
