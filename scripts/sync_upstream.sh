#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Sync upstream tw93/Kaku -> Kaku-Chinese ==="

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Adding upstream remote tw93/Kaku"
  git remote add upstream https://github.com/tw93/Kaku.git
fi

echo "Fetching upstream/main..."
git fetch upstream main --prune

if git merge-base --is-ancestor upstream/main HEAD; then
  echo "Already up to date with upstream/main, nothing to do."
  exit 0
fi

echo "Local HEAD: $(git rev-parse --short HEAD)"
echo "Upstream : $(git rev-parse --short upstream/main)"
echo "Merge-base: $(git rev-parse --short "$(git merge-base HEAD upstream/main)")"
echo ""
echo "Commits in upstream not in local:"
git log --oneline HEAD..upstream/main | head -20 || true
echo ""

is_conflicted() {
  git diff --name-only --diff-filter=U | grep -Fxq -- "$1"
}

resolve_release_metadata() {
  # Release notes and the contributor image are upstream-owned/generated files.
  for file in .github/RELEASE_NOTES.md CONTRIBUTORS.svg; do
    if is_conflicted "$file"; then
      echo "Taking upstream version of $file"
      git checkout --theirs -- "$file"
      git add "$file"
    fi
  done
}

resolve_manifest() {
  local file="$1"
  if ! is_conflicted "$file"; then
    return 0
  fi

  echo "Resolving fork manifest $file..."
  local base ours theirs merged
  base=$(mktemp)
  ours=$(mktemp)
  theirs=$(mktemp)
  merged=$(mktemp)
  git show :1:"$file" >"$base"
  git show :2:"$file" >"$ours"
  git show :3:"$file" >"$theirs"

  # Merge non-conflicting upstream changes, but keep fork-specific changes in
  # conflict regions (especially rust-i18n). The package version is selected
  # separately as the newer of the two versions.
  set +e
  git merge-file -p "$ours" "$base" "$theirs" >"$merged"
  local merge_file_status=$?
  set -e
  python3 - "$merged" "$ours" "$theirs" "$file" <<'PY'
import pathlib
import re
import sys

merged_path, ours_path, theirs_path, output_path = sys.argv[1:]
merged = pathlib.Path(merged_path).read_text(encoding="utf-8")
ours = pathlib.Path(ours_path).read_text(encoding="utf-8")
theirs = pathlib.Path(theirs_path).read_text(encoding="utf-8")

# Prefer the fork only inside conflict markers. This leaves all clean upstream
# edits in place instead of replacing the complete manifest with either side.
lines = merged.splitlines()
result = []
i = 0
while i < len(lines):
    if lines[i].startswith("<<<<<<<"):
        i += 1
        fork_lines = []
        while i < len(lines) and not lines[i].startswith("======="):
            fork_lines.append(lines[i])
            i += 1
        while i < len(lines) and not lines[i].startswith(">>>>>>>"):
            i += 1
        if i < len(lines):
            i += 1
        result.extend(fork_lines)
    else:
        result.append(lines[i])
        i += 1

text = "\n".join(result) + "\n"

def package_version(value):
    match = re.search(
        r'^\[package\]\s*\nname = "[^"]+"\s*\nversion = "([^"]+)"',
        value,
        re.MULTILINE,
    )
    return match.group(1) if match else None

def version_key(value):
    try:
        return tuple(int(part) for part in value.split(".")[:3])
    except (AttributeError, ValueError):
        return (0, 0, 0)

fork_version = package_version(ours)
upstream_version = package_version(theirs)
if upstream_version and (not fork_version or version_key(upstream_version) > version_key(fork_version)):
    text = re.sub(
        r'(^\[package\]\s*\nname = "[^"]+"\s*\nversion = )"[^"]+"',
        rf'\g<1>"{upstream_version}"',
        text,
        count=1,
        flags=re.MULTILINE,
    )

pathlib.Path(output_path).write_text(text, encoding="utf-8")
PY
  git add "$file"
  rm -f "$base" "$ours" "$theirs" "$merged"
  if [ "$merge_file_status" -gt 1 ]; then
    echo "Unable to merge $file" >&2
    return 1
  fi
}

