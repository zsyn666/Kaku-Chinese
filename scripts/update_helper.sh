#!/bin/bash
set -euo pipefail

TARGET_APP="$1"
NEW_APP="$2"
WORK_DIR="$3"
LOG_FILE="$WORK_DIR/update.log"

strip_trailing_slashes() {
  local p="$1"
  while [[ "$p" == */ ]]; do
    p="${p%/}"
  done
  printf '%s\n' "$p"
}
TARGET_APP_NORM=$(strip_trailing_slashes "$TARGET_APP")
NEW_APP_NORM=$(strip_trailing_slashes "$NEW_APP")
# Use normalized paths consistently for all later path joins and file operations.
TARGET_APP="$TARGET_APP_NORM"
NEW_APP="$NEW_APP_NORM"
BACKUP_APP="${TARGET_APP}.backup.$(date +%s)"
TARGET_GUI="$TARGET_APP/Contents/MacOS/kaku-gui"
TARGET_CLI="$TARGET_APP/Contents/MacOS/kaku"

# Validate that paths end with Kaku.app for safety (allow trailing slashes).
# Final component match mirrors Rust Path::ends_with("Kaku.app") semantics.
# After stripping trailing slashes, the final component must be Kaku.app
if [[ ! "$TARGET_APP_NORM" == */Kaku.app && ! "$TARGET_APP_NORM" == Kaku.app ]]; then
    echo "Error: TARGET_APP must end with Kaku.app" >&2
    exit 1
fi
if [[ ! "$NEW_APP_NORM" == */Kaku.app && ! "$NEW_APP_NORM" == Kaku.app ]]; then
    echo "Error: NEW_APP must end with Kaku.app" >&2
    exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG_FILE"
}

rollback() {
  log "restore from backup"
  /bin/rm -rf "$TARGET_APP" || true
  if [[ -d "$BACKUP_APP" ]]; then
    /bin/mv "$BACKUP_APP" "$TARGET_APP" || true
  fi
}

read_persisted_managed_shell() {
  local config_base state_file managed_shell
  config_base="${XDG_CONFIG_HOME:-}"
  if [[ -z "$config_base" ]]; then
    if [[ -z "${HOME:-}" ]]; then
      return
    fi
    config_base="$HOME/.config"
  fi
  state_file="$config_base/kaku/state.json"
  if [[ ! -f "$state_file" ]]; then
    return
  fi
  managed_shell="$(/usr/bin/plutil -extract managed_shell raw -expect string -o - -- "$state_file" 2>/dev/null || true)"
  case "$managed_shell" in
    zsh|fish) printf '%s\n' "$managed_shell" ;;
  esac
}

install_kaku_wrapper_fallback() {
  local home_dir shell_candidate wrapper_shell wrapper_path wrapper_dir
  home_dir="${HOME:-}"
  if [[ -z "$home_dir" ]]; then
    return 1
  fi

  shell_candidate="${KAKU_TARGET_SHELL:-}"
  if [[ -z "$shell_candidate" ]]; then
    shell_candidate="$(read_persisted_managed_shell || true)"
  fi
  if [[ -z "$shell_candidate" ]]; then
    shell_candidate="${SHELL:-/bin/zsh}"
  fi
  case "$shell_candidate" in
    *fish|fish)
      wrapper_shell="fish"
      ;;
    *)
      wrapper_shell="zsh"
      ;;
  esac

  wrapper_path="$home_dir/.config/kaku/$wrapper_shell/bin/kaku"
  wrapper_dir="${wrapper_path%/*}"
  /bin/mkdir -p "$wrapper_dir"

  /bin/cat >"$wrapper_path" <<EOF
#!/bin/bash
set -euo pipefail

if [[ -n "\${KAKU_BIN:-}" && -x "\${KAKU_BIN}" ]]; then
  exec "\${KAKU_BIN}" "\$@"
fi

for candidate in \
  "$TARGET_CLI" \
  "/Applications/Kaku.app/Contents/MacOS/kaku" \
  "\${HOME:-}/Applications/Kaku.app/Contents/MacOS/kaku"; do
  if [[ -n "\$candidate" && -x "\$candidate" ]]; then
    exec "\$candidate" "\$@"
  fi
done

  echo "kaku: Kaku.app not found. Expected /Applications/Kaku.app." >&2
  exit 127
