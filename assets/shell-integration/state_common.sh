# Shared shell state helpers for first-run and config updates.

read_bundled_config_version() {
	local script_dir="$1"
	local version_file="$script_dir/config_version.txt"

	if [[ ! -f "$version_file" ]]; then
		echo "Error: missing bundled config version file: $version_file" >&2
		return 1
	fi

	local version
	version="$(tr -d '[:space:]' < "$version_file" || true)"
	if [[ "$version" =~ ^[0-9]+$ ]]; then
		printf '%s\n' "$version"
		return 0
	fi

	echo "Error: invalid bundled config version in $version_file" >&2
	return 1
}

config_update_highlight_language() {
	local explicit="${KAKU_CONFIG_UPDATE_LANGUAGE:-${KAKU_UPDATE_LANGUAGE:-}}"
	case "$explicit" in
		zh* | ZH* | cn | CN | 中文)
			printf 'zh\n'
			return
			;;
		en* | EN*)
			printf 'en\n'
			return
			;;
	esac

	local locale="${LC_ALL:-} ${LC_MESSAGES:-} ${LANG:-}"
	case "$locale" in
		*zh* | *ZH*)
			printf 'zh\n'
			;;
		*)
			printf 'en\n'
			;;
	esac
}

detect_config_highlight_language() {
	local highlight="$1"
	if [[ "$highlight" == *[一-龥]* ]]; then
		printf 'zh\n'
	else
		printf 'en\n'
	fi
}

