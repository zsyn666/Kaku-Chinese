#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../state_common.sh
source "$SCRIPT_DIR/state_common.sh"

assert_contains() {
	local value="$1"
	local expected="$2"
	if [[ "$value" != *"$expected"* ]]; then
		printf 'expected output to contain: %s\n' "$expected" >&2
		return 1
	fi
}

assert_not_contains() {
	local value="$1"
	local unexpected="$2"
	if [[ "$value" == *"$unexpected"* ]]; then
		printf 'expected output not to contain: %s\n' "$unexpected" >&2
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

output="$(KAKU_CONFIG_UPDATE_LANGUAGE=en print_config_update_highlights "$SCRIPT_DIR" 12 15)"

assert_not_contains "$output" "  v12"
assert_not_contains "$output" "  v13"
assert_not_contains "$output" "  v14"
assert_not_contains "$output" "Shell integration compatibility is improved for SSH"
assert_contains "$output" "Starship prompt and AI shell hooks are more reliable"
assert_contains "$output" "regenerate the"
assert_contains "$output" "managed script correctly"
assert_contains "$output" "Yazi now follows Kaku dark and light themes automatically"

english_output="$(KAKU_CONFIG_UPDATE_LANGUAGE=en print_config_update_highlights "$SCRIPT_DIR" 20 21)"
assert_contains "$english_output" "Tab and pane close confirmation now support Never, Smart, and Always"
assert_contains "$english_output" "Kaku Dark now reports a dark terminal background to Hermes"
assert_not_contains "$english_output" "标签页和面板关闭确认"

chinese_output="$(KAKU_CONFIG_UPDATE_LANGUAGE=zh print_config_update_highlights "$SCRIPT_DIR" 20 21)"
assert_contains "$chinese_output" "标签页和面板关闭确认现在支持"
assert_contains "$chinese_output" "Kaku Dark 现在会向 Hermes 正确报告深色终端背景"
assert_not_contains "$chinese_output" "Tab and pane close confirmation now support"

state_test_dir="$(mktemp -d)"
trap 'rm -rf "$state_test_dir"' EXIT
HOME="$state_test_dir/home"
CONFIG_DIR="$state_test_dir/config"
STATE_FILE="$CONFIG_DIR/state.json"
LEGACY_VERSION_FILE="$CONFIG_DIR/.kaku_config_version"
LEGACY_GEOMETRY_FILE="$CONFIG_DIR/.kaku_window_geometry"
CURRENT_CONFIG_VERSION=22
mkdir -p "$CONFIG_DIR"
printf '%s\n' '{"config_version":21,"managed_shell":"fish","window_geometry":{"width":120,"height":40},"window_position":{"x":10,"y":20,"screen_id":7},"future_setting":{"enabled":true}}' >"$STATE_FILE"

assert_eq "$(read_managed_shell)" "fish"
persist_config_version
assert_eq "$(read_managed_shell)" "fish"
grep -Eq '"config_version"[[:space:]]*:[[:space:]]*22' "$STATE_FILE"
assert_eq "$(plutil -extract window_geometry.width raw -expect integer -o - -- "$STATE_FILE")" "120"
assert_eq "$(plutil -extract window_position.screen_id raw -expect integer -o - -- "$STATE_FILE")" "7"
assert_eq "$(plutil -extract future_setting.enabled raw -expect bool -o - -- "$STATE_FILE")" "true"

printf '%s\n' '{}' >"$STATE_FILE"
persist_config_version 22
assert_eq "$(plutil -extract config_version raw -expect integer -o - -- "$STATE_FILE")" "22"

printf '%s\n' '  {"window_position":{"x":30,"y":40},"future_setting":{"enabled":true}}' >"$STATE_FILE"
persist_config_version 23
assert_eq "$(read_config_version)" "23"
grep -Eq '"x"[[:space:]]*:[[:space:]]*30' "$STATE_FILE"
grep -Eq '"future_setting"[[:space:]]*:' "$STATE_FILE"

printf '%s\n' '{"metadata":{"config_version":null},"future_setting":{"enabled":true}}' >"$STATE_FILE"
persist_config_version 24
assert_eq "$(read_config_version)" "24"
grep -Eq '"config_version"[[:space:]]*:[[:space:]]*24' "$STATE_FILE"
grep -Eq '"metadata"[[:space:]]*:' "$STATE_FILE"
grep -Eq '"config_version"[[:space:]]*:[[:space:]]*null' "$STATE_FILE"
assert_eq "$(plutil -extract config_version raw -expect integer -o - -- "$HOME/.config/kaku/state.json")" "24"

echo "config_update_highlights smoke test passed"
