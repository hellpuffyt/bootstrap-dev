#!/usr/bin/env bash
# steps/web-packages.sh - tools for web development

BOOTSTRAP_WEB_PACKAGES_BINS=(node npm)

_web_packages_list() {
	case "$1" in
	apt) printf '%s\n' nodejs npm ;;
	dnf) printf '%s\n' nodejs npm ;;
	pacman) printf '%s\n' nodejs npm ;;
	brew) printf '%s\n' node ;;
	esac
}

step_web-packages_describe() {
	printf 'install web development tools (node, npm)'
}

step_web-packages_check() {
	local bin
	for bin in "${BOOTSTRAP_WEB_PACKAGES_BINS[@]}"; do
		pkg_is_installed "$bin" || return 1
	done
	return 0
}

step_web-packages_apply() {
	pkg_detect || return 1
	local pkgs
	mapfile -t pkgs < <(_web_packages_list "$PKG_MANAGER")
	if [ "${DRY_RUN:-0}" = "1" ]; then
		log_info "[dry-run] would install: ${pkgs[*]}"
		return 0
	fi
	pkg_install "${pkgs[@]}"
}

step_web-packages_verify() {
	step_web-packages_check
}

step_web-packages_rollback_hint() {
	printf 'remove the packages with your package manager, e.g. "apt-get remove nodejs npm"'
}
