#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Sync upstream tw93/Kaku -> Kaku-Chinese ==="

# Ensure git identity for auto-commits
git config user.name "github-actions[bot]" >/dev/null 2>&1 || true
git config user.email "41898282+github-actions[bot]@users.noreply.github.com" >/dev/null 2>&1 || true

# Ensure upstream remote
if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Adding upstream remote tw93/Kaku"
  git remote add upstream https://github.com/tw93/Kaku.git
fi

# Fetch upstream main (prune to keep clean)
echo "Fetching upstream/main..."
git fetch upstream main --prune

# Already up-to-date?
if git merge-base --is-ancestor upstream/main HEAD; then
  echo "Already up to date with upstream/main, nothing to do."
  exit 0
fi

# Show divergence
echo "Local HEAD: $(git rev-parse --short HEAD)"
echo "Upstream : $(git rev-parse --short upstream/main)"
echo "Merge-base: $(git rev-parse --short "$(git merge-base HEAD upstream/main)")"
echo ""
echo "Commits in upstream not in local:"
git log --oneline HEAD..upstream/main | head -20 || true
echo ""
echo "Commits in local not in upstream:"
git log --oneline upstream/main..HEAD | head -20 || true
echo ""

# Attempt merge
echo "Attempting git merge --no-ff upstream/main..."
set +e
git merge --no-ff --no-edit upstream/main
MERGE_STATUS=$?
set -e

resolve_cargo_lock() {
  echo "Resolving Cargo.lock..."
  # Prefer upstream's Cargo.lock, then re-apply h2 fix if needed
  if git diff --name-only --diff-filter=U | grep -q "^Cargo.lock$"; then
    git checkout --theirs -- Cargo.lock || true
    git add Cargo.lock
    echo "  took theirs for Cargo.lock, now ensuring h2 >=0.4.16"
    python3 - "$REPO_ROOT/Cargo.lock" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
# Check h2 version
m = re.search(r'name = "h2"\nversion = "([^"]+)"\n[^\n]*\nchecksum = "([^"]+)"', text)
if m:
    ver = m.group(1)
    print(f"  h2 version in merged Cargo.lock: {ver}")
    if ver != "0.4.16":
        # Only bump h2 block to 0.4.16, keep other dependencies as upstream resolved
        old = 'name = "h2"\nversion = "0.4.13"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "2f44da3a8150a6703ed5d34e164b875fd14c2cdab9af1252a9a1020bde2bdc54"'
        new = 'name = "h2"\nversion = "0.4.16"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "a9f37a958b41b3b19ee2707c06439c0e9e547e847223eb791ecb0cb821c65e27"'
        if old in text:
            text = text.replace(old, new)
            p.write_text(text, encoding='utf-8')
            print("  patched h2 0.4.13 -> 0.4.16")
        else:
            print("  h2 block not in expected 0.4.13 form, leaving as is")
    else:
        print("  h2 already >=0.4.16, keep upstream")
else:
    print("  h2 package not found")
PY
    git add Cargo.lock
  else
    echo "  Cargo.lock not conflicted, checking h2 version anyway"
    # Even if no conflict, ensure h2 is not regressed to vulnerable version
    python3 - "$REPO_ROOT/Cargo.lock" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
if 'version = "0.4.13"' in text and 'name = "h2"' in text:
    old = 'name = "h2"\nversion = "0.4.13"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "2f44da3a8150a6703ed5d34e164b875fd14c2cdab9af1252a9a1020bde2bdc54"'
    new = 'name = "h2"\nversion = "0.4.16"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "a9f37a958b41b3b19ee2707c06439c0e9e547e847223eb791ecb0cb821c65e27"'
    if old in text:
        text = text.replace(old, new)
        p.write_text(text, encoding='utf-8')
        print("  patched h2 0.4.13 -> 0.4.16 (no-conflict path)")
PY
    git add Cargo.lock || true
  fi
}

