# Kaku Agent Guide

Kaku is a macOS-native terminal emulator derived from WezTerm and shaped around AI-assisted terminal workflows. This guide is the shared operating context for agents working in this repository.

## Repository Map

- `kaku/` - CLI entry points, command flows, and user-facing configuration commands.
- `kaku-gui/` - GUI, rendering, window lifecycle, input, mouse handling, AI chat, and the `k` helper binary.
- `mux/` - tabs, panes, domains, and client/server state.
- `term/` - terminal emulation and screen buffer behavior.
- `termwiz/` - terminal UI primitives.
- `config/` - Lua config loading, schema behavior, proxy settings, and versioned defaults.
- `window/` - platform windowing layer.
- `lua-api-crates/` - Rust-to-Lua API bindings.
- `crates/` - shared utility crates, including Kaku-specific AI helpers.
- `assets/` - app resources, bundled config, shell integration, and vendor assets.
- `scripts/` - build, release, and validation helpers.
- `docs/` - user and developer documentation.
- `.agents/skills/` - the canonical home for project skills, and the only tracked copy: `.claude/` is gitignored here, so `.claude/skills/<name>` are relative symlinks pointing back into `.agents/`. Add a skill under `.agents/skills/` and symlink it, never the reverse, or it ships to nobody. Skills: `release`, `maintainer-sweep`, `product-docs`, `bugs` (proactive multi-entry UX / latent-defect sweep). Exception: `.claude/rules/macos.md` is force-added and tracked despite the ignore rule; anything else added under `.claude/` needs `git add -f` or it stays local-only.
- `.github/workflows/checks.yml` - fast correctness gates on pushes to `main` and on pull requests, with `paths-ignore` for `**.md` and assets, so a docs-only change gets no CI at all. Runs fmt, check, tests, and the log/prompt guards; clippy is scoped to the lint-opt-in crates, not the workspace.
- `.github/workflows/build-validation.yml` - release-shaped universal/bundle builds; runs on build-pipeline changes, daily, or on dispatch. `release.sh` preflight requires its latest run green.
- `.github/workflows/release.yml` - automated release pipeline on tag push (`v*`) or dispatch; builds universal macOS DMG, in-app update zip, checksums, and publishes GitHub Release.
- `.github/workflows/nightly.yml` - daily rolling nightly preview release pipeline.
- `.github/RELEASE_NOTES.md` - source for the GitHub Release title and body.

## Commands

```bash
make fmt
make fmt-check
make check
make test
make dev
make app
./scripts/build.sh
./scripts/check_config_release_readiness.sh
./scripts/check_release_config.sh
./scripts/check_release_notes.sh
```

`make fmt` and `make fmt-check` both shell out to `cargo +nightly fmt`, so they require the nightly toolchain. Use `make app` for GUI, rendering, windowing, and AI overlay verification because it builds the app bundle that users run.

## Working Rules

