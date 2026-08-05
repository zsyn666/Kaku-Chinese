#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="${KAKU_TEST_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

assert_file_exists() {
	if [[ ! -f "$1" ]]; then
		printf 'expected file to exist: %s\n' "$1" >&2
		return 1
	fi
}

assert_file_absent() {
	if [[ -e "$1" ]]; then
		printf 'expected file to be absent: %s\n' "$1" >&2
		return 1
	fi
}

assert_eq() {
	local actual="$1"
	local expected="$2"
	if [[ "$actual" != "$expected" ]]; then
		printf 'expected %s, got %s\n' "$expected" "$actual" >&2
		return 1
	fi
}

run_case() {
	local name="$1"
	local init_exit="$2"
	local case_root="$TEST_ROOT/$name"
	local resources="$case_root/Resources"
	local macos="$case_root/MacOS"
	local home="$case_root/home"
	local xdg="$case_root/xdg"

	mkdir -p "$resources" "$macos" "$home" "$xdg"
	cp "$REPO_ROOT/assets/shell-integration/first_run.sh" "$resources/first_run.sh"
	cp "$REPO_ROOT/assets/shell-integration/state_common.sh" "$resources/state_common.sh"
	cp "$REPO_ROOT/assets/shell-integration/config_version.txt" "$resources/config_version.txt"
	printf '#!/bin/bash\nexit 0\n' >"$resources/setup_zsh.sh"
	chmod +x "$resources/setup_zsh.sh"

	printf '#!/bin/bash\nif [[ "${1:-}" == "init" ]]; then exit %s; fi\nexit 0\n' "$init_exit" >"$macos/kaku"
	chmod +x "$macos/kaku"

	printf '\n' | HOME="$home" XDG_CONFIG_HOME="$xdg" SHELL=/usr/bin/true TERM=xterm \
		KAKU_SKIP_TOOL_BOOTSTRAP=1 bash "$resources/first_run.sh" >/dev/null
}

run_case failed 1
assert_file_absent "$TEST_ROOT/failed/xdg/kaku/state.json"
assert_file_absent "$TEST_ROOT/failed/home/.config/kaku/state.json"

run_case successful 0
primary_state="$TEST_ROOT/successful/xdg/kaku/state.json"
mirror_state="$TEST_ROOT/successful/home/.config/kaku/state.json"
assert_file_exists "$primary_state"
assert_file_exists "$mirror_state"
expected_version="$(tr -d '[:space:]' <"$REPO_ROOT/assets/shell-integration/config_version.txt")"
assert_eq "$(plutil -extract config_version raw -expect integer -o - -- "$primary_state")" "$expected_version"
assert_eq "$(plutil -extract config_version raw -expect integer -o - -- "$mirror_state")" "$expected_version"

echo "first_run state smoke test passed"
