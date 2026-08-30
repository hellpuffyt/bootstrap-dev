#!/usr/bin/env bash
# steps/shell-profile.sh - managed block of shell defaults in ~/.bashrc

BOOTSTRAP_SHELL_PROFILE_FILE="${BOOTSTRAP_SHELL_PROFILE_FILE:-${HOME:-.}/.bashrc}"
BOOTSTRAP_SHELL_PROFILE_ID="shell-profile"

_shell_profile_content() {
	cat <<'EOF'
export EDITOR="${EDITOR:-vim}"
export PATH="$HOME/.local/bin:$PATH"
alias ll='ls -alF'
EOF
}

step_shell-profile_describe() {
	printf 'add managed shell defaults to %s' "$BOOTSTRAP_SHELL_PROFILE_FILE"
}

step_shell-profile_check() {
	local wanted current
	wanted="$(_shell_profile_content)"
	current="$(managed_block_current "$BOOTSTRAP_SHELL_PROFILE_FILE" "$BOOTSTRAP_SHELL_PROFILE_ID")"
	[ "$wanted" = "$current" ]
}

step_shell-profile_apply() {
	managed_block_apply "$BOOTSTRAP_SHELL_PROFILE_FILE" "$BOOTSTRAP_SHELL_PROFILE_ID" "$(_shell_profile_content)"
}

step_shell-profile_verify() {
	step_shell-profile_check
}

step_shell-profile_rollback_hint() {
	printf 'delete the block between "# >>> bootstrap-dev:%s >>>" and "# <<< bootstrap-dev:%s <<<" in %s' \
		"$BOOTSTRAP_SHELL_PROFILE_ID" "$BOOTSTRAP_SHELL_PROFILE_ID" "$BOOTSTRAP_SHELL_PROFILE_FILE"
}
