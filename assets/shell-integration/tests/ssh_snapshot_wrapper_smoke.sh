#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SHELL_DIR/../.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if ! command -v zsh >/dev/null 2>&1; then
  echo "warning: zsh not found; skipping ssh snapshot wrapper smoke" >&2
  exit 0
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kaku-ssh-snapshot-smoke.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

tmp_home="$tmp_dir/home"
tmp_vendor="$tmp_dir/vendor"
tmp_bin="$tmp_dir/bin"
mkdir -p "$tmp_home" "$tmp_vendor" "$tmp_bin"

for plugin in fast-syntax-highlighting zsh-autosuggestions zsh-completions zsh-z; do
  mkdir -p "$tmp_vendor/$plugin"
done

if [[ -f "$REPO_ROOT/assets/vendor/starship.toml" ]]; then
  cp "$REPO_ROOT/assets/vendor/starship.toml" "$tmp_vendor/starship.toml"
else
  printf '# test starship config\n' >"$tmp_vendor/starship.toml"
fi

HOME="$tmp_home" \
  KAKU_INIT_INTERNAL=1 \
  KAKU_SKIP_TOOL_BOOTSTRAP=1 \
  KAKU_SKIP_TERMINFO_BOOTSTRAP=1 \
  KAKU_VENDOR_DIR="$tmp_vendor" \
  bash "$SHELL_DIR/setup_zsh.sh" --update-only >/dev/null

kaku_zsh="$tmp_home/.config/kaku/zsh/kaku.zsh"
[[ -f "$kaku_zsh" ]] || fail "kaku.zsh was not generated"

cat >"$tmp_bin/ssh" <<'EOF'
#!/bin/sh
printf 'TERM=%s\n' "${TERM-}"
for arg in "$@"; do
  printf 'ARG=<%s>\n' "$arg"
done
EOF
chmod +x "$tmp_bin/ssh"

snapshot="$tmp_dir/ssh.snapshot.zsh"
HOME="$tmp_home" \
  PATH="$tmp_bin:$PATH" \
  TERM=xterm-256color \
  KAKU_ZSH="$kaku_zsh" \
  SNAPSHOT="$snapshot" \
  zsh -fc '
    alias ssh="ssh -p 2200"
    source "$KAKU_ZSH"
    functions ssh > "$SNAPSHOT"
  ' >/dev/null

if grep -Fq '_kaku_wrapped_ssh' "$snapshot"; then
  fail "captured ssh wrapper still depends on _kaku_wrapped_ssh"
fi

output="$({
  HOME="$tmp_home" \
    PATH="$tmp_bin:$PATH" \
    SNAPSHOT="$snapshot" \
    zsh -fc '
      source "$SNAPSHOT"
      TERM=kaku ssh '\''semi;colon'\'' '\''$(printf SENTINEL)'\''
    '
} 2>&1)" || {
  printf '%s\n' "$output" >&2
  fail "snapshot-restored ssh wrapper failed"
}

grep -Fqx 'TERM=xterm-256color' <<<"$output" \
  || fail "snapshot-restored wrapper did not apply the TERM fallback"
grep -Fqx 'ARG=<semi;colon>' <<<"$output" \
  || fail "semicolon argument was not preserved literally"
grep -Fqx 'ARG=<$(printf SENTINEL)>' <<<"$output" \
  || fail "command-substitution-shaped argument was not preserved literally"

# Helper: run a live (non-snapshot) zsh with the generated integration and
# print what the fake ssh binary received.
live_ssh() {
  # $1 = setup script (alias definitions etc.), rest = env assignments
  local setup="$1"; shift
  HOME="$tmp_home" \
    PATH="$tmp_bin:$PATH" \
    TERM=xterm-256color \
    KAKU_ZSH="$kaku_zsh" \
    env "$@" \
    zsh -fc "
      $setup
      source \"\$KAKU_ZSH\"
      TERM=kaku ssh probe-host
    " 2>&1
}

# Live shell keeps the user's alias flags (the snapshot path above is allowed
# to drop them, the live path is not).
output="$(live_ssh 'alias ssh="ssh -p 2200"')" || true
grep -Fqx 'ARG=<-p>' <<<"$output" && grep -Fqx 'ARG=<2200>' <<<"$output" \
  || fail "live wrapper dropped the alias flags"

# An env-prefix alias must still reach ssh instead of failing on the
# assignment word.
output="$(live_ssh 'alias ssh="LC_ALL=C ssh"')" || true
grep -Fqx 'ARG=<probe-host>' <<<"$output" \
  || fail "env-prefix ssh alias did not reach ssh"

# 1Password agent socket injects IdentitiesOnly=yes exactly once...
output="$(live_ssh '' SSH_AUTH_SOCK=/tmp/1password/agent.sock)" || true
grep -Fqx 'ARG=<IdentitiesOnly=yes>' <<<"$output" \
  || fail "1Password socket did not inject IdentitiesOnly=yes"

# ...but not when the user already passed it or opted out.
output="$(HOME="$tmp_home" PATH="$tmp_bin:$PATH" TERM=xterm-256color \
  KAKU_ZSH="$kaku_zsh" SSH_AUTH_SOCK=/tmp/1password/agent.sock \
  zsh -fc 'source "$KAKU_ZSH"; TERM=kaku ssh -oIdentitiesOnly=no probe-host' 2>&1)"
grep -Fqx 'ARG=<IdentitiesOnly=yes>' <<<"$output" \
  && fail "IdentitiesOnly=yes was injected despite an explicit user setting"
output="$(live_ssh '' SSH_AUTH_SOCK=/tmp/1password/agent.sock KAKU_SSH_SKIP_1PASSWORD_FIX=1)" || true
grep -Fqx 'ARG=<IdentitiesOnly=yes>' <<<"$output" \
  && fail "IdentitiesOnly=yes was injected despite KAKU_SSH_SKIP_1PASSWORD_FIX=1"

# The TERM fix honors its opt-out toggle.
output="$(live_ssh '' KAKU_SSH_SKIP_TERM_FIX=1)" || true
grep -Fqx 'TERM=kaku' <<<"$output" \
  || fail "KAKU_SSH_SKIP_TERM_FIX=1 did not keep TERM untouched"

# mosh gets the same TERM fallback (wrapper only defined when mosh exists,
# so the fake binary must be on PATH before the integration is sourced).
cat >"$tmp_bin/mosh" <<'EOF'
#!/bin/sh
printf 'TERM=%s\n' "${TERM-}"
EOF
chmod +x "$tmp_bin/mosh"
output="$(HOME="$tmp_home" PATH="$tmp_bin:$PATH" TERM=xterm-256color \
  KAKU_ZSH="$kaku_zsh" \
  zsh -fc 'source "$KAKU_ZSH"; TERM=kaku mosh probe-host' 2>&1)"
grep -Fqx 'TERM=xterm-256color' <<<"$output" \
  || fail "mosh wrapper did not apply the TERM fallback"

echo "ssh snapshot wrapper smoke test passed"
