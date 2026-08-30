#!/usr/bin/env bash
# steps/data-packages.sh - tools for data work

BOOTSTRAP_DATA_PACKAGES_BINS=(python3 pip3)

_data_packages_list() {
	case "$1" in
	apt) printf '%s\n' python3 python3-pip python3-venv ;;
	dnf) printf '%s\n' python3 python3-pip ;;
	pacman) printf '%s\n' python python-pip ;;
	brew) printf '%s\n' python3 ;;
	esac
}

step_data-packages_describe() {
	printf 'install data tooling (python3, pip)'
}

step_data-packages_check() {
	local bin
	for bin in "${BOOTSTRAP_DATA_PACKAGES_BINS[@]}"; do
		pkg_is_installed "$bin" || return 1
	done
	return 0
}

step_data-packages_apply() {
	pkg_detect || return 1
	local pkgs
	# bash 3.2 on macOS has no mapfile; read into the array by hand.
	pkgs=()
	while IFS= read -r _pkg; do
		pkgs+=("$_pkg")
	done < <(_data_packages_list "$PKG_MANAGER")
	if [ "${DRY_RUN:-0}" = "1" ]; then
		log_info "[dry-run] would install: ${pkgs[*]}"
		return 0
	fi
	pkg_install "${pkgs[@]}"
}

step_data-packages_verify() {
	step_data-packages_check
}

step_data-packages_rollback_hint() {
	printf 'remove the packages with your package manager, e.g. "apt-get remove python3-pip"'
}
