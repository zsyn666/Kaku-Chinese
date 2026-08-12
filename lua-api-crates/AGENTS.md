# Lua API Crates Agent Guide

`lua-api-crates/` contains Rust-to-Lua API bindings for user configuration scripts.

## Scope

`lua-api-crates/` exposes runtime capabilities to Lua, including:
- mux and pane controls
- window and spawn helpers
- ssh and system integration helpers
- utility modules like logging, time, and filesystem

## Where to Look

- `lua-api-crates/mux/`: pane/tab control APIs
- `lua-api-crates/window-funcs/`: window-level APIs
- `lua-api-crates/spawn-funcs/`: process spawn APIs
- `lua-api-crates/ssh-funcs/`: SSH-related Lua APIs

## Practical Rules

- API behavior here is user-facing and breaking-change sensitive.
- Be careful with user-var and event-facing APIs, since GUI hooks and config reload signals rely on those event paths.
- Keep proxy, config reload, and user-var event semantics stable for AI and automation workflows that observe Lua-facing state.
- `PaneInformation` (used in title-formatting events) is fields-only userdata: method-style calls and `if pane.get_xxx` probes silently no-op instead of erroring. See "Bundled kaku.lua Pitfalls" in [`config/AGENTS.md`](../config/AGENTS.md) before extending it or its consumers.

## Cross-References

- [`mux/AGENTS.md`](../mux/AGENTS.md) - Mux controls exposed to Lua.
- [`config/AGENTS.md`](../config/AGENTS.md) - Lua config execution environment.
- [`kaku-gui/AGENTS.md`](../kaku-gui/AGENTS.md) - Window functions and GUI integration.
