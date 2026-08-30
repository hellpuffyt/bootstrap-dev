#!/usr/bin/env bats

load 'test_helper'

setup() {
	bd_common_setup
	. "$ROOT/lib/log.sh"
	. "$ROOT/lib/preflight.sh"
}

teardown() {
	bd_common_teardown
}

@test "preflight_check_disk_space passes with a low minimum" {
	BOOTSTRAP_MIN_DISK_MB=1 run preflight_check_disk_space "$TEST_TMP"
	[ "$status" -eq 0 ]
}

@test "preflight_check_disk_space fails with an absurdly high minimum" {
	BOOTSTRAP_MIN_DISK_MB=999999999 run preflight_check_disk_space "$TEST_TMP"
	[ "$status" -eq 1 ]
}

@test "preflight_check_network is skipped via env override" {
	BOOTSTRAP_SKIP_NETWORK_CHECK=1 run preflight_check_network "example.invalid"
	[ "$status" -eq 0 ]
}

@test "preflight_check_network fails against an unreachable host" {
	run preflight_check_network "this-host-does-not-exist.invalid"
	[ "$status" -eq 1 ]
}

@test "preflight_check_sudo passes when skipped via env override" {
	BOOTSTRAP_SKIP_SUDO_CHECK=1 run preflight_check_sudo
	[ "$status" -eq 0 ]
}

@test "preflight_check_conflicts passes when no conflicting binaries are declared" {
	run preflight_check_conflicts
	[ "$status" -eq 0 ]
}

@test "preflight_check_conflicts fails when a declared binary already exists" {
	touch "$FAKE_BIN/rogue-tool"
	chmod +x "$FAKE_BIN/rogue-tool"
	BOOTSTRAP_CONFLICT_BINS="rogue-tool" run preflight_check_conflicts
	[ "$status" -eq 1 ]
}

@test "preflight_run stops at the first failing check" {
	BOOTSTRAP_MIN_DISK_MB=999999999 BOOTSTRAP_SKIP_NETWORK_CHECK=1 BOOTSTRAP_SKIP_SUDO_CHECK=1 run preflight_run
	[ "$status" -eq 1 ]
}

@test "preflight_run passes when all checks are satisfied or skipped" {
	BOOTSTRAP_MIN_DISK_MB=1 BOOTSTRAP_SKIP_NETWORK_CHECK=1 BOOTSTRAP_SKIP_SUDO_CHECK=1 run preflight_run
	[ "$status" -eq 0 ]
}