print_config_update_highlights() {
	local script_dir="$1"
	local from_version="$2"
	local target_version="$3"
	local highlights_file="$script_dir/config_update_highlights.tsv"
	local target_language="${4:-$(config_update_highlight_language)}"
	local found=1
	local seen=$'\n'
	local wrap_width=72
	local current_group=""

	local GREEN=$'\033[0;32m'
	local DIM=$'\033[2m'
	local NC=$'\033[0m'

	if [[ ! -f "$highlights_file" ]]; then
		return 1
	fi

	local group_count=0
	local prev_v=""
	while IFS=$'\t' read -r version highlight; do
		if [[ -z "${version:-}" || "$version" == \#* || -z "${highlight:-}" ]]; then
			continue
		fi
		if [[ "$(detect_config_highlight_language "$highlight")" != "$target_language" ]]; then
			continue
		fi
		if [[ "$version" =~ ^[0-9]+$ ]] && (( version > from_version && version <= target_version )); then
			if [[ "$version" != "$prev_v" ]]; then
				(( group_count++ ))
				prev_v="$version"
			fi
		fi
	done < "$highlights_file"

	while IFS=$'\t' read -r version highlight; do
		if [[ -z "${version:-}" || "$version" == \#* || -z "${highlight:-}" ]]; then
			continue
		fi
		if [[ "$(detect_config_highlight_language "$highlight")" != "$target_language" ]]; then
			continue
		fi

		if [[ "$version" =~ ^[0-9]+$ ]] && (( version > from_version && version <= target_version )); then
			if [[ "$seen" == *$'\n'"$highlight"$'\n'* ]]; then
				continue
			fi
			seen+="$highlight"$'\n'
			found=0

			if (( group_count > 1 )) && [[ "$version" != "$current_group" ]]; then
				current_group="$version"
				printf "  ${DIM}─── v%s ${NC}\n" "$version"
			fi

			printf '%s\n' "$highlight" | fold -s -w "$wrap_width" | \
				sed "1s|^|  ${GREEN}✦${NC} |; 2,\$s|^|    |"
		fi
	done < "$highlights_file"

	return "$found"
}

read_config_version() {
	if [[ ! -f "$STATE_FILE" ]]; then
		printf '%s\n' "0"
		return
	fi

	local version
	version="$(/usr/bin/plutil -extract config_version raw -expect integer -o - -- "$STATE_FILE" 2>/dev/null || true)"
	if [[ "$version" =~ ^[0-9]+$ ]]; then
		printf '%s\n' "$version"
	else
		printf '%s\n' "0"
	fi
}

read_managed_shell() {
	if [[ ! -f "$STATE_FILE" ]]; then
		return
	fi

	local managed_shell
	managed_shell="$(/usr/bin/plutil -extract managed_shell raw -expect string -o - -- "$STATE_FILE" 2>/dev/null || true)"
	case "$managed_shell" in
		zsh|fish) printf '%s\n' "$managed_shell" ;;
	esac
}

mirror_completed_state_to_default() {
	local target_version="$1"
	local managed_shell="${2:-}"
	local default_config_dir="${HOME:-}/.config/kaku"
	local default_state_file="$default_config_dir/state.json"

	if [[ -z "${HOME:-}" || "$CONFIG_DIR" == "$default_config_dir" ]]; then
		return
	fi

	mkdir -p "$default_config_dir"
	local mirror_tmp
	mirror_tmp="${default_state_file}.tmp.$$"
	if [[ -f "$default_state_file" ]] &&
		/usr/bin/plutil -convert json -o "$mirror_tmp" -- "$default_state_file" 2>/dev/null; then
		:
	else
		printf '{"config_version":%s}\n' "$target_version" >"$mirror_tmp"
	fi

	if ! /usr/bin/plutil -replace config_version -integer "$target_version" "$mirror_tmp" 2>/dev/null; then
		if ! /usr/bin/plutil -insert config_version -integer "$target_version" "$mirror_tmp" 2>/dev/null; then
			if [[ "$(tr -d '[:space:]' <"$mirror_tmp")" == "{}" ]]; then
				printf '{"config_version":%s}\n' "$target_version" >"$mirror_tmp"
			else
				rm -f "$mirror_tmp"
				return 1
			fi
		fi
	fi
	if [[ "$managed_shell" == "zsh" || "$managed_shell" == "fish" ]]; then
		if ! /usr/bin/plutil -replace managed_shell -string "$managed_shell" "$mirror_tmp" 2>/dev/null; then
			/usr/bin/plutil -insert managed_shell -string "$managed_shell" "$mirror_tmp" 2>/dev/null || {
				rm -f "$mirror_tmp"
				return 1
			}
		fi
	fi
	/usr/bin/plutil -convert json -r "$mirror_tmp" >/dev/null
	mv "$mirror_tmp" "$default_state_file"
}

record_config_version_success() {
	local target_version="$1"
	printf '%s\n' "$target_version" >"$LEGACY_VERSION_FILE"
	if ! mirror_completed_state_to_default "$target_version" "$(read_managed_shell || true)"; then
		printf 'warning: could not mirror completed Kaku state to the default config path\n' >&2
	fi
	return 0
}

persist_config_version() {
	local target_version="${1:-$CURRENT_CONFIG_VERSION}"
	mkdir -p "$CONFIG_DIR"
	if [[ ! "$target_version" =~ ^[0-9]+$ ]]; then
		printf 'invalid config version: %s\n' "$target_version" >&2
		return 1
	fi

	# Treat state as structured JSON. Text regexes can accidentally update a
	# nested config_version or discard fields when whitespace precedes `{`.
	# plutil ships with macOS and preserves every unknown object member while
	# replacing or inserting the top-level version.
	if [[ -f "$STATE_FILE" && ! -f "$LEGACY_GEOMETRY_FILE" ]]; then
		local state_tmp
		state_tmp="${STATE_FILE}.tmp.$$"
		if /usr/bin/plutil -convert json -o "$state_tmp" -- "$STATE_FILE" 2>/dev/null; then
			if ! /usr/bin/plutil -replace config_version -integer "$target_version" "$state_tmp" 2>/dev/null; then
				if ! /usr/bin/plutil -insert config_version -integer "$target_version" "$state_tmp" 2>/dev/null; then
					if [[ "$(tr -d '[:space:]' <"$state_tmp")" == "{}" ]]; then
						printf '{"config_version":%s}\n' "$target_version" >"$state_tmp"
					else
						rm -f "$state_tmp"
						return 1
					fi
				fi
			fi
			/usr/bin/plutil -convert json -r "$state_tmp" >/dev/null
			mv "$state_tmp" "$STATE_FILE"
			record_config_version_success "$target_version"
			return
		fi
		rm -f "$state_tmp"
	fi

	local width height geometry_json managed_shell managed_shell_json
	width=""
	height=""
	geometry_json=""
	managed_shell="$(read_managed_shell || true)"
	managed_shell_json=""

	if [[ -f "$STATE_FILE" ]]; then
		width="$(sed -nE 's/.*"width"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$STATE_FILE" | head -n 1)"
		height="$(sed -nE 's/.*"height"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$STATE_FILE" | head -n 1)"
	fi

	if [[ -z "$width" || -z "$height" ]] && [[ -f "$LEGACY_GEOMETRY_FILE" ]]; then
		local geometry
		geometry="$(tr -d '[:space:]' < "$LEGACY_GEOMETRY_FILE" || true)"
		local a b c d
		IFS=',' read -r a b c d <<< "$geometry"
		if [[ "${c:-}" =~ ^[0-9]+$ && "${d:-}" =~ ^[0-9]+$ ]]; then
			width="$c"
			height="$d"
		elif [[ "${a:-}" =~ ^[0-9]+$ && "${b:-}" =~ ^[0-9]+$ ]]; then
			width="$a"
			height="$b"
		fi
	fi

	if [[ -n "$width" && -n "$height" ]]; then
		geometry_json="$(printf ',\n  "window_geometry": {\n    "width": %s,\n    "height": %s\n  }' "$width" "$height")"
	fi
	if [[ "$managed_shell" == "zsh" || "$managed_shell" == "fish" ]]; then
		managed_shell_json="$(printf ',\n  "managed_shell": "%s"' "$managed_shell")"
	fi

	printf "{\n  \"config_version\": %s%s%s\n}\n" "$target_version" "$managed_shell_json" "$geometry_json" >"$STATE_FILE"

	# Keep a legacy version marker for users still loading older bundled kaku.lua.
	# This avoids repeated first-run onboarding after upgrades.
	record_config_version_success "$target_version"
	rm -f "$LEGACY_GEOMETRY_FILE"
}

detect_login_shell() {
	if [[ -n "${SHELL:-}" && -x "${SHELL:-}" ]]; then
		printf '%s\n' "$SHELL"
		return
	fi

	local current_user resolved_shell passwd_entry
	current_user="${USER:-}"
	if [[ -z "$current_user" ]]; then
		current_user="$(id -un 2>/dev/null || true)"
	fi

	if [[ -n "$current_user" ]] && command -v dscl &>/dev/null; then
		resolved_shell="$(dscl . -read "/Users/$current_user" UserShell 2>/dev/null | awk '/UserShell:/ { print $2 }')"
		if [[ -n "$resolved_shell" && -x "$resolved_shell" ]]; then
			printf '%s\n' "$resolved_shell"
			return
		fi
	fi

	if [[ -n "$current_user" ]] && command -v getent &>/dev/null; then
		passwd_entry="$(getent passwd "$current_user" 2>/dev/null || true)"
		resolved_shell="${passwd_entry##*:}"
		if [[ -n "$resolved_shell" && -x "$resolved_shell" ]]; then
			printf '%s\n' "$resolved_shell"
			return
		fi
	fi

	if [[ -x "/bin/zsh" ]]; then
		printf '%s\n' "/bin/zsh"
	else
		printf '%s\n' "/bin/sh"
	fi
}
