# Config Agent Guide

The `config` crate owns config loading, Lua integration, schema behavior, proxy settings, versioned defaults, and AI configuration.

## Scope

`config` controls:
- loading user and bundled configs
- Lua execution and binding lifecycle
- schema mapping between Lua and Rust
- config subscriptions and reload behavior
- AI model, fast-model, and proxy settings consumed by GUI and CLI flows
- versioned default config and release readiness checks

## Where to Look

- `config/src/config.rs`: load/parse flow
- `config/src/lib.rs`: config API and subscriptions
- `config/src/proxy.rs`: proxy configuration used by AI and network-facing flows
- `config/src/version.rs`: config version and migration-related constants
- `assets/macos/Kaku.app/Contents/Resources/kaku.lua`: bundled fallback config

## Config TUI (`kaku/src/config_tui/` and `kaku/src/tui_core/`)

The config TUI is the interactive terminal UI for editing Kaku config. It lives in the `kaku` CLI crate, not the `config` crate.

- `kaku/src/config_tui/` - TUI app: `mod.rs` (form state and main loop), `ui.rs` (rendering)
- `kaku/src/tui_core/` - shared TUI primitives, currently `theme.rs` only (`accent`, `bg`, `muted`, `panel`, `primary`, `red`, `success`, `text_fg`)
- `tui_core::theme` is consumed by `config_tui/ui.rs`, `ai_config/tui/ui.rs`, and `tui_splash.rs`. New primitives shared by more than one TUI flow belong in `tui_core`, not copied per feature.

## AI Config TUI (`kaku/src/ai_config/`)

The AI config TUI lives in the `kaku` CLI crate and shares terminal UI primitives with `config_tui`.

- Keep `fast_model`, primary model, and proxy settings aligned between CLI config, GUI AI chat, and documentation.
- Do not duplicate form widgets or debounce behavior outside `kaku/src/tui_core/`.
- Verify AI config changes against both config parsing and the visible TUI flow.

## Practical Rules

- Loading priority: user config first, bundled config second.
- Keep reload-safe behavior for startup hooks and subscriptions.
- Avoid introducing config paths that bypass existing precedence rules.
- `KAKU_CONFIG_FILE` is an output, not an input. Config loading exports it (`config/src/config.rs`) and `effective_config_file_path()` (`config/src/lib.rs`), the GUI single-instance check (`kaku-gui/src/main.rs`), `assets/shell-integration/setup_{zsh,fish}.sh`, and the bundled `kaku.lua` all read it back. Do not turn it into a config path override; the only supported override is `--config-file` (`CONFIG_FILE_OVERRIDE`).
- Keep bundled fallback config authoritative at `assets/macos/Kaku.app/Contents/Resources/kaku.lua`.
- Preserve compatibility with runtime reload callers that trigger `config::reload()` from GUI-side signals.
- The current `config_version` is whatever `assets/shell-integration/config_version.txt` says; never trust a number written in a doc (this line once said 24 while the release was at 26). Any version bump must update bundled config, release checks, docs, and migration expectations together, and add a row to `docs/config-versions.md`.
- New config fields are user-facing behavior. Keep them out of pure cleanup/refactor patches unless the maintainer explicitly approved the product change, and update bundled defaults plus documentation in the same change when they do land.
- Keep alternate-screen wheel scroll behavior configurable; terminal and GUI defaults must not diverge.

## Bundled kaku.lua Pitfalls

- **200-locals hard limit.** LuaJIT caps a chunk at 200 local variables, and the top-level
  chunk of `assets/macos/Kaku.app/Contents/Resources/kaku.lua` is already at capacity.
  Adding one more top-level `local` makes the whole config fail to load at startup. New
  helper functions and values must be nested inside existing functions or tables. After any
  edit, verify the file still loads:

  ```bash
  luajit -e "assert(loadfile('assets/macos/Kaku.app/Contents/Resources/kaku.lua'))"
  ```

- **PaneInformation is fields-only.** In title-formatting paths (`format-tab-title`,
  `format-window-title`), the `pane` object is a `PaneInformation` userdata that exposes
  fields only, no methods. Method-style access such as `pane:get_foreground_process_name()`
  or capability probes like `if pane.get_xxx then` do not error; they silently evaluate to
  nil, so the guarded branch never runs (#485 shipped dead code this way). Use the
  documented fields, prefer the `WEZTERM_PROG` user var for the running command, and treat
  argv-derived titles as untrusted (argv can leak environment values).

## Cross-References

- [`kaku-gui/AGENTS.md`](../kaku-gui/AGENTS.md) - GUI config consumers and reload signals.
- [`lua-api-crates/AGENTS.md`](../lua-api-crates/AGENTS.md) - Lua APIs that expose config values.
- [`mux/AGENTS.md`](../mux/AGENTS.md) - Alert propagation for config changes.