resolve_cargo_lock() {
  local file="Cargo.lock"
  if is_conflicted "$file"; then
    echo "Taking upstream Cargo.lock, then checking h2..."
    git checkout --theirs -- "$file"
    git add "$file"
  fi

  # Keep the RustSec fix if upstream ever regresses to the vulnerable version.
  python3 - "$REPO_ROOT/$file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = '''name = "h2"
version = "0.4.13"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "2f44da3a8150a6703ed5d34e164b875fd14c2cdab9af1252a9a1020bde2bdc54"'''
new = '''name = "h2"
version = "0.4.16"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "a9f37a958b41b3b19ee2707c06439c0e9e547e847223eb791ecb0cb821c65e27"'''
if old in text:
    path.write_text(text.replace(old, new), encoding="utf-8")
    print("  patched h2 0.4.13 -> 0.4.16")
PY
  git add "$file"
}

resolve_highlights_conflict() {
  local file="assets/shell-integration/config_update_highlights.tsv"
  if ! is_conflicted "$file"; then
    return 0
  fi
  echo "Merging config highlights from fork and upstream..."
  local ours theirs
  ours=$(mktemp)
  theirs=$(mktemp)
  git show :2:"$file" >"$ours"
  git show :3:"$file" >"$theirs"
  python3 - "$ours" "$theirs" "$file" <<'PY'
import pathlib
import sys

ours, theirs, output = (pathlib.Path(value) for value in sys.argv[1:])
lines = ours.read_text(encoding="utf-8").splitlines()
seen = set(lines)
for line in theirs.read_text(encoding="utf-8").splitlines():
    if line not in seen:
        lines.append(line)
        seen.add(line)
output.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
  git add "$file"
  rm -f "$ours" "$theirs"
}

resolve_config_docs_conflict() {
  local file="docs/config-versions.md"
  if ! is_conflicted "$file"; then
    return 0
  fi
  echo "Merging config version history from fork and upstream..."
  local ours theirs
  ours=$(mktemp)
  theirs=$(mktemp)
  git show :2:"$file" >"$ours"
  git show :3:"$file" >"$theirs"
  python3 - "$ours" "$theirs" "$file" <<'PY'
import pathlib
import sys

ours, theirs, output = (pathlib.Path(value) for value in sys.argv[1:])
upstream_lines = theirs.read_text(encoding="utf-8").splitlines()
upstream_versions = {
    line.split("|", 2)[1].strip()
    for line in upstream_lines
    if line.startswith("| v") and "|" in line[1:]
}
local_rows = [
    line for line in ours.read_text(encoding="utf-8").splitlines()
    if line.startswith("| v")
    and line not in upstream_lines
    and line.split("|", 2)[1].strip() not in upstream_versions
]
if local_rows:
    insert_at = next(
        (index for index, line in enumerate(upstream_lines) if line.startswith("When you bump")),
        len(upstream_lines),
    )
    upstream_lines[insert_at:insert_at] = local_rows
output.write_text("\n".join(upstream_lines) + "\n", encoding="utf-8")
PY
  git add "$file"
  rm -f "$ours" "$theirs"
}

resolve_highlights() {
  local version="$1"
  local file="assets/shell-integration/config_update_highlights.tsv"
  if grep -q "^${version}[[:space:]]" "$file"; then
    return 0
  fi
  echo "Adding automatic config highlights for version $version"
  printf '%s\tSecurity Audit maintenance: update h2 to 0.4.16 and preserve cross-architecture release support\n' "$version" >>"$file"
  printf '%s\t安全审计维护：更新 h2 至 0.4.16 并保持双架构发布支持\n' "$version" >>"$file"
  git add "$file"
}

resolve_docs() {
  local version="$1"
  local file="docs/config-versions.md"
  if grep -q "| v${version} " "$file"; then
    return 0
  fi
  echo "Adding config version history row for v$version"
  local temp
  temp=$(mktemp)
  awk -v version="$version" '
    /^When you bump/ {
      print "| v" version " | - | No schema change. Bumps to satisfy the release gate after automatic upstream synchronization. |"
      print ""
    }
    { print }
  ' "$file" >"$temp"
  mv "$temp" "$file"
  git add "$file"
}

resolve_config_version() {
  echo "Resolving config version files..."
  local current_version ours_version theirs_version
  if is_conflicted "assets/shell-integration/config_version.txt"; then
    ours_version=$(git show :2:assets/shell-integration/config_version.txt | tr -d '[:space:]')
    theirs_version=$(git show :3:assets/shell-integration/config_version.txt | tr -d '[:space:]')
    if [[ ! "$ours_version" =~ ^[0-9]+$ || ! "$theirs_version" =~ ^[0-9]+$ ]]; then
      echo "Invalid config version in merge stages" >&2
      return 1
    fi
    current_version="$ours_version"
    if [ "$theirs_version" -gt "$current_version" ]; then
      current_version="$theirs_version"
    fi
    printf '%s\n' "$current_version" >assets/shell-integration/config_version.txt
    git add assets/shell-integration/config_version.txt
  else
    current_version=$(tr -d '[:space:]' <assets/shell-integration/config_version.txt)
  fi

  if [[ ! "$current_version" =~ ^[0-9]+$ ]]; then
    echo "Invalid current config version: $current_version" >&2
    return 1
  fi

  local release_version previous_tag previous_version minimum_version
  release_version=$(grep '^version =' "$REPO_ROOT/kaku/Cargo.toml" | head -n1 | cut -d'"' -f2)
  previous_tag=$(git tag --sort=-version:refname \
    | grep -E '^[Vv][0-9]+\.[0-9]+\.[0-9]+$' \
    | grep -Eiv "^v${release_version}$" \
    | head -n1 || true)
  if [ -n "$previous_tag" ]; then
    previous_version=$(git show "${previous_tag}:assets/shell-integration/config_version.txt" 2>/dev/null | tr -d '[:space:]' || true)
    if [[ "$previous_version" =~ ^[0-9]+$ ]]; then
      minimum_version=$((previous_version + 1))
      if [ "$current_version" -lt "$minimum_version" ]; then
        current_version="$minimum_version"
        printf '%s\n' "$current_version" >assets/shell-integration/config_version.txt
        git add assets/shell-integration/config_version.txt
        echo "  bumped config_version to $current_version (previous $previous_tag=$previous_version)"
      fi
    fi
  fi

  resolve_highlights_conflict
  resolve_config_docs_conflict
  resolve_highlights "$current_version"
  resolve_docs "$current_version"
}

ensure_audit_step() {
  local file=".github/workflows/audit.yml"
  if is_conflicted "$file"; then
    git checkout --theirs -- "$file"
    git add "$file"
  fi
  if grep -q "Prepare Homebrew tap trust" "$file"; then
    return 0
  fi
  echo "Preserving Homebrew tap trust step in $file"
  python3 - "$file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "      - name: Install cargo-audit"
step = '''      - name: Prepare Homebrew tap trust
        run: |
          # macos-latest may ship with aws/tap pre-tapped but untrusted.
          if brew tap | grep -q '^aws/tap'; then
            brew trust aws/tap || true
          fi

'''
if needle in text:
    path.write_text(text.replace(needle, step + needle, 1), encoding="utf-8")
PY
  git add "$file"
}

resolve_locales() {
  local file base ours theirs merged merge_status
  while read -r file; do
    [ -n "$file" ] || continue
    echo "Resolving locale file $file while preserving fork translations..."
    base=$(mktemp)
    ours=$(mktemp)
    theirs=$(mktemp)
    merged=$(mktemp)
    git show :1:"$file" >"$base" 2>/dev/null || : >"$base"
    git show :2:"$file" >"$ours" 2>/dev/null || : >"$ours"
    git show :3:"$file" >"$theirs" 2>/dev/null || : >"$theirs"
    if [ ! -s "$ours" ]; then
      git checkout --theirs -- "$file"
      git add "$file"
    else
      set +e
      git merge-file -p "$ours" "$base" "$theirs" >"$merged"
      merge_status=$?
      set -e
      python3 - "$merged" "$file" <<'PY'
import pathlib
import sys

source, output = (pathlib.Path(value) for value in sys.argv[1:])
lines = source.read_text(encoding="utf-8").splitlines()
result = []
i = 0
while i < len(lines):
    if lines[i].startswith("<<<<<<<"):
        i += 1
        while i < len(lines) and not lines[i].startswith("======="):
            result.append(lines[i])
            i += 1
        while i < len(lines) and not lines[i].startswith(">>>>>>>"):
            i += 1
        if i < len(lines):
            i += 1
    else:
        result.append(lines[i])
        i += 1
output.write_text("\n".join(result) + "\n", encoding="utf-8")
PY
      git add "$file"
      if [ "$merge_status" -gt 1 ]; then
        echo "Unable to merge locale file $file" >&2
        rm -f "$base" "$ours" "$theirs" "$merged"
        return 1
      fi
    fi
    rm -f "$base" "$ours" "$theirs" "$merged"
  done < <(git diff --name-only --diff-filter=U | grep '^locales/' || true)
}

echo "Attempting git merge --no-ff upstream/main..."
set +e
git merge --no-ff --no-edit upstream/main
merge_status=$?
set -e

if [ "$merge_status" -ne 0 ]; then
  echo "Auto-resolving whitelisted conflicts..."
  resolve_release_metadata
  resolve_manifest kaku/Cargo.toml
  resolve_manifest kaku-gui/Cargo.toml
  resolve_cargo_lock
  resolve_config_version
  ensure_audit_step
  resolve_locales

  remaining=$(git diff --name-only --diff-filter=U || true)
  if [ -n "$remaining" ]; then
    echo ""
    echo "ERROR: Remaining conflicts require manual resolution:"
    echo "$remaining"
    git merge --abort || true
    exit 2
  fi

  git commit --no-edit
else
  # A clean merge is already committed. Apply invariant repairs, if any, as a
  # small follow-up commit rather than silently dropping them.
  resolve_cargo_lock
  resolve_config_version
  ensure_audit_step
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "chore(sync): preserve fork invariants after upstream merge"
  fi
fi

echo ""
echo "=== Merge result ==="
git log --oneline -5
git status --short
echo "Sync upstream done."
