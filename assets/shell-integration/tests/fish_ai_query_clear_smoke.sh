#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/common.sh"

fail() {
  echo "fish_ai_query_clear: $*" >&2
  exit 1
}

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kaku-fish-ai-query.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

HOME="$tmp_dir/home"
mkdir -p "$HOME"

vendor_dir="$tmp_dir/vendor"
create_stub_vendor_dir "$vendor_dir"

setup_out=""
setup_status=0
setup_out="$(
  HOME="$HOME" \
  KAKU_INIT_INTERNAL=1 \
  KAKU_SKIP_TOOL_BOOTSTRAP=1 \
  KAKU_SKIP_TERMINFO_BOOTSTRAP=1 \
  KAKU_VENDOR_DIR="$vendor_dir" \
  bash "$REPO_ROOT/assets/shell-integration/setup_fish.sh" --update-only 2>&1
)" || setup_status=$?
if [[ "$setup_status" -ne 0 ]]; then
  echo "$setup_out" >&2
  fail "setup_fish.sh failed with exit $setup_status"
fi

kaku_fish="$HOME/.config/kaku/fish/kaku.fish"
[[ -f "$kaku_fish" ]] || fail "managed init file not created at $kaku_fish"
grep -Fq 'if set -q TERM_PROGRAM; and test "$TERM_PROGRAM" = "Kaku"; and command -q starship' \
  "$kaku_fish" \
  || fail "generated kaku.fish did not preserve the runtime Kaku session guard"
grep -Fq 'set -l capability_file "$HOME/.config/kaku/ai_inline_capability"' \
  "$kaku_fish" \
  || fail "generated kaku.fish did not read the inline AI capability"

if command -v fish >/dev/null 2>&1; then
  fish_bin="$(command -v fish)"
  starship_stub_dir="$tmp_dir/starship-bin"
  starship_marker="$tmp_dir/starship-initialized"
  mkdir -p "$starship_stub_dir"
  cp /dev/null "$starship_marker"
  cat >"$starship_stub_dir/starship" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "init" ]]; then
  printf 'echo initialized >> "$KAKU_STARSHIP_TEST_MARKER"\n'
fi
EOF
  chmod +x "$starship_stub_dir/starship"

  env \
    HOME="$HOME" \
    TERM_PROGRAM="Apple_Terminal" \
    KAKU_STARSHIP_TEST_MARKER="$starship_marker" \
    PATH="$starship_stub_dir:/usr/bin:/bin" \
    "$fish_bin" --no-config "$kaku_fish"
  [[ ! -s "$starship_marker" ]] \
    || fail "generated kaku.fish initialized Starship outside Kaku"

  env \
    HOME="$HOME" \
    TERM_PROGRAM="Kaku" \
    KAKU_STARSHIP_TEST_MARKER="$starship_marker" \
    PATH="$starship_stub_dir:/usr/bin:/bin" \
    "$fish_bin" --no-config "$kaku_fish"
  [[ "$(cat "$starship_marker")" == "initialized" ]] \
    || fail "generated kaku.fish did not initialize Starship inside Kaku"
else
  echo "warning: fish not found; skipping runtime Starship guard check" >&2
fi

function_body="$(
  awk '
    /^function __kaku_ai_query_execute$/ { in_fn = 1 }
    in_fn { print }
    in_fn && /^end$/ { exit }
  ' "$kaku_fish"
)"

[[ "$function_body" == *'if __kaku_set_ai_user_var kaku_ai_query "[mode:$mode] $query"'* ]] \
  || fail "kaku_ai_query user var is missing or not mode-tagged"
[[ "$function_body" == *'commandline -r ""'* ]] \
  || fail "submitted # query buffer is not cleared"

sequence_ok="$(
  awk '
    /^function __kaku_ai_query_execute$/ { in_fn = 1 }
    in_fn && /if __kaku_set_ai_user_var kaku_ai_query "\[mode:\$mode\] \$query"/ { saw_user_var = 1 }
    in_fn && saw_user_var && /commandline -r ""/ { saw_clear = 1 }
    in_fn && saw_clear && /commandline -f repaint/ { print "ok"; exit }
    in_fn && /^end$/ { exit }
  ' "$kaku_fish"
)"

[[ "$sequence_ok" == "ok" ]] \
  || fail "expected query send -> commandline clear -> repaint order"

echo "fish_ai_query_clear smoke test passed"
