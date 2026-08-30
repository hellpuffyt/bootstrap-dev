#!/usr/bin/env bash
# steps/ops-packages.sh - tools for operations work

BOOTSTRAP_OPS_PACKAGES_BINS=(jq tmux htop)

_ops_packages_list() {
	case "$1" in
	apt) printf '%s\n' jq tmux htop ;;
	dnf) printf '%s\n' jq tmux htop ;;
	pacman) printf '%s\n' jq tmux htop ;;
	brew) printf '%s\n' jq tmux htop ;;
	esac
}

step_ops-packages_describe() {
	printf 'install operations tooling (jq, tmux, htop)'
}

step_ops-packages_check() {
	local bin
	for bin in "${BOOTSTRAP_OPS_PACKAGES_BINS[@]}"; do
		pkg_is_installed "$bin" || return 1
	done
	return 0
}

step_ops-packages_apply() {
	pkg_detect || return 1
	local pkgs
	# bash 3.2 on macOS has no mapfile; read into the array by hand.
	pkgs=()
	while IFS= read -r _pkg; do
		pkgs+=("$_pkg")
	done < <(_ops_packages_list "$PKG_MANAGER")
	if [ "${DRY_RUN:-0}" = "1" ]; then
		log_info "[dry-run] would install: ${pkgs[*]}"
		return 0
	fi
	pkg_install "${pkgs[@]}"
}

step_ops-packages_verify() {
	step_ops-packages_check
}

step_ops-packages_rollback_hint() {
	printf 'remove the packages with your package manager, e.g. "apt-get remove jq tmux htop"'
}
