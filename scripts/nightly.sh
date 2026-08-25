#!/usr/bin/env bash
# nightly.sh - Build a release-grade, notarized preview and publish it as the
# rolling "nightly" GitHub prerelease.
#
# This produces the same artifact quality a normal user expects from a stable
# release (Developer ID signed, notarized, stapled, drag-to-Applications DMG),
# so anyone can download it to test fixes that have landed on main but are not
# yet in a tagged version.
#
# It deliberately does NOT do what scripts/release.sh does: no version bump, no
# V* tag, no Homebrew tap dispatch, no RELEASE_NOTES.md. The version in the app
# stays whatever Cargo.toml currently says.
#
# Usage:
#   ./scripts/nightly.sh                     # build + notarize + publish
#   ./scripts/nightly.sh --upload-only       # skip build/notarize; re-publish existing dist/Kaku.dmg
#   ./scripts/nightly.sh --features=remote    # enable optional cargo features
#
# Requirements (same credentials as scripts/release.sh):
#   - Developer ID Application certificate in Keychain (or KAKU_SIGNING_IDENTITY)
#   - Notarization creds: rcodesign ASC API key or notarytool Keychain profile
#   - gh CLI authenticated (gh auth login)
#
# Environment overrides:
#   PROFILE      release-opt (default, matches stable) or release (faster build)
#   NIGHTLY_TAG  rolling release tag (default: nightly)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GITHUB_REPO="${GITHUB_REPO:-zsyn666/Kaku-Chinese}"
NIGHTLY_TAG="${NIGHTLY_TAG:-nightly}"
PROFILE="${PROFILE:-release-opt}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
DMG_PATH="$OUT_DIR/Kaku.dmg"
DMG_ASSET_NAME="Kaku-nightly.dmg"
DMG_ASSET_PATH="$OUT_DIR/$DMG_ASSET_NAME"
UPLOAD_ONLY=0
FEATURES=""

for arg in "$@"; do
    case "$arg" in
        --upload-only) UPLOAD_ONLY=1 ;;
        --features=*) FEATURES="${arg#--features=}" ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

case "$PROFILE" in
    release | release-opt) ;;
    *) echo "PROFILE must be release or release-opt for a notarizable nightly, got: $PROFILE" >&2; exit 1 ;;
esac

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log() { echo -e "${GREEN}[nightly]${NC} $*"; }
die() { echo -e "${YELLOW}[nightly]${NC} $*" >&2; exit 1; }

# Concurrency guard: only one nightly build at a time per checkout.
mkdir -p "$OUT_DIR"
LOCK="$OUT_DIR/.nightly.lock"
if ! (set -o noclobber; echo $$ > "$LOCK") 2>/dev/null; then
    die "nightly.sh already running (PID $(cat "$LOCK" 2>/dev/null)); remove $LOCK if stale"
fi
trap 'rm -f "$LOCK"' EXIT

# --- Pre-flight (fail before a multi-minute build) ---------------------------

if ! command -v gh >/dev/null 2>&1; then
    die "gh CLI not found. Install from https://cli.github.com/"
fi
if ! gh auth status >/dev/null 2>&1; then
    die "gh CLI not authenticated. Run: gh auth login"
fi

# Tie the nightly tag to the exact commit being built; this also fails loudly
# below if that commit has not been pushed to origin yet.
FULL_SHA=$(git rev-parse HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)

if [[ "$UPLOAD_ONLY" -eq 0 ]]; then
    # Notarization needs either an rcodesign ASC API key or a notarytool profile.
    # Mirror release.sh's lookup so we don't build for minutes then fail at notary.
    have_creds=0
    asc_key="${KAKU_ASC_API_KEY_PATH:-}"
    [[ -z "$asc_key" ]] && asc_key=$(security find-generic-password -s "kaku-asc-api-key-path" -w 2>/dev/null || true)
    if [[ -n "$asc_key" && -f "$asc_key" ]] && command -v rcodesign >/dev/null 2>&1; then
        have_creds=1
    fi
    notary_profile="${KAKU_NOTARYTOOL_PROFILE:-}"
    [[ -z "$notary_profile" ]] && notary_profile=$(security find-generic-password -s "kaku-notarytool-profile" -w 2>/dev/null || true)
    [[ -n "$notary_profile" ]] && have_creds=1
    if [[ "$have_creds" -eq 0 ]]; then
        die "No notarization credentials found (rcodesign ASC API key or notarytool profile). See scripts/notarize.sh for setup."
    fi
fi

# --- Build (Developer ID signed, universal, with DMG) -----------------------

if [[ "$UPLOAD_ONLY" -eq 0 ]]; then
    log "Building $PROFILE universal bundle (Developer ID signed)..."
    # Filter the noisy ranlib warning, but preserve build.sh's exit code via
    # PIPESTATUS — `| grep ... || true` would mask any build failure.
    set +e
    PROFILE="$PROFILE" BUILD_ARCH=universal OUT_DIR="$OUT_DIR" \
        KAKU_REQUIRE_SIGNED_RELEASE=1 CARGO_FEATURES="$FEATURES" \
        ./scripts/build.sh 2>&1 | grep -v 'ranlib: warning:.*has no symbols'
    BUILD_STATUS=${PIPESTATUS[0]}
    set -e
    [[ "$BUILD_STATUS" -ne 0 ]] && die "build.sh failed with exit code $BUILD_STATUS"
    log "Build complete: $OUT_DIR/Kaku.app + $DMG_PATH"

    log "Notarizing and stapling..."
    OUT_DIR="$OUT_DIR" ./scripts/notarize.sh
