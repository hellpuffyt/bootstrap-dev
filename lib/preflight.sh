#!/usr/bin/env bash
# lib/preflight.sh - checks that must pass before anything is changed
#
# Public API:
#   preflight_run  - runs all checks, returns 1 on the first hard failure
#
# Individual checks can be skipped for testing:
#   BOOTSTRAP_SKIP_NETWORK_CHECK=1
#   BOOTSTRAP_SKIP_SUDO_CHECK=1
#   BOOTSTRAP_MIN_DISK_MB (default 500)

if [ -n "${BOOTSTRAP_PREFLIGHT_SH_LOADED:-}" ]; then
	return
fi
BOOTSTRAP_PREFLIGHT_SH_LOADED=1

# shellcheck disable=SC2120  # $1 is an optional override; callers may omit it
preflight_check_disk_space() {
	local min_mb="${BOOTSTRAP_MIN_DISK_MB:-500}"
	local target="${1:-$HOME}"
	if ! command -v df >/dev/null 2>&1; then
		log_warn "preflight: df not available, skipping disk space check"
		return 0
	fi
	local avail_kb
	avail_kb="$(df -Pk "$target" 2>/dev/null | awk 'NR==2 {print $4}')"
	if [ -z "$avail_kb" ]; then
		log_warn "preflight: could not determine free disk space, skipping check"
		return 0
	fi
	local avail_mb=$((avail_kb / 1024))
	if [ "$avail_mb" -lt "$min_mb" ]; then
		log_error "preflight: only ${avail_mb}MB free at $target, need ${min_mb}MB"
		return 1
	fi
	log_info "preflight: disk space ok (${avail_mb}MB free at $target)"
	return 0
}

# shellcheck disable=SC2120  # $1 is an optional override; callers may omit it
preflight_check_network() {
	if [ "${BOOTSTRAP_SKIP_NETWORK_CHECK:-0}" = "1" ]; then
		log_info "preflight: network check skipped"
		return 0
	fi
	local host="${1:-github.com}"
	if command -v curl >/dev/null 2>&1; then
		if curl -fsS --max-time 5 -o /dev/null "https://${host}"; then
			log_info "preflight: network reachable ($host)"
			return 0
		fi
	elif command -v ping >/dev/null 2>&1; then
		if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
			log_info "preflight: network reachable ($host)"
			return 0
		fi
	else
		log_warn "preflight: neither curl nor ping available, skipping network check"
		return 0
	fi
	log_error "preflight: network unreachable ($host)"
	return 1
}

preflight_check_sudo() {
	if [ "${BOOTSTRAP_SKIP_SUDO_CHECK:-0}" = "1" ]; then
		log_info "preflight: sudo check skipped"
		return 0
	fi
	if [ "$(id -u 2>/dev/null || echo 1000)" = "0" ]; then
		log_info "preflight: running as root, sudo not required"
		return 0
	fi
	if command -v sudo >/dev/null 2>&1; then
		log_info "preflight: sudo available"
		return 0
	fi
	log_error "preflight: not root and sudo is not installed"
	return 1
}

preflight_check_conflicts() {
	# Steps may export BOOTSTRAP_CONFLICT_BINS as a space separated list of
	# binaries that must NOT already exist from an unmanaged install.
	local bin
	for bin in ${BOOTSTRAP_CONFLICT_BINS:-}; do
		if command -v "$bin" >/dev/null 2>&1; then
			log_error "preflight: conflicting existing install found for '$bin'"
			return 1
		fi
	done
	log_info "preflight: no conflicting installs declared or found"
	return 0
}

preflight_run() {
	log_step "running preflight checks"
	preflight_check_disk_space || return 1
	preflight_check_network || return 1
	preflight_check_sudo || return 1
	preflight_check_conflicts || return 1
	log_info "preflight: all checks passed"
	return 0
}
