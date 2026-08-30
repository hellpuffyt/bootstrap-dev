#!/usr/bin/env bash
# steps/base-packages.sh - core command line tools every profile needs

BOOTSTRAP_BASE_PACKAGES_BINS=(git curl)

_base_packages_list() {
	case "$1" in
	apt) printf '%s\n' git curl ca-certificates ;;
	dnf) printf '%s\n' git curl ca-certificates ;;
	pacman) printf '%s\n' git curl ca-certificates ;;
	brew) printf '%s\n' git curl ;;
	esac
}

step_base-packages_describe() {
	printf 'install core command line tools (git, curl, ca-certificates)'
}

step_base-packages_check() {
	local bin
	for bin in "${BOOTSTRAP_BASE_PACKAGES_BINS[@]}"; do
		pkg_is_installed "$bin" || return 1
	done
	return 0
}

step_base-packages_apply() {
	pkg_detect || return 1
	local pkgs
	# bash 3.2 on macOS has no mapfile; read into the array by hand.
	pkgs=()
	while IFS= read -r _pkg; do
		pkgs+=("$_pkg")
	done < <(_base_packages_list "$PKG_MANAGER")
	if [ "${DRY_RUN:-0}" = "1" ]; then
		log_info "[dry-run] would install: ${pkgs[*]}"
		return 0
	fi
	pkg_install "${pkgs[@]}"
}

step_base-packages_verify() {
	step_base-packages_check
}

step_base-packages_rollback_hint() {
	printf 'remove the packages with your package manager, e.g. "apt-get remove git curl"'
}
