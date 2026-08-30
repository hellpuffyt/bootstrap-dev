#!/usr/bin/env bats

load 'test_helper'

setup() {
	bd_common_setup
	. "$ROOT/lib/log.sh"
	. "$ROOT/lib/pkg.sh"
}

teardown() {
	bd_common_teardown
}

@test "pkg_detect finds a stubbed apt-get" {
	stub_pkg_manager apt-get
	PKG_MANAGER=""
	# Called directly (not via `run`) because `run` captures output through a
	# subshell, which would discard the PKG_MANAGER assignment we need to see.
	pkg_detect
	[ "$PKG_MANAGER" = "apt" ]
}

@test "pkg_detect finds a stubbed brew" {
	stub_pkg_manager brew
	PKG_MANAGER=""
	pkg_detect
	[ "$PKG_MANAGER" = "brew" ]
}

@test "pkg_detect fails clearly when no manager is present" {
	PKG_MANAGER=""
	run pkg_detect
	[ "$status" -eq 1 ]
	[[ "$output" == *"no supported package manager"* ]]
}

@test "pkg_install dispatches to apt-get with the right arguments" {
	stub_pkg_manager apt-get
	PKG_MANAGER=""
	pkg_install git curl
	[ -f "$CALL_LOG" ]
	run cat "$CALL_LOG"
	[[ "$output" == *"install -y git curl"* ]]
}

@test "pkg_install dispatches to brew without sudo" {
	stub_pkg_manager brew
	PKG_MANAGER=""
	pkg_install node
	run cat "$CALL_LOG"
	[[ "$output" == *"install node"* ]]
}

@test "pkg_install never invokes a package manager that was not stubbed" {
	stub_pkg_manager apt-get
	PKG_MANAGER=""
	# create a decoy dnf on PATH that would fail loudly if ever called
	cat >"$FAKE_BIN/dnf" <<'EOF'
#!/usr/bin/env bash
echo "dnf should never be called" >&2
exit 99
EOF
	chmod +x "$FAKE_BIN/dnf"
	run pkg_install git
	[ "$status" -eq 0 ]
	[[ "$output" != *"should never be called"* ]]
}

@test "pkg_is_installed is true for a binary on PATH" {
	touch "$FAKE_BIN/somebin"
	chmod +x "$FAKE_BIN/somebin"
	run pkg_is_installed somebin
	[ "$status" -eq 0 ]
}

@test "pkg_is_installed is false for a binary not on PATH" {
	run pkg_is_installed definitely-not-a-real-binary
	[ "$status" -eq 1 ]
}

@test "pkg_install with zero packages is a no-op success" {
	run pkg_install
	[ "$status" -eq 0 ]
}