EOF

  /bin/chmod 755 "$wrapper_path"
  printf '%s\n' "$wrapper_path"
}

log "start apply update"

# pgrep/pkill -f treats the pattern as a regex, but TARGET_GUI/TARGET_CLI may contain
# regex metacharacters. Match against the full command line via ps and shell pattern
# literals instead. Use ps -axww so long command lines are not truncated.
collect_kaku_pids() {
  ps -axww -o pid= -o args= | while read -r pid args; do
    [[ -z "$pid" ]] && continue
    [[ "$pid" == "$$" ]] && continue
    case "$args" in
      *"$TARGET_GUI"* | *"$TARGET_CLI"* ) printf '%s\n' "$pid" ;;
    esac
  done | sort -u
}

KAKU_PIDS=""
for _ in $(seq 1 20); do
  KAKU_PIDS=$(collect_kaku_pids | tr '\n' ' ')
  if [[ -z "$KAKU_PIDS" ]]; then
    break
  fi
  for pid in $KAKU_PIDS; do
    if ! kill -TERM "$pid" 2>/dev/null; then
      log "failed to send TERM to pid $pid"
    fi
  done
  sleep 1
done
# Final force-kill if any remain
KAKU_PIDS=$(collect_kaku_pids | tr '\n' ' ')
if [[ -n "$KAKU_PIDS" ]]; then
  for pid in $KAKU_PIDS; do
    if ! kill -KILL "$pid" 2>/dev/null; then
      log "failed to send KILL to pid $pid"
    fi
  done
fi

if [[ -d "$TARGET_APP" ]]; then
  log "backup existing app"
  /bin/mv "$TARGET_APP" "$BACKUP_APP"
fi

log "copy new app"
if ! /usr/bin/ditto "$NEW_APP" "$TARGET_APP"; then
  rollback
  exit 1
fi

/usr/bin/xattr -cr "$TARGET_APP" >/dev/null 2>&1 || true

if [[ -d "$BACKUP_APP" ]]; then
  /bin/rm -rf "$BACKUP_APP" || true
fi

log "refresh shell integration"
if "$TARGET_CLI" init --update-only >>"$LOG_FILE" 2>&1; then
  log "shell integration refreshed"
else
  log "warning: failed to refresh shell integration via kaku init"
  if fallback_wrapper_path="$(install_kaku_wrapper_fallback)"; then
    log "installed fallback kaku wrapper at ${fallback_wrapper_path:-~/.config/kaku/<unknown>/bin/kaku}"
  else
    log "warning: failed to install fallback kaku wrapper"
  fi
fi

# Write update completed marker with new version
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$TARGET_APP/Contents/Info.plist" 2>/dev/null || echo "")
if [[ -n "$NEW_VERSION" ]]; then
  DATA_DIR="${XDG_DATA_HOME:-$HOME/Library/Application Support}/kaku"
  /bin/mkdir -p "$DATA_DIR" 2>/dev/null
  printf '%s\n' "$NEW_VERSION" > "$DATA_DIR/update_completed"
  log "wrote update_completed marker: $NEW_VERSION"
fi

log "relaunch app"
sleep 1

# Verify the new app exists before attempting to open
if [[ ! -d "$TARGET_APP" ]]; then
  log "error: TARGET_APP does not exist after copy: $TARGET_APP"
  exit 1
fi

# Try multiple methods to relaunch the app
log "attempting to relaunch: $TARGET_APP"

# Method 1: open command with path (most reliable)
if /usr/bin/open "$TARGET_APP" 2>>"$LOG_FILE"; then
  log "relaunch via open path succeeded"
else
  log "open path failed (exit code: $?), trying open -a"
  sleep 1
  # Method 2: open by app name
  if /usr/bin/open -a Kaku 2>>"$LOG_FILE"; then
    log "relaunch via open -a succeeded"
  else
    log "open -a failed (exit code: $?), trying osascript"
    sleep 1
    # Method 3: AppleScript as last resort
    /usr/bin/osascript -e 'tell application "Kaku" to activate' 2>>"$LOG_FILE" || log "osascript also failed"
  fi
fi

log "done"
/bin/rm -f "$0" >/dev/null 2>&1 || true
/bin/rm -rf "$WORK_DIR" >/dev/null 2>&1 || true