fi

[[ -f "$DMG_PATH" ]] || die "$DMG_PATH not found. Run without --upload-only to build it."

# Rename for download clarity; cp preserves the stapled notarization ticket.
cp -f "$DMG_PATH" "$DMG_ASSET_PATH"
SIZE=$(du -sh "$DMG_ASSET_PATH" | cut -f1)
log "Asset ready: $DMG_ASSET_PATH ($SIZE)"

# --- Release notes (official frame + auto changelog since last stable) -------
# Matches the visual frame of a tagged release (.github/RELEASE_NOTES.md): logo
# header, tagline, "### Changelog", footer link. The changelog itself is derived
# from commits since the last stable tag — a nightly cannot carry the hand-
# written bilingual prose of a curated release, so it stays English-only and is
# clearly framed as a preview rather than faking a curated 更新日志.

LAST_STABLE=$(git tag -l 'V*' --sort=-v:refname | head -n1 || true)
BUILD_DATE=$(date -u "+%Y-%m-%d")
CARGO_VERSION=$(grep '^version =' "$REPO_ROOT/kaku/Cargo.toml" | head -n1 | cut -d'"' -f2)

if [[ -n "$LAST_STABLE" ]]; then
    LOG_RANGE="$LAST_STABLE..HEAD"
    SINCE_LABEL="$LAST_STABLE"
else
    LOG_RANGE="HEAD~20..HEAD"
    SINCE_LABEL="recent work"
fi

# Clean raw commit subjects toward the curated changelog look: drop non-user-
# facing prefixes, strip the conventional-commit type/scope, move leading issue
# refs to the end, and capitalize the first letter.
CHANGELOG=$(git log "$LOG_RANGE" --no-merges --pretty='%s' \
    | grep -vE '^(docs|chore|ci|build|test|style)(\([^)]*\))?!?: ' \
    | awk '
        {
            line = $0
            sub(/^[a-z]+(\([^)]*\))?!?: /, "", line)
            if (match(line, /^#[0-9]+([ ,]+#[0-9]+)*[ ]+/)) {
                refs = substr(line, 1, RLENGTH)
                rest = substr(line, RLENGTH + 1)
                gsub(/[ ]+$/, "", refs)
                gsub(/[ ]+/, ", ", refs)
                line = rest " (" refs ")"
            }
            line = toupper(substr(line, 1, 1)) substr(line, 2)
            printf "%d. %s\n", ++n, line
        }
    ')
[[ -z "$CHANGELOG" ]] && CHANGELOG="1. Maintenance and internal changes since ${SINCE_LABEL}."

NOTES_FILE=$(mktemp /tmp/kaku-nightly-notes.XXXXXX.md)
trap 'rm -f "$LOCK" "$NOTES_FILE"' EXIT
cat > "$NOTES_FILE" <<EOF
<div align="center">
  <img src="https://raw.githubusercontent.com/tw93/Kaku/main/assets/logo.png" alt="Kaku Logo" width="120" height="120" />
  <h1 style="margin: 12px 0 6px;">Kaku Nightly</h1>
  <p><em>A fast, out-of-the-box terminal built for AI coding.</em></p>
</div>

> Preview build from \`main\` at \`$SHORT_SHA\`, $BUILD_DATE, based on v$CARGO_VERSION. Notarized: open the DMG and drag Kaku to Applications. It may be unstable; for the stable build use the latest tagged release.

### Changelog

$CHANGELOG

> https://github.com/tw93/Kaku
EOF

# --- Publish (recreate so the release date refreshes and it sorts to the top) ---

# Confirm the built commit is on the remote before deleting the old release, so
# a not-yet-pushed HEAD can never leave nightly with no release at all.
if ! gh api "repos/$GITHUB_REPO/commits/$FULL_SHA" >/dev/null 2>&1; then
    die "Commit $SHORT_SHA is not on $GITHUB_REPO yet. Push main before publishing the nightly."
fi

if gh release view "$NIGHTLY_TAG" -R "$GITHUB_REPO" >/dev/null 2>&1; then
    log "Removing previous '$NIGHTLY_TAG' release so the new one sorts to the top..."
    gh release delete "$NIGHTLY_TAG" -R "$GITHUB_REPO" --yes --cleanup-tag
fi

log "Publishing nightly at $SHORT_SHA..."
gh release create "$NIGHTLY_TAG" \
    -R "$GITHUB_REPO" \
    --target "$FULL_SHA" \
    --prerelease \
    --title "Nightly $(date -u '+%Y-%m-%d') ($SHORT_SHA)" \
    --notes-file "$NOTES_FILE" \
    "$DMG_ASSET_PATH"

DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$NIGHTLY_TAG/$DMG_ASSET_NAME"
log "Done."
echo ""
echo "  Download: $DOWNLOAD_URL"
echo ""
