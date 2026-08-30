#!/usr/bin/env bats

load 'test_helper'

setup() {
	bd_common_setup
	. "$ROOT/lib/log.sh"
	. "$ROOT/lib/editfile.sh"
	TARGET="$TEST_TMP/dotfile"
}

teardown() {
	bd_common_teardown
}

@test "managed_block_apply creates a new file with the block" {
	run managed_block_apply "$TARGET" "demo" "export FOO=bar"
	[ "$status" -eq 0 ]
	[ -f "$TARGET" ]
	grep -qF '# >>> bootstrap-dev:demo >>>' "$TARGET"
	grep -qF 'export FOO=bar' "$TARGET"
	grep -qF '# <<< bootstrap-dev:demo <<<' "$TARGET"
}

@test "managed_block_apply appends to an existing file without a block" {
	printf 'existing line\n' >"$TARGET"
	managed_block_apply "$TARGET" "demo" "export FOO=bar"
	grep -qF 'existing line' "$TARGET"
	grep -qF 'export FOO=bar' "$TARGET"
}

@test "applying the same content ten times leaves exactly one block" {
	local i
	for i in $(seq 1 10); do
		managed_block_apply "$TARGET" "demo" "export FOO=bar" || true
	done
	local count
	count="$(grep -c '# >>> bootstrap-dev:demo >>>' "$TARGET")"
	[ "$count" -eq 1 ]
	count="$(grep -c 'export FOO=bar' "$TARGET")"
	[ "$count" -eq 1 ]
}

@test "applying identical content a second time reports no change (exit 1)" {
	managed_block_apply "$TARGET" "demo" "export FOO=bar"
	run managed_block_apply "$TARGET" "demo" "export FOO=bar"
	[ "$status" -eq 1 ]
}

@test "applying different content updates the block in place" {
	managed_block_apply "$TARGET" "demo" "export FOO=bar"
	managed_block_apply "$TARGET" "demo" "export FOO=baz"
	grep -qF 'export FOO=baz' "$TARGET"
	! grep -qF 'export FOO=bar' "$TARGET"
	local count
	count="$(grep -c '# >>> bootstrap-dev:demo >>>' "$TARGET")"
	[ "$count" -eq 1 ]
}

@test "two different block ids coexist independently" {
	managed_block_apply "$TARGET" "one" "export ONE=1"
	managed_block_apply "$TARGET" "two" "export TWO=2"
	grep -qF 'export ONE=1' "$TARGET"
	grep -qF 'export TWO=2' "$TARGET"
	managed_block_apply "$TARGET" "one" "export ONE=changed"
	grep -qF 'export ONE=changed' "$TARGET"
	grep -qF 'export TWO=2' "$TARGET"
}

@test "managed_block_current returns empty for a missing file" {
	run managed_block_current "$TEST_TMP/does-not-exist" "demo"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "managed_block_current returns the current body" {
	managed_block_apply "$TARGET" "demo" "line one
line two"
	run managed_block_current "$TARGET" "demo"
	[[ "$output" == *"line one"* ]]
	[[ "$output" == *"line two"* ]]
}

@test "DRY_RUN=1 does not create a new file" {
	DRY_RUN=1 run managed_block_apply "$TARGET" "demo" "export FOO=bar"
	[ "$status" -eq 0 ]
	[ ! -e "$TARGET" ]
}

@test "DRY_RUN=1 does not modify an existing file" {
	printf 'original\n' >"$TARGET"
	local before
	before="$(cat "$TARGET")"
	DRY_RUN=1 run managed_block_apply "$TARGET" "demo" "export FOO=bar"
	[ "$status" -eq 0 ]
	[ "$(cat "$TARGET")" = "$before" ]
}

@test "DRY_RUN=1 still reports no-op as exit 1 when content already matches" {
	managed_block_apply "$TARGET" "demo" "export FOO=bar"
	DRY_RUN=1 run managed_block_apply "$TARGET" "demo" "export FOO=bar"
	[ "$status" -eq 1 ]
}
