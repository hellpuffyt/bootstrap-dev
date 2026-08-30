#!/usr/bin/env bash
# lib/log.sh - structured logging for bootstrap-dev
#
# Public API:
#   log_init <path>      - open a log file for this run (idempotent per run)
#   log_info  <msg>
#   log_warn  <msg>
#   log_error <msg>
#   log_step  <msg>       - highlighted "entering step" line
#   log_raw   <msg>       - write only to the log file, not stdout

# Guard against double-sourcing.
if [ -n "${BOOTSTRAP_LOG_SH_LOADED:-}" ]; then
	return
fi
BOOTSTRAP_LOG_SH_LOADED=1

LOG_FILE="${LOG_FILE:-}"

_log_color() {
	local name="$1"
	if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
		printf ''
		return
	fi
	case "$name" in
	red) printf '\033[31m' ;;
	green) printf '\033[32m' ;;
	yellow) printf '\033[33m' ;;
	blue) printf '\033[34m' ;;
	bold) printf '\033[1m' ;;
	reset) printf '\033[0m' ;;
	*) printf '' ;;
	esac
}

log_init() {
	local path="$1"
	LOG_FILE="$path"
	mkdir -p "$(dirname -- "$LOG_FILE")"
	{
		printf -- '----- bootstrap-dev run started %s -----\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
	} >>"$LOG_FILE"
}

_log_write() {
	local level="$1"
	local msg="$2"
	local ts
	ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
	if [ -n "$LOG_FILE" ]; then
		printf '%s [%s] %s\n' "$ts" "$level" "$msg" >>"$LOG_FILE"
	fi
}

log_raw() {
	_log_write "RAW" "$1"
}

log_info() {
	local msg="$1"
	printf '%s[INFO]%s %s\n' "$(_log_color blue)" "$(_log_color reset)" "$msg"
	_log_write "INFO" "$msg"
}

log_warn() {
	local msg="$1"
	printf '%s[WARN]%s %s\n' "$(_log_color yellow)" "$(_log_color reset)" "$msg" >&2
	_log_write "WARN" "$msg"
}

log_error() {
	local msg="$1"
	printf '%s[ERROR]%s %s\n' "$(_log_color red)" "$(_log_color reset)" "$msg" >&2
	_log_write "ERROR" "$msg"
}

log_step() {
	local msg="$1"
	printf '%s%s==>%s %s\n' "$(_log_color bold)" "$(_log_color green)" "$(_log_color reset)" "$msg"
	_log_write "STEP" "$msg"
}
