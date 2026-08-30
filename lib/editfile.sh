#!/usr/bin/env bash
# lib/editfile.sh - idempotent managed-block edits to dotfiles
#
# A "managed block" is a region of a file delimited by marker comments:
#
#   # >>> bootstrap-dev:web >>>
#   export EDITOR=vim
#   # <<< bootstrap-dev:web <<<
#
# managed_block_apply replaces the block if the markers already exist, or
# appends a new block if they do not. Running it any number of times with
# the same content leaves exactly one block in the file.
#
# Public API:
#   managed_block_render <id> <content>          -> block text on stdout
#   managed_block_current <file> <id>            -> current block body on stdout (empty if absent)
#   managed_block_apply <file> <id> <content>     -> writes file, returns 0 if changed, 1 if unchanged
#     Honors DRY_RUN=1: prints the change and returns without writing.

if [ -n "${BOOTSTRAP_EDITFILE_SH_LOADED:-}" ]; then
	return
fi
BOOTSTRAP_EDITFILE_SH_LOADED=1

_managed_block_start() { printf '# >>> bootstrap-dev:%s >>>' "$1"; }
_managed_block_end() { printf '# <<< bootstrap-dev:%s <<<' "$1"; }

managed_block_render() {
	local id="$1" content="$2"
	_managed_block_start "$id"
	printf '\n'
	printf '%s\n' "$content"
	_managed_block_end "$id"
	printf '\n'
}

# Prints the current body (without markers) of the managed block in $1
# identified by $2. Prints nothing if the file or block does not exist.
managed_block_current() {
	local file="$1" id="$2"
	[ -f "$file" ] || return 0
	local start end
	start="$(_managed_block_start "$id")"
	end="$(_managed_block_end "$id")"
	awk -v start="$start" -v end="$end" '
		$0 == start { inside = 1; next }
		$0 == end   { inside = 0; next }
		inside      { print }
	' "$file"
}

managed_block_apply() {
	local file="$1" id="$2" content="$3"
	local start end
	start="$(_managed_block_start "$id")"
	end="$(_managed_block_end "$id")"

	local new_block
	new_block="$(managed_block_render "$id" "$content")"

	local dry="${DRY_RUN:-0}"
	local existing=0
	[ -f "$file" ] && existing=1

	local source="$file"
	if [ "$existing" -ne 1 ]; then
		source="/dev/null"
	fi

	local tmp
	tmp="$(mktemp)"

	if [ "$existing" -eq 1 ] && grep -Fxq -- "$start" "$file" 2>/dev/null; then
		awk -v start="$start" -v end="$end" -v block="$new_block" '
			$0 == start { print block; inside = 1; next }
			$0 == end   { inside = 0; next }
			inside      { next }
			{ print }
		' "$source" >"$tmp"
	else
		cat -- "$source" >"$tmp"
		# Ensure exactly one blank line separates existing content from the
		# new block, without leaving leading blank lines in an empty file.
		if [ -s "$tmp" ]; then
			printf '\n' >>"$tmp"
		fi
		printf '%s\n' "$new_block" >>"$tmp"
	fi

	if [ "$existing" -eq 1 ] && cmp -s -- "$file" "$tmp"; then
		rm -f "$tmp"
		return 1
	fi

	if [ "$dry" = "1" ]; then
		log_info "[dry-run] would update managed block '$id' in $file"
		if command -v diff >/dev/null 2>&1; then
			diff -u -- "$source" "$tmp" 2>/dev/null | sed 's/^/  /' || true
		fi
		rm -f "$tmp"
		return 0
	fi

	mkdir -p "$(dirname -- "$file")"
	mv -- "$tmp" "$file"
	return 0
}
