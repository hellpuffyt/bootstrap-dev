#!/usr/bin/env bash
# lib/pkg.sh - package manager abstraction
#
# Detects apt, dnf, pacman or brew and dispatches install/query calls to it.
# Fails clearly rather than guessing when no supported manager is found.
#
# Public API:
#   pkg_detect                 - sets PKG_MANAGER, returns 1 if unsupported
#   pkg_install <pkg...>       - install one or more packages
#   pkg_is_installed <bin>     - true if a binary is already on PATH
#   pkg_run_privileged <cmd...> - run a command with sudo unless already root

if [ -n "${BOOTSTRAP_PKG_SH_LOADED:-}" ]; then
	return
fi
BOOTSTRAP_PKG_SH_LOADED=1

PKG_MANAGER="${PKG_MANAGER:-}"

pkg_detect() {
	if [ -n "${PKG_MANAGER:-}" ]; then
		return 0
	fi
	if command -v apt-get >/dev/null 2>&1; then
		PKG_MANAGER="apt"
	elif command -v dnf >/dev/null 2>&1; then
		PKG_MANAGER="dnf"
	elif command -v pacman >/dev/null 2>&1; then
		PKG_MANAGER="pacman"
	elif command -v brew >/dev/null 2>&1; then
		PKG_MANAGER="brew"
	else
		PKG_MANAGER=""
		log_error "no supported package manager found (looked for apt-get, dnf, pacman, brew)"
		return 1
	fi
	log_info "detected package manager: $PKG_MANAGER"
	return 0
}

pkg_run_privileged() {
	if [ "$(id -u 2>/dev/null || echo 1000)" = "0" ]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		log_error "root privileges required but sudo is not available: $*"
		return 1
	fi
}

pkg_install() {
	if [ "$#" -eq 0 ]; then
		return 0
	fi
	pkg_detect || return 1
	case "$PKG_MANAGER" in
	apt)
		pkg_run_privileged apt-get install -y "$@"
		;;
	dnf)
		pkg_run_privileged dnf install -y "$@"
		;;
	pacman)
		pkg_run_privileged pacman -S --noconfirm "$@"
		;;
	brew)
		brew install "$@"
		;;
	*)
		log_error "pkg_install: unsupported or undetected package manager"
		return 1
		;;
	esac
}

pkg_is_installed() {
	local bin="$1"
	command -v "$bin" >/dev/null 2>&1
}