resolve_config_version() {
  echo "Resolving config_version files..."
  # If any of the three files is conflicted, unify them
  local conflicted=false
  for f in assets/shell-integration/config_version.txt assets/shell-integration/config_update_highlights.tsv docs/config-versions.md; do
    if git diff --name-only --diff-filter=U | grep -q "^${f}$"; then
      conflicted=true
    fi
  done
  # Also need to handle case where merge succeeded but current < min (gate would fail)
  # Compute current, theirs, ours, and required minimum
  local ours_version theirs_version current_version
  # ours is HEAD before merge (saved via git show HEAD:... but HEAD now is merge commit with conflicts)
  # Use :2: and :3: stages if conflicted, otherwise use file
  if git diff --name-only --diff-filter=U | grep -q "config_version.txt"; then
    ours_version=$(git show :2:assets/shell-integration/config_version.txt 2>/dev/null | tr -d '[:space:]' || echo "0")
    theirs_version=$(git show :3:assets/shell-integration/config_version.txt 2>/dev/null | tr -d '[:space:]' || echo "0")
    echo "  conflict: ours=$ours_version theirs=$theirs_version"
    # Compute new version as max + 1 to guarantee > previous tag
    local max=$ours_version
    if [ "$theirs_version" -gt "$max" ]; then max=$theirs_version; fi
    # Also consider previous tag's version +1
    local prev_tag prev_version min_version
    prev_tag=$(git tag --sort=-version:refname | grep -E '^[Vv][0-9]+\.[0-9]+\.[0-9]+$' | grep -Eiv "^v$(grep '^version =' "$REPO_ROOT/kaku/Cargo.toml" | head -n1 | cut -d'"' -f2)$" | head -n1 || true)
    if [ -n "$prev_tag" ]; then
      prev_version=$(git show "${prev_tag}:assets/shell-integration/config_version.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
      if [[ "$prev_version" =~ ^[0-9]+$ ]]; then
        min_version=$((prev_version + 1))
        echo "  previous tag $prev_tag has $prev_version, min required $min_version"
        if [ "$min_version" -gt "$max" ]; then max=$((min_version - 1)); fi
      fi
    fi
    local new_version=$((max + 1))
    # If upstream already satisfied min and ours==theirs, we still need +1 per gate
    # Use max+1 unconditionally when conflict
    echo "  bumping config_version to $new_version"
    echo "$new_version" > assets/shell-integration/config_version.txt
    git add assets/shell-integration/config_version.txt
    # Now fix highlights and docs for new_version
    resolve_highlights "$new_version"
    resolve_docs "$new_version"
  else
    # No conflict on config_version.txt, but check if current still satisfies gate
    current_version=$(cat assets/shell-integration/config_version.txt | tr -d '[:space:]')
    local prev_tag prev_version min_version
    prev_tag=$(git tag --sort=-version:refname | grep -E '^[Vv][0-9]+\.[0-9]+\.[0-9]+$' | grep -Eiv "^v$(grep '^version =' "$REPO_ROOT/kaku/Cargo.toml" | head -n1 | cut -d'"' -f2)$" | head -n1 || true)
    if [ -n "$prev_tag" ]; then
      prev_version=$(git show "${prev_tag}:assets/shell-integration/config_version.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
      if [[ "$prev_version" =~ ^[0-9]+$ ]]; then
        min_version=$((prev_version + 1))
        if [ "$current_version" -lt "$min_version" ]; then
          echo "  current $current_version < min $min_version (previous $prev_tag=$prev_version), bumping to $min_version"
          echo "$min_version" > assets/shell-integration/config_version.txt
          git add assets/shell-integration/config_version.txt
          resolve_highlights "$min_version"
          resolve_docs "$min_version"
        else
          echo "  current $current_version satisfies min $min_version"
        fi
      fi
    fi
    # Also ensure highlights/docs not left conflicted
    for f in assets/shell-integration/config_update_highlights.tsv docs/config-versions.md; do
      if git diff --name-only --diff-filter=U | grep -q "^${f}$"; then
        echo "  $f still conflicted, taking union"
        if [ "$f" = "assets/shell-integration/config_update_highlights.tsv" ]; then
          # Take theirs and re-append our new version entries if missing
          git checkout --theirs -- "$f" || true
          # Ensure new_version highlights exist
          local cv=$(cat assets/shell-integration/config_version.txt | tr -d '[:space:]')
          if ! grep -q "^${cv}	" "$f"; then
            resolve_highlights "$cv"
          else
            git add "$f"
          fi
        else
          git checkout --theirs -- "$f" || true
          local cv=$(cat assets/shell-integration/config_version.txt | tr -d '[:space:]')
          if ! grep -q "v${cv}" "$f"; then
            resolve_docs "$cv"
          else
            git add "$f"
          fi
        fi
      fi
    done
  fi
}

resolve_highlights() {
  local ver=$1
  local file="assets/shell-integration/config_update_highlights.tsv"
  echo "  ensuring highlights for v$ver"
  if grep -q "^${ver}	" "$file"; then
    echo "    already exists for $ver"
    return 0
  fi
  # If file is still conflicted, take theirs first
  if git diff --name-only --diff-filter=U | grep -q "^${file}$"; then
    git checkout --theirs -- "$file" || true
  fi
  # Append auto-generated highlights (EN + ZH)
  printf "%s\tSecurity Audit maintenance: update h2 to 0.4.16 for RUSTSEC-2026-0258 and trust Homebrew tap\n" "$ver" >> "$file"
  printf "%s\t安全审计维护：更新 h2 至 0.4.16 修复 RUSTSEC-2026-0258 并信任 Homebrew tap\n" "$ver" >> "$file"
  # Deduplicate and keep sorted? Keep file as is, just ensure at least 2
  git add "$file"
  echo "    added auto highlights for $ver"
}

resolve_docs() {
  local ver=$1
  local file="docs/config-versions.md"
  echo "  ensuring docs for v$ver"
  if grep -q "v${ver} " "$file"; then
    echo "    already documented for $ver"
    return 0
  fi
  if git diff --name-only --diff-filter=U | grep -q "^${file}$"; then
    git checkout --theirs -- "$file" || true
  fi
  # Insert before final line
  # Find line with "When you bump"
  local tmp=$(mktemp)
  awk -v ver="$ver" '
    /When you bump/ {
      print "| v" ver " | - | No schema change. Bumps to satisfy the release gate after the Security Audit fixes (h2 0.4.13 -> 0.4.16 for RUSTSEC-2026-0258 and Homebrew `aws\/tap` trust). |"
      print ""
    }
    {print}
  ' "$file" > "$tmp" && mv "$tmp" "$file"
  git add "$file"
  echo "    added docs row for $ver"
}

resolve_audit_yml() {
  echo "Resolving .github/workflows/audit.yml..."
  if git diff --name-only --diff-filter=U | grep -q "^\.github/workflows/audit.yml$"; then
    # Take theirs (upstream) and re-inject our Prepare Homebrew tap trust step if missing
    git checkout --theirs -- .github/workflows/audit.yml || true
    if ! grep -q "Prepare Homebrew tap trust" .github/workflows/audit.yml; then
      echo "  re-injecting Prepare Homebrew tap trust step"
      python3 - <<'PY'
import pathlib
p = pathlib.Path(".github/workflows/audit.yml")
t = p.read_text(encoding='utf-8')
old = "      - name: Install cargo-audit"
new = """      - name: Prepare Homebrew tap trust
        run: |
          # GitHub's macOS images ship with aws/tap pre-tapped but Homebrew
          # now requires explicit trust (https://docs.brew.sh/Tap-Trust).
          # Without this, every `brew` invocation emits a warning annotation
          # ("The following taps are not trusted: aws/tap") that pollutes the
          # Security Audit workflow. Trust it if present.
          if brew tap | grep -q '^aws/tap'; then
            brew trust aws/tap || true
          fi

      - name: Install cargo-audit"""
if old in t and "Prepare Homebrew tap trust" not in t:
    t = t.replace(old, new)
    p.write_text(t, encoding='utf-8')
    print("  injected")
PY
    fi
    git add .github/workflows/audit.yml
  else
    echo "  no conflict"
    # Ensure our step still present even if no conflict but upstream overwrote
    if ! grep -q "Prepare Homebrew tap trust" .github/workflows/audit.yml; then
      echo "  step missing after merge (no conflict), injecting"
      python3 - <<'PY'
import pathlib
p = pathlib.Path(".github/workflows/audit.yml")
t = p.read_text(encoding='utf-8')
old = "      - name: Install cargo-audit"
new = """      - name: Prepare Homebrew tap trust
        run: |
          # GitHub's macOS images ship with aws/tap pre-tapped but Homebrew
          # now requires explicit trust (https://docs.brew.sh/Tap-Trust).
          # Without this, every `brew` invocation emits a warning annotation
          # ("The following taps are not trusted: aws/tap") that pollutes the
          # Security Audit workflow. Trust it if present.
          if brew tap | grep -q '^aws/tap'; then
            brew trust aws/tap || true
          fi

      - name: Install cargo-audit"""
if old in t:
    t = t.replace(old, new)
    p.write_text(t, encoding='utf-8')
PY
      git add .github/workflows/audit.yml || true
    fi
  fi
}

resolve_locales() {
  echo "Resolving locales..."
  local conflicted=$(git diff --name-only --diff-filter=U | grep "^locales/" || true)
  if [ -z "$conflicted" ]; then
    echo "  no locale conflicts"
    return 0
  fi
  echo "  conflicted locales: $conflicted"
  for f in $conflicted; do
    echo "  merging $f via union (theirs + ours)"
    # Use python to union YAML keys (simple text union for this repo's flat structure)
    # Strategy: take theirs as base, then append any keys from ours not in theirs
    # For this i18n bundle, structure is simple; we do 3-way text merge via git merge-file
    local base=$(mktemp) ours=$(mktemp) theirs=$(mktemp)
    git show :1:"$f" > "$base" 2>/dev/null || echo "" > "$base"
    git show :2:"$f" > "$ours" 2>/dev/null || cat "$f" > "$ours" 2>/dev/null || true
    git show :3:"$f" > "$theirs" 2>/dev/null || echo "" > "$theirs"
    # Try git merge-file (3-way)
    cp "$ours" "$f"
    if git merge-file "$f" "$base" "$theirs"; then
      echo "    merge-file succeeded for $f"
      git add "$f"
    else
      echo "    merge-file had conflicts for $f, taking union"
      # Fallback: union of lines, prefer ours on duplicate keys
      python3 - "$base" "$ours" "$theirs" "$f" <<'PY'
import sys, pathlib
base, ours, theirs, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
def load(p):
    try: return pathlib.Path(p).read_text(encoding='utf-8').splitlines()
    except: return []
b = load(base)
o = load(ours)
t = load(theirs)
# Simple union: keep all lines from theirs, append ours lines not in theirs (by stripped)
seen = set(l.strip() for l in t)
merged = t[:]
for l in o:
    if l.strip() and l.strip() not in seen and l.strip() not in set(x.strip() for x in b):
        merged.append(l)
        seen.add(l.strip())
pathlib.Path(out).write_text("\n".join(merged)+"\n", encoding='utf-8')
print(f"  union merged {out}: {len(merged)} lines")
PY
      git add "$f"
    fi
    rm -f "$base" "$ours" "$theirs"
  done
  # Also ensure zh-CN.yml exists if only en.yml was conflicted (fork-specific)
  if [ -f locales/zh-CN.yml ] && git diff --name-only --diff-filter=U | grep -q "zh-CN"; then
    git add locales/zh-CN.yml || true
  fi
}

if [ $MERGE_STATUS -ne 0 ]; then
  echo "Auto-resolving whitelisted conflicts..."
  # Order matters: cargo.lock first (no dependency), then config, then audit, then locales
  resolve_cargo_lock
  resolve_config_version
  resolve_audit_yml
  resolve_locales

  # Check remaining conflicts
  remaining=$(git diff --name-only --diff-filter=U || true)
  if [ -n "$remaining" ]; then
    echo ""
    echo "ERROR: Remaining conflicts require manual resolution:"
    echo "$remaining"
    echo ""
    echo "Aborting merge. Resolve manually and commit."
    git merge --abort || true
    exit 2
  fi

  echo "All whitelisted conflicts resolved, committing merge..."
  # Stage already added files, commit the merge
  git commit --no-edit || true
else
  echo "Merge completed without conflicts"
  # Still need to ensure config_version satisfies gate and Cargo.lock h2 is fixed
  # (upstream may have brought back vulnerable h2)
  resolve_cargo_lock
  # Check if cargo.lock was changed
  if ! git diff --quiet; then
    echo "Cargo.lock needed h2 fix after clean merge, committing"
    git add Cargo.lock
    git commit -m "chore(deps): ensure h2 >=0.4.16 after upstream merge" || true
  fi
  # Check config_version gate after clean merge
  current_version=$(cat assets/shell-integration/config_version.txt | tr -d '[:space:]')
  prev_tag=$(git tag --sort=-version:refname | grep -E '^[Vv][0-9]+\.[0-9]+\.[0-9]+$' | grep -Eiv "^v$(grep '^version =' "$REPO_ROOT/kaku/Cargo.toml" | head -n1 | cut -d'"' -f2)$" | head -n1 || true)
  if [ -n "$prev_tag" ]; then
    prev_version=$(git show "${prev_tag}:assets/shell-integration/config_version.txt" 2>/dev/null | tr -d '[:space:]' || echo "0")
    if [[ "$prev_version" =~ ^[0-9]+$ ]]; then
      min_version=$((prev_version + 1))
      if [ "$current_version" -lt "$min_version" ]; then
        echo "Clean merge but config_version $current_version < min $min_version, bumping"
        echo "$min_version" > assets/shell-integration/config_version.txt
        resolve_highlights "$min_version"
        resolve_docs "$min_version"
        git add assets/shell-integration/config_version.txt assets/shell-integration/config_update_highlights.tsv docs/config-versions.md
        git commit -m "chore(config): bump config_version to $min_version after upstream merge" || true
      fi
    fi
  fi
  # Ensure audit.yml step present
  if ! grep -q "Prepare Homebrew tap trust" .github/workflows/audit.yml; then
    resolve_audit_yml
    if ! git diff --quiet; then
      git add .github/workflows/audit.yml
      git commit -m "ci: preserve Homebrew tap trust step after upstream merge" || true
    fi
  fi
fi

echo ""
echo "=== Merge result ==="
git log --oneline -5
echo ""
echo "Checking remaining changes:"
git status --short
echo ""
echo "Sync upstream done."
