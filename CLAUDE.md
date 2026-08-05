# Kaku

Kaku is a macOS-native terminal emulator derived from WezTerm and tuned for AI-assisted terminal work.

## Agent Entry Points

- Read `AGENTS.md` first for the repository map, subsystem guides, risk areas, and verification matrix.
- Read the nearest crate-level `AGENTS.md` before changing code inside a crate.
- Use `.claude/skills/maintainer-sweep/SKILL.md` for GitHub issue/PR sweeps, CI-gated pushes, public replies, and closure decisions.
- Use `.claude/skills/bugs/SKILL.md` (tracked under `.agents/skills/bugs/`) for proactive latent-bug / multi-entry UX sweeps with no reported symptom yet. After fixing one update or destructive-action surface, sibling-sweep the other entry points before declaring done.
- Keep private release credentials, local keychain setup, and machine-specific runbooks out of tracked documentation.

## Common Commands

```bash
make fmt-check
make check
make test
make app
./scripts/build.sh
./scripts/check_release_notes.sh
./scripts/check_release_config.sh
./scripts/check_config_release_readiness.sh
```

`make fmt` requires nightly Rust. Use `make app` when the change touches GUI, rendering, windowing, input, or AI overlay behavior.

## Project-Specific Rules

- AI chat and shell flows are core product surfaces. Before changing `kaku-gui/src/ai_*`, `ai_chat_engine/`, `cli_chat/`, or `overlay/ai_chat/`, read `kaku-gui/AGENTS.md`.
- `config_version` bumps every release (source of truth: `assets/shell-integration/config_version.txt`; enforced by `scripts/check_release_config.sh`). Schema changes must update bundled defaults, docs, release checks, and migration behavior together. Per-version history and migration rules live in `docs/config-versions.md`; do not hardcode the current number in instruction files.
- Startup performance depends on shell user-var caching, Lua bytecode, early appearance queries, GLSL version detection, and bundled font caching. Measure before invalidating those paths.
- Notification actions that call back into Kaku must resolve bundled executables relative to the running app.
- macOS menu and window changes need runtime validation in the app bundle, not only a successful compile.
- Review scorecards and diagnostic snapshots should be distilled into stable rules or verification gates before commit; do not keep dated reports as source-of-truth docs.
- Maintainability cleanups must not silently add default-on UI, config, or workflow behavior. Split those changes or get explicit maintainer approval.

## Git and Maintainer Flow

- When the maintainer asks to commit or push, finish the requested git operation after the checks that match the change.
- For multiple unrelated bugs, prefer one commit per issue or behavior. Use subjects such as `fix(scope): #123 short summary` when an issue number exists.
- Public issue and PR replies should be drafted first unless the maintainer has already approved the wording, closure decision, and CI gate.
- After pushing a fix to `main`, wait for the new GitHub Actions run to pass before posting fixed/closed replies.
