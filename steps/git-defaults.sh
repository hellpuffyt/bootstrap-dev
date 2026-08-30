#!/usr/bin/env bash
# steps/git-defaults.sh - sane global git configuration

BOOTSTRAP_GIT_DEFAULTS_KEYS=(init.defaultBranch pull.rebase)
_git_default_value() {
	case "$1" in
	init.defaultBranch) printf 'main' ;;
	pull.rebase) printf 'false' ;;
	esac
}

step_git-defaults_describe() {
	printf 'set sane git global defaults (init.defaultBranch, pull.rebase)'
}

step_git-defaults_check() {
	local key want got
	for key in "${BOOTSTRAP_GIT_DEFAULTS_KEYS[@]}"; do
		want="$(_git_default_value "$key")"
		got="$(git config --global --get "$key" 2>/dev/null || true)"
		[ "$got" = "$want" ] || return 1
	done
	return 0
}

step_git-defaults_apply() {
	local key want
	for key in "${BOOTSTRAP_GIT_DEFAULTS_KEYS[@]}"; do
		want="$(_git_default_value "$key")"
		if [ "${DRY_RUN:-0}" = "1" ]; then
			log_info "[dry-run] would set git config --global $key $want"
			continue
		fi
		git config --global "$key" "$want"
	done
}

step_git-defaults_verify() {
	step_git-defaults_check
}

step_git-defaults_rollback_hint() {
	printf 'unset with: %s' "$(
		for key in "${BOOTSTRAP_GIT_DEFAULTS_KEYS[@]}"; do
			printf 'git config --global --unset %s; ' "$key"
		done
	)"
}
