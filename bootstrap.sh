#!/usr/bin/env bash
# bootstrap.sh - idempotent, verified, resumable dev machine bootstrapper
set -euo pipefail

BOOTSTRAP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/log.sh
. "$BOOTSTRAP_ROOT/lib/log.sh"
# shellcheck source=lib/state.sh
. "$BOOTSTRAP_ROOT/lib/state.sh"
# shellcheck source=lib/pkg.sh
. "$BOOTSTRAP_ROOT/lib/pkg.sh"
# shellcheck source=lib/editfile.sh
. "$BOOTSTRAP_ROOT/lib/editfile.sh"
# shellcheck source=lib/preflight.sh
. "$BOOTSTRAP_ROOT/lib/preflight.sh"
# shellcheck source=lib/step.sh
. "$BOOTSTRAP_ROOT/lib/step.sh"

PROFILE="minimal"
DRY_RUN=0
RESUME_MODE=0
FORCE_STEP=""
STATE_FILE="${STATE_FILE:-${HOME:-.}/.bootstrap-dev/state}"
LOG_FILE_PATH="${LOG_FILE_PATH:-${HOME:-.}/.bootstrap-dev/bootstrap.log}"
SKIP_PREFLIGHT=0
LIST_STEPS=0
LIST_PROFILES=0

usage() {
	cat <<'EOF'
Usage: bootstrap.sh [options]

Options:
  --profile <name>     Profile to run (default: minimal). See profiles/*.conf.
  --dry-run            Print what would change; touch nothing.
  --resume             Skip steps already recorded as done in the state file.
  --force <step>       Re-run a single step even if it is marked done.
  --state-file <path>  Override the state file location.
  --log-file <path>    Override the log file location.
  --skip-preflight     Skip preflight checks (for local testing only).
  --list-steps         List all known steps and exit.
  --list-profiles      List all known profiles and exit.
  -h, --help           Show this help.
EOF
}

# Every option that takes a value goes through this, so a missing value is a
# bad argument (exit 3) rather than a bare ${2:?} shell error (exit 1).
need_value() {
	if [ "$2" -lt 2 ] || [ -z "$3" ]; then
		printf '%s requires a value\n' "$1" >&2
		usage >&2
		exit 3
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--profile)
		need_value --profile "$#" "${2:-}"
		PROFILE="$2"
		shift 2
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--resume)
		RESUME_MODE=1
		shift
		;;
	--force)
		need_value --force "$#" "${2:-}"
		FORCE_STEP="$2"
		shift 2
		;;
	--state-file)
		need_value --state-file "$#" "${2:-}"
		STATE_FILE="$2"
		shift 2
		;;
	--log-file)
		need_value --log-file "$#" "${2:-}"
		LOG_FILE_PATH="$2"
		shift 2
		;;
	--skip-preflight)
		SKIP_PREFLIGHT=1
		shift
		;;
	--list-steps)
		LIST_STEPS=1
		shift
		;;
	--list-profiles)
		LIST_PROFILES=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'unknown option: %s\n' "$1" >&2
		usage >&2
		exit 3
		;;
	esac
done

export DRY_RUN RESUME_MODE FORCE_STEP STATE_FILE

if [ "$LIST_PROFILES" -eq 1 ]; then
	for f in "$BOOTSTRAP_ROOT"/profiles/*.conf; do
		basename -- "$f" .conf
	done
	exit 0
fi

# Load every step definition so --list-steps and profile resolution both work.
for step_file in "$BOOTSTRAP_ROOT"/steps/*.sh; do
	[ -e "$step_file" ] || continue
	# shellcheck source=/dev/null
	. "$step_file"
done

if [ "$LIST_STEPS" -eq 1 ]; then
	for step_file in "$BOOTSTRAP_ROOT"/steps/*.sh; do
		[ -e "$step_file" ] || continue
		basename -- "$step_file" .sh
	done
	exit 0
fi

case "$PROFILE" in
"" | *[!A-Za-z0-9_-]*)
	printf 'invalid profile name: %s (letters, digits, - and _ only)\n' "$PROFILE" >&2
	exit 3
	;;
esac

PROFILE_FILE="$BOOTSTRAP_ROOT/profiles/${PROFILE}.conf"
if [ ! -f "$PROFILE_FILE" ]; then
	printf 'unknown profile: %s (looked for %s)\n' "$PROFILE" "$PROFILE_FILE" >&2
	exit 3
fi

# Read with a loop rather than `mapfile`: mapfile is a bash 4 builtin and
# macOS still ships bash 3.2, where it does not exist. A bootstrap tool that
# cannot run on macOS is not much of a bootstrap tool.
STEP_IDS=()
while IFS= read -r _line; do
	STEP_IDS+=("$_line")
done < <(grep -Ev '^[[:space:]]*(#|$)' "$PROFILE_FILE")

if [ -n "$FORCE_STEP" ]; then
	_force_in_profile=0
	for id in "${STEP_IDS[@]}"; do
		[ "$id" = "$FORCE_STEP" ] && _force_in_profile=1
	done
	if [ "$_force_in_profile" -ne 1 ]; then
		printf -- '--force %s: no such step in profile %s (steps: %s)\n' "$FORCE_STEP" "$PROFILE" "${STEP_IDS[*]}" >&2
		exit 3
	fi
fi

log_init "$LOG_FILE_PATH"
log_info "bootstrap-dev starting: profile=$PROFILE dry_run=$DRY_RUN resume=$RESUME_MODE"

if [ "$SKIP_PREFLIGHT" -eq 1 ]; then
	log_warn "preflight checks skipped by request"
elif ! preflight_run; then
	log_error "preflight checks failed, aborting before making any changes"
	exit 2
fi

if [ "$DRY_RUN" -ne 1 ]; then
	state_init
fi

exit_code=0
for id in "${STEP_IDS[@]}"; do
	if ! run_step "$id"; then
		exit_code=1
		break
	fi
done

step_summary_print
log_info "log written to $LOG_FILE_PATH"

if [ "${#STEP_FAILED[@]}" -gt 0 ]; then
	exit_code=1
fi

exit "$exit_code"
