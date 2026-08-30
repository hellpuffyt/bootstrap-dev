#!/usr/bin/env bash
# tests/test_helper.bash - shared bats setup

# Absolute path to the repo root regardless of where bats is invoked from.
repo_root() {
	cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

ROOT="$(repo_root)"

# Creates a scratch HOME and a fake bin directory ahead of PATH, then sources
# the library files under test. Call from a test's `setup()`.
bd_common_setup() {
	TEST_TMP="$(mktemp -d)"
	export TEST_TMP
	export HOME="$TEST_TMP/home"
	mkdir -p "$HOME"

	FAKE_BIN="$TEST_TMP/fake-bin"
	mkdir -p "$FAKE_BIN"
	export FAKE_BIN
	export PATH="$FAKE_BIN:$PATH"

	# Remember the real PATH so a test can opt into full isolation.
	export REAL_PATH="$PATH"

	export STATE_FILE="$TEST_TMP/state"
	export LOG_FILE="$TEST_TMP/log"
	unset DRY_RUN RESUME_MODE FORCE_STEP PKG_MANAGER || true

	# A transparent sudo stub so pkg_run_privileged never shells out to the
	# real sudo (which may prompt, or reset PATH via secure_path and dodge
	# our fake package manager binaries) when tests run as a non-root user.
	cat >"$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
	chmod +x "$FAKE_BIN/sudo"

	# Fake curl: enough for base-packages' check (a binary on PATH) and for
	# preflight's network check to succeed without a real network call.
	cat >"$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
# Succeeds for any URL except one containing the reserved ".invalid" TLD,
# so preflight's network check is exercised without a real network call.
for arg in "$@"; do
	case "$arg" in
	*.invalid*) exit 6 ;; # curl's "could not resolve host" code
	esac
done
exit 0
EOF
	chmod +x "$FAKE_BIN/curl"

	# Fake git: real git is not guaranteed to be present in every test
	# environment (e.g. minimal containers), and even where it is, tests
	# should not depend on the host's package manager or git version. This
	# stub implements just enough of `git config --global` to make
	# steps/git-defaults.sh fully testable and idempotent, backed by a
	# plain key=value file instead of the real gitconfig format.
	local store="$TEST_TMP/fake-gitconfig-store"
	: >"$store"
	cat >"$FAKE_BIN/git" <<EOF
#!/usr/bin/env bash
store="$store"
if [ "\$1" = "config" ] && [ "\$2" = "--global" ]; then
	shift 2
	if [ "\$1" = "--get" ]; then
		key="\$2"
		grep -F "\${key}=" "\$store" 2>/dev/null | tail -n1 | cut -d= -f2-
		exit \${PIPESTATUS[0]:-1}
	else
		key="\$1"
		val="\$2"
		tmp="\$(mktemp)"
		grep -Fv "\${key}=" "\$store" >"\$tmp" 2>/dev/null || true
		mv "\$tmp" "\$store"
		printf '%s=%s\n' "\$key" "\$val" >>"\$store"
		exit 0
	fi
fi
echo "fake git: unsupported invocation: \$*" >&2
exit 1
EOF
	chmod +x "$FAKE_BIN/git"
}

bd_common_teardown() {
	[ -n "${TEST_TMP:-}" ] && rm -rf -- "$TEST_TMP"
}

# Writes a fake package manager binary into FAKE_BIN that records every
# invocation (one line per call, args space separated) into CALL_LOG, and
# optionally "installs" packages by creating stub binaries in FAKE_BIN so a
# following `command -v` check succeeds.
#
# stub_pkg_manager <name> [bin-to-create-on-install ...]
stub_pkg_manager() {
	local name="$1"
	shift
	CALL_LOG="$TEST_TMP/${name}.calls"
	export CALL_LOG
	: >"$CALL_LOG"

	local create_bins=("$@")
	local script="$FAKE_BIN/$name"
	{
		printf '#!/usr/bin/env bash\n'
		printf 'printf "%%s\\n" "$*" >> %q\n' "$CALL_LOG"
		local b
		for b in "${create_bins[@]}"; do
			printf 'touch %q\n' "$FAKE_BIN/$b"
			printf 'chmod +x %q\n' "$FAKE_BIN/$b"
		done
		printf 'exit 0\n'
	} >"$script"
	chmod +x "$script"
}

# Restricts PATH so no *package manager* from the host is visible.
#
# Package-manager detection must be able to assert that none is present, but an
# Ubuntu runner has a real apt-get on PATH -- which made "no manager found" and
# "detects a stubbed brew" pass in a bare Alpine container and fail in CI.
#
# Emptying PATH outright is too blunt: the library needs `date` for logging and
# the teardown needs `rm`, so the tests died with 127 instead of asserting.
# Instead, build a sanitised directory of symlinks to the utilities the code
# genuinely uses, deliberately excluding every package manager, and put the
# stub directory ahead of it.
bd_isolate_path() {
	local sysbin="$TEST_TMP/sysbin"
	mkdir -p "$sysbin"

	# Everything the libraries and bats itself need. Package managers are
	# absent by design; that absence is the condition under test.
	local tool
	for tool in sh bash env printf date rm mkdir mktemp cat cp mv ln touch 		sed awk grep df chmod sort head tail wc tr cut dirname basename 		sleep id uname stat find xargs tee; do
		local resolved
		resolved="$(PATH="$REAL_PATH" command -v "$tool" 2>/dev/null || true)"
		if [ -n "$resolved" ] && [ ! -e "$sysbin/$tool" ]; then
			ln -sf "$resolved" "$sysbin/$tool"
		fi
	done

	export PATH="$FAKE_BIN:$sysbin"
}

# Restores the PATH captured by bd_common_setup.
bd_restore_path() {
	export PATH="$REAL_PATH"
}
