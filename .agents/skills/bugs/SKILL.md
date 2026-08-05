---
name: bugs
description: "Proactively sweep a Kaku area for latent defects and UX traps before users report them, using this repo's own fix history and multi-entry-point archetypes, and confirm every finding with a probe run this turn."
when_to_use: "找找有没有bug, 主动找bug, 有没有隐患, 排查隐患, 举一反三, 上线前扫一遍, 这块可靠吗, 体验问题, latent bug scan, sibling sweep after a fix, /bugs"
---

# Bugs: Find It Before the User Does

`/hunt` needs a symptom. `check` / review needs a diff. This one needs neither: it goes looking.

Named **bugs**, not bug: `/bug` is a Claude Code built-in.

## The Question

Across Kaku's closed bugs and fix commits, the dominant defect is not always a crash. It is often:

- a **second entry point** that skipped the safety path the first entry already had
- a **wrong-but-plausible** geometry or selection state after a modal/resize/sleep
- a **shell-generated script** that is fine on the author's machine and broken in a clean HOME
- an **AI surface** (Cmd+L, `#`, `k`, toast) that diverges on auth, theme, or cwd

So the question that finds bugs here is never only "can this crash?" It is:

> What does this code do when the user arrives through the **other** path (menu vs toast vs CLI vs shell), when the display **scale or sleep** changes mid-session, when the shell is **not** the developer's zsh, or when the AI pane cwd is **remote**?

## 1. Pick the surface

Name the area and the depth. Whole-repo sweeps with no budget produce speculation. Start from the Hotspot Map below (or the area that just shipped a fix) and go deep.

## 2. Read that area's own fix history first

```bash
git log --oneline --grep='^fix' -i -- <path>
git log --pretty=format:'%h %s%n%b' --grep='^fix' -i -- <path> | head -200
gh issue list --repo tw93/Kaku --state closed --label bug --limit 40
```

Bugs recur by shape within a module. Two signals worth acting on:

- A fix chain of two or more commits each "completing" the previous one means a sibling path is probably still open. Real chain here: toast confirm → menu confirm → brew confirm on the same update flow.
- A commit body that says only one surface was fixed (toast / CLI / overlay / brew) means grep every other surface for the same action.

## 3. Sweep the boundaries, in this order

Highest historical yield first. Subsystem guides live in crate `AGENTS.md` files and root `AGENTS.md` risk areas.

| Boundary | What to ask | Where it usually lives |
|---|---|---|
| Multi-entry destructive actions | Menu, toast, CLI, shell, key binding: do they all confirm the same way before quit/replace/kill? | `kaku-gui/src/frontend.rs`, `update.rs`, `overlay/confirm_*.rs`, `kaku/src/update.rs` |
| macOS window geometry | Traffic lights vs tab bar, DPI scale, external display drag, sleep/wake, lock screen, fullscreen first frame | `window/src/os/macos/`, `kaku-gui/src/termwindow/resize.rs`, titlebar paint |
| Tab chrome | Overflow hit targets, rename modal selection, multi-pane title width, top vs bottom bar | `kaku-gui/src/tabbar.rs`, `termwindow/tab_rename.rs` |
| Selection / mouse state | Survives Ctrl+L, modal cancel, mouse-reporting panes, successful terminal input? | `kaku-gui/src/termwindow/selection.rs`, mouseevent |
| Shell integration generation | `local` only inside functions; backticks in bash-heredoc that emit zsh; Starship/PATH scoped to Kaku | `assets/shell-integration/`, `kaku/src/init.rs`, `setup_zsh.sh` |
| Session restore | Split + scrollback both sides, crash backup, stale snapshot resurrecting closed tabs | `kaku-gui/src/session_restore.rs`, paint/quad buffers |
| AI dual surfaces | Cmd+L vs `#` vs `k` vs chat: same auth, theme, proxy, remote-cwd tool policy? | `kaku-gui/src/ai_*`, `inline_ai.rs`, `cli_chat/`, overlay |
| Proxy / network | External API uses system proxy; loopback/private/LAN/`.local`/NO_PROXY go direct | `config/src/proxy.rs`, AI transport |
| AppKit menu intercept | `Ctrl+letter` only `key_is_down: false` in logs? Menu `keyEquivalent` ate it | `window/src/os/macos/menu.rs`, debug_key_events |
| Render buffer growth | Over-capacity draw after retry budget; sleep invalidates drawable | `renderstate.rs`, paint/draw paths |

