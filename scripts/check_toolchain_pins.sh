#!/usr/bin/env bash
# Verify every stable-toolchain pin in .github/workflows matches the channel in
# rust-toolchain.toml.
#
# rustup resolves rust-toolchain.toml over whatever the workflow installed, so a
# mismatch silently downgrades CI to a minimal toolchain: `components: clippy`
# and `targets: x86_64-apple-darwin` are installed for the pinned version, then
# cargo runs under the toolchain-file version that has neither. The failures read
# as unrelated ("cargo-clippy is not installed", "can't find crate for `core`"),
# and only the jobs needing an extra component or target go red, so the break
# hides behind passing Cargo Check and Unit Tests.
#
# Exit non-zero when any workflow pin disagrees with rust-toolchain.toml.
#
# Used by CI; also safe to run locally.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

toolchain_file="rust-toolchain.toml"
if [[ ! -f "$toolchain_file" ]]; then
  echo "ERROR: $toolchain_file not found"
  exit 1
fi

expected="$(sed -n 's/^channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$toolchain_file" | head -n1)"
if [[ -z "$expected" ]]; then
  echo "ERROR: could not read channel from $toolchain_file"
  exit 1
fi

status=0
while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  pin="$(printf '%s' "$rest" | sed -n 's/.*toolchain:[[:space:]]*//p')"

  # nightly jobs (rustfmt) intentionally float off the pinned stable channel.
  if [[ "$pin" == "nightly" || "$pin" == nightly-* ]]; then
    continue
  fi

  if [[ "$pin" != "$expected" ]]; then
    echo "ERROR: $file:$lineno pins toolchain $pin but $toolchain_file says $expected"
    status=1
  fi
done < <(grep -rn "toolchain:" .github/workflows || true)

if [[ $status -ne 0 ]]; then
  echo "Bump the workflow pins and $toolchain_file together."
  exit 1
fi

echo "OK: workflow toolchain pins match $toolchain_file ($expected)"
