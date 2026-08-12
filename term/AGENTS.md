# Terminal Agent Guide

## Scope

`term/` contains terminal emulation core behavior, including screen state, escape sequence handling, selection, and PTY-facing terminal semantics.

## Where to Look

- `term/src/terminal.rs` - main terminal state and event handling
- `term/src/terminalstate/` - detailed state transitions
- `term/src/screen.rs` - screen buffer behavior
- `term/src/test/` - terminal-core regression tests (`selection.rs`, `csi.rs`, `c0.rs`, `c1.rs`, `core_emulation.rs`)
- `crates/wezterm-escape-parser/` - escape sequence parsing (CSI/OSC/ESC/APC); `term` consumes it, it does not live under `term/src/`
- `kaku-gui/src/selection.rs` and `kaku-gui/src/termwindow/selection.rs` - selection and copy behavior (GUI side, not `term`)

## Practical Rules

- Prefer existing parser and state helpers over ad hoc escape handling.
- Keep GUI assumptions out of terminal core.
- Preserve screen buffer invariants and add focused tests for behavior changes.
- Keep normal-screen and alternate-screen behavior distinct; wheel scrolling and inline AI status must not corrupt terminal state.
- Preserve selection and cursor invariants that GUI overlays and inline assistant status depend on.
- For TUI re-render corruption, reduce the report to an ANSI transcript and cover cursor motion plus erasure in terminal-core tests before changing GUI code. Full-line erase of a physical row must also leave wrap state consistent, especially for styled prompts that previously wrapped.

## Verification

- Compile checks: run `make check`.
- Terminal logic changes: run `make test` or the narrow cargo nextest filter for the affected behavior.
- Cross-crate behavior: also inspect `mux/AGENTS.md` and `kaku-gui/AGENTS.md`.

## Cross-References

- `../mux/AGENTS.md` - owns panes and terminal instances.
- `../kaku-gui/AGENTS.md` - renders terminal surfaces.
- `../termwiz/AGENTS.md` - terminal UI primitives.