For a named user symptom, switch to hunt. For a diff under review, switch to check / review.

## 4. Confirm before reporting

A candidate is not a finding until it has evidence produced **this turn**.

- **Confirmed**: source trace that names every entry point, a failing test, or a probe (log, `make test` subset, clean-HOME shell smoke).
- **Plausible**: complete source path, named failure mode, no run yet. Report separately with the probe that would settle it.
- **Not a finding**: "looks risky" without reading the implementation. Grep the call sites or drop it.

Before flagging unwraps or panics, confirm production code: skip `#[test]`, fixtures, doctests, and build scripts.

## 5. Rank by blast radius

1. Silent data loss or process kill (update/restart, close all, reset) without confirm on some entry path
2. Crash loop or unrecoverable launch (session restore, paint)
3. Stuck UI state (selection latch, frozen frame after sleep, window behind menu bar)
4. Shell/environment pollution outside Kaku (Starship, PATH, generated zsh)
5. Visual chrome wrong but recoverable (tab clip, traffic-light gap, font weight)
6. Docs / copy drift

## 6. Guard what gets fixed

Anything confirmed and fixed needs a regression guard when feasible:

- unit/integration test that fails on unfixed code
- shellcheck / setup smoke for shell-generation bugs
- entry-point matrix comment or test listing menu + toast + CLI for destructive flows

Verify with the matrix in root `AGENTS.md`. GUI geometry and AppKit need `make app` or a hand smoke from `.agents/skills/release/SKILL.md` «Pre-release smoke checklist».

## Hard Rules

- **No finding without this-turn evidence.** Speculation wastes review time.
- **One archetype hit means sweep every sibling entry point.** Report `checked N sites, M defective, K n/a`.
- **Do not fix while sweeping.** Collect, then fix. Interleaving loses the sweep.
- **Report clean boundaries as clean.** Do not invent findings to justify the run.
- **Findings outside the named area get listed, not fixed**, unless the maintainer agrees.
- **Do not propose UI i18n** (see root `AGENTS.md`).

## Hotspot Map (issue-backed)

Use these as default scopes when the maintainer says "scan for bugs" without a path:

| Area | Issue / fix examples | Probe |
|---|---|---|
| Update confirm matrix | toast + menu overlay, CLI/brew `confirm_apply_update`, guards in `update.rs` / `frontend.rs` tests | Trace every caller of `restart_to_update` / `spawn_update_helper` / `run_brew_upgrade`; run those unit tests |
| Titlebar / tabs / DPI | #516, #504, #490, #483, #460 | External display + scaled resolution + tab top/bottom |
| Window drag / menubar | #508, #456, #408, #414, #477 | Drag to menubar, lock screen, fill desktop |
| Selection latch | #495, #487, #455 | Ctrl+L, cancel rename, mouse-reporting TUI |
| Shell init generation | #432, #441, #450, #503, #420 | clean HOME `kaku init`, `zsh -n` generated file, non-Kaku shell |
| Session restore paint | #514, #448, #482 | split + dual scrollback snapshot |
| AI auth / overlay | #506, #501, #502, #418 | Cmd+L vs `#`, split resize, appearance flip |
| Proxy split brain | private base_url + system proxy | loopback OpenAI-compatible smoke |

## Output

```
Area:        [what was swept, at what depth]
Boundaries:  [N walked, M applicable]

Confirmed (severity order):
1. [file:line] [the defect in one sentence]
   Evidence: [probe / call-graph / failing test]
   Blast:    [what the user sees]
   Siblings: [N checked, M defective, K n/a]

Plausible (needs a probe):
1. [file:line] [defect] -> [the probe that would settle it]

Swept clean:
- [boundary]: [what was checked, why it holds]

Sibling sweep: [pattern signature] -> [N checked, M defective, K n/a]
```

Say whether anything was fixed or whether this was scan-only.

## Relation to other skills

| Skill | When |
|---|---|
| `bugs` (this) | No symptom yet; proactive sweep or post-fix sibling hunt |
| hunt / debug | User already has a broken behavior |
| check / review | Diff or PR quality |
| maintainer-sweep | Live GitHub issues/PRs, public replies, close after CI |
| release | Pre-tag smoke; runtime checklist that CI cannot see |