- Work on the current branch unless the maintainer asks for a branch or worktree.
- Keep changes inside one crate or subsystem when the problem allows it.
- Prefer targeted `rg` searches over repository-wide scans.
- Inspect public APIs and cross-crate boundaries before changing shared behavior.
- Draft issue and PR replies unless the maintainer has already approved the exact public action.
- Do not modify files outside this repository without showing the intended change and getting explicit confirmation.
- Do not add instructions for the removed `website/` tree unless that directory exists in the current worktree.
- The marketing and docs site lives on the `vercel` branch (linked worktree at `~/www/kaku-site`), not on `main`. It follows the design guide at `~/www/kaku-site/DESIGN.md`; verify changes with screenshots at 375px / 1280px and deploy by pushing the `vercel` branch (Vercel serves kaku.fun).
- Keep private credentials, local keychain paths, and machine-specific release notes out of public repository docs.
- **Chinese UI (i18n) is enabled by default.** This fork ships Simplified Chinese (`zh-CN`) as the default UI language via `rust-i18n`. Set `config.language = "en"` in `kaku.lua` to switch back to English. The implementation is derived from upstream PR #362 (`feat(i18n): add Simplified Chinese support via rust-i18n` by MingmouHaochi). New UI surfaces should add corresponding keys to `locales/{en,zh-CN}.yml`.
- **Do not pre-bake provider abstractions in `kaku/src/ai_config/`.** The `mod provider_adapter` trait scaffolding for the 9 AI providers (KakuAssistant, ClaudeCode, Codex, Copilot, Kimi, Antigravity, Gemini, FactoryDroid, OpenClaw) was deleted on 2026-05-26 after sitting at zero implementations for half a year. When provider work is actually needed, start with a single concrete migration (one PR moves KakuAssistant's eight top-level functions out of `tui.rs`, next to the existing provider code in `kaku/src/ai_config/tui/providers/`, not into a new sibling `ai_config/providers/` tree); do not spec out a trait, a `ProviderKind` enum, or stub modules ahead of time. Save Copilot for last because its OAuth flow is the real abstraction stress test.

## Maintainer Follow-up

- For current issue and PR sweeps, read live GitHub state first with `gh issue list` and `gh pr list`; refresh once more before final conclusions or public actions.
- Before commenting on or closing an item, confirm its title, state, and author with `gh issue view` or `gh pr view`.
- Do not close issues or PRs on local green alone. For fixes pushed to `main`, wait for the new GitHub Actions run on `main` to pass before posting fixed/closed replies.
- The rolling `nightly` release is not rebuilt by push. Before sending users to Nightly, run or verify `./scripts/nightly.sh` and confirm `gh release view nightly --json tagName,targetCommitish,publishedAt,assets,url` points at the fix commit and includes `Kaku-nightly.dmg`.
- Default issue-closure pipeline once a fix is verified: commit the fix, refresh the `nightly` release assets per the rule above, reply in the reporter's language with the Nightly download or in-app update path, then propose closure and wait for maintainer confirmation. Do not promise a specific packaged-release date in replies.
- Before pushing `main`, run `git fetch origin main` and verify `origin/main` has not moved unexpectedly. If it moved, stop and review `origin/main..HEAD` before pushing.
- If an accepted PR's equivalent fix lands on `main` outside the contributor branch, state the landed commit and co-author status in the PR before closing it.

## Investigation Order

When scope is incomplete, inspect in this order:

1. User-provided repro, failing command, or failing test.
2. Entry point for the behavior, usually `kaku/src/main.rs`, `kaku/src/cli/`, or `kaku-gui/src/main.rs`.
3. Owning subsystem document and target crate.
4. Immediate cross-crate boundary used by the call path.
5. Narrow tests, fixtures, snapshots, or scripts that reproduce the behavior.

For AI-facing behavior, inspect in this order:

1. CLI and assistant configuration under `kaku/src/ai_config/`, `kaku/src/assistant_config.rs`, and `config/src/proxy.rs`.
2. GUI AI state and transport under `kaku-gui/src/ai_*`, `kaku-gui/src/ai_chat_engine/`, and `kaku-gui/src/cli_chat/`.
3. Overlay UI under `kaku-gui/src/overlay/ai_chat/`.
4. Shared helpers in `crates/kaku-ai-utils/`.

For AI transport bugs around custom `base_url`, keep both proxy paths true: external API hosts should use detected system proxy settings, while loopback, private LAN, link-local, CGNAT/Tailscale-style, `.local`, `NO_PROXY`, and macOS ExceptionsList model endpoints should connect directly. Verify with the macOS system proxy enabled and a loopback or internal OpenAI-compatible smoke before saying it is fixed. Do not claim general SOCKS support unless that transport is actually implemented and verified.

For `Ctrl+letter` not working in a raw-mode TUI (the most common shape: `Ctrl+C` / `Ctrl+R` works in plain shell but not inside a TUI overlay), inspect in this order:

1. AppKit menu `keyEquivalent` intercepting `keyDown` before the terminal sees it. Enable `config.debug_key_events = true`, restart the app, then `grep 'key_event.*CTRL' ~/.local/share/kaku/kaku-gui-log-<pid>.txt`. If the log shows only `key_is_down: false` and no matching `key_is_down: true`, the AppKit menu absorbed the event; do not chase termwiz or PTY.
2. Cooked-mode tests (`cat -v` showing `^C`) do **not** rule out menu interception. Reproduce inside a raw-mode TUI before forming a hypothesis.
3. Only after step 1 rules out menu interception, inspect termwiz encoding (`termwiz/src/input.rs`), then PTY / termios state.

For TUI display corruption after interactive CLIs re-render prompts or selection lists, first capture a minimal ANSI transcript. Add a terminal-core regression around cursor-up (`CSI n A`), full-line erase (`CSI 2K`), cursor-down (`CSI 1B`), wrapped rows, and styled prompt symbols. If the core transcript passes but the built app differs from Terminal.app, inspect GUI width, cell metrics, resize, and wrapping inputs rather than changing terminal semantics blindly.

## Subsystem Guides

| Subsystem | Guide | Scope |
|---|---|---|
| GUI | `kaku-gui/AGENTS.md` | Rendering, window lifecycle, input, mouse |
| Mux | `mux/AGENTS.md` | Tabs, panes, domains, client/server |
| Terminal | `term/AGENTS.md` | VT emulation, screen buffer |
| Config | `config/AGENTS.md` | Lua loading, schema, config reload |
| Termwiz | `termwiz/AGENTS.md` | TUI primitives and widgets |
| Lua API | `lua-api-crates/AGENTS.md` | Rust-to-Lua bindings |
| Crates | `crates/AGENTS.md` | Shared utility crates |
| macOS platform | `.claude/rules/macos.md` | AppKit menu / keyEquivalent traps, menubar init timing |

## Verification

| Change type | Command |
|---|---|
| Rust compile check | `make check` |
| Rust logic change | `make test` |
| Formatting | `make fmt-check` |
| GUI or rendering change | `make app` |
| Config release change | `./scripts/check_config_release_readiness.sh` and `./scripts/check_release_config.sh` |
| Release note change | `./scripts/check_release_notes.sh` |
| Release-adjacent change | `make fmt && make check && make test`, then `make app` |
| `crates/kaku-relay` change | `cargo check --locked --manifest-path crates/kaku-relay/Cargo.toml` (it is in `workspace.exclude`, so `make check` and `make test` never see it; CI's `relay-check` job is the only gate) |

For GUI or rendering issues, read `kaku-gui/AGENTS.md` first and verify with `make app`, not only `make dev`.

## Current Risk Areas

- In-app update replace/restart must confirm on every entry path (menu Check for Updates, menu Restart to Update, toast, CLI direct ZIP, brew cask). Do not set `KAKU_UPDATE_AUTO_CONFIRM` for exploratory menu check; only the overlay-confirmed path may auto-confirm. Sibling entry points tend to regress independently; after changing one path, sweep the matrix and keep the guards in `kaku-gui` (`user_facing_update_events_route_through_confirm`) and `kaku` (`brew_and_direct_paths_confirm_before_replace`) green. Details: `kaku-gui/AGENTS.md` and `.agents/skills/bugs/SKILL.md`.
- AI chat and shell flows are active product surfaces. Preserve `fast_model`, proxy config, inline `#` query status, syntax highlighting, approval flow, and conversation state behavior.
- `config_version` bumps every release; the source of truth is `assets/shell-integration/config_version.txt` and the gate is `scripts/check_release_config.sh`. Config schema changes must update bundled defaults, docs, release checks, and migration behavior together. Per-version history and the migration rule (only keys that existed in the previous released version need migration code) live in `docs/config-versions.md`. Do not hardcode the current version number in agent guides; it goes stale between releases.
- GUI regressions can come from overlay resize, pane split/removal, macOS worker thread lifetime, WebGPU surface reconfigure, tab bar spacing, and alternate-screen wheel scroll behavior.
- Startup performance depends on caching shell user vars, Lua bytecode, early appearance queries, GLSL version, and built-in fonts. Do not invalidate those caches without measurement.
- Notification actions that call back into Kaku should resolve bundled executables relative to the running app, not an assumed system path.
- Known high-regression zones: theme/config TUI initialization (`kaku/src/ai_config/tui/`), macOS window geometry (`window/src/os/macos/window.rs`, `kaku-gui/src/termwindow/resize.rs`), and menubar initialization timing (`window/src/os/macos/menu.rs`). Changes touching these must ship with a regression test or assertion.
- `assets/shell-integration` scripts run in the user's shell, not just at build time. Bash heredocs that generate zsh (e.g. `setup_zsh.sh` writing `kaku.zsh`) expand backticks and `$(...)` at generation time, so escape any that must reach the output literally (#450), and never put `local` outside a function (#432/#441). CI gates this: shellcheck (`--severity=error`, catches SC2168) over the bash scripts plus a `zsh -n` parse check of the generated `kaku.zsh` in the setup smoke.

## Release Notes

Tag format is `V0.x.x`. `scripts/release.sh` is the source of truth for tagged releases. The GitHub Release title comes from the first heading in `.github/RELEASE_NOTES.md`.

Before drafting release notes, read the previous formal release (`gh release view <latest-tag>`) and treat it as the format template: title `V{version} {Codename}` with a one-word codename, a centered logo header with the product tagline, `### Changelog` as numbered `**Label**: one sentence` items, a `### 更新日志` section whose Chinese items map one-to-one by number, and a `> https://github.com/tw93/Kaku` footer. After publishing, add all six positive reactions (`+1`, `laugh`, `heart`, `hooray`, `rocket`, `eyes`) to the release via `gh api` and read them back to confirm; never add `-1` or `confused`.

## Pre-release Runtime Smoke

CI gates fmt/check/clippy/tests but cannot see visual layout, native AppKit, render timing, or shell-in-user-env behavior, which is where most post-release reports come from. The checklist lives in one place: `.agents/skills/release/SKILL.md` «Pre-release smoke checklist», covering macOS window, tab bar, shell setup, AI chat, and render timing, with the issue numbers each item guards and a note on which slices now have automated coverage. Run it by hand in the built `dist/Kaku.app` before tagging, and add the reproduction there when a release fixes a bug outside the list.

Releases that touch windowing, titlebar coloring, tab bar layout, or transparency also need the config matrix in `docs/release-checklist.md`, which enumerates the tab position / tab style / opacity / window state combinations to check by hand and names the `update_titlebar_background()` regression guard.

## Documentation Maintenance

- Single-crate behavior belongs in that crate's `AGENTS.md`.
- Cross-crate behavior should update every affected subsystem guide.
- Build, CI, release, and maintainer workflow changes belong in this root file.
- Shared agent instructions belong in tracked docs. Personal overrides belong in ignored local files.
- One-off review reports, scorecards, and diagnostic snapshots are evidence, not durable project docs. Extract stable rules or verification gates into `AGENTS.md`, `CLAUDE.md`, subsystem guides, scripts, or tests, then remove the transient report.
- Do not hide user-visible behavior changes inside maintainability or cleanup patches. New UI, config fields, defaults, or workflow permissions should be split into their own change unless the maintainer explicitly approved that scope.
