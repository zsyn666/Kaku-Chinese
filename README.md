<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/6h/dwarf.svg" width="120" />
  <h1>Kaku</h1>
  <p><em>A fast, out-of-the-box terminal built for AI coding.</em></p>
  <p><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a></p>
</div>

<p align="center">
  <a href="https://github.com/zsyn666/Kaku-Chinese/stargazers"><img src="https://img.shields.io/github/stars/zsyn666/Kaku-Chinese?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/zsyn666/Kaku-Chinese/releases"><img src="https://img.shields.io/github/v/tag/zsyn666/Kaku-Chinese?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/zsyn666/Kaku-Chinese/commits"><img src="https://img.shields.io/github/commit-activity/m/zsyn666/Kaku-Chinese?style=flat-square" alt="Commits"></a>
  <a href="https://twitter.com/HiTw93"><img src="https://img.shields.io/badge/follow-Tw93-red?style=flat-square&logo=Twitter" alt="Twitter"></a>
</p>

<p align="center">
  <img src="assets/kaku.jpg" alt="Kaku Screenshot" width="1000" />
</p>

## Fork Overview

This repository is a [zsyn666](https://github.com/zsyn666) maintained fork of
[tw93/Kaku](https://github.com/tw93/Kaku). It stays track of upstream `main`
while providing three enhancements:

- **Simplified Chinese UI by default**: The application ships with `zh-CN` as
  the default UI language via `rust-i18n` (derived from upstream PR #362),
  with `locales/zh-CN.yml` and `locales/en.yml` kept in parity. Set
  `config.language = "en"` in `kaku.lua` to switch back to English.
- **ARM64 and x86-64 dual-architecture support**: `make app` builds a
  universal binary (fat `arm64 + x86_64`) by default. CI builds and releases
  three packages in parallel — `Kaku.dmg` (universal), `Kaku-arm64.dmg`
  (Apple Silicon), and `Kaku-x64.dmg` (Intel) — along with matching
  `kaku_for_update*.zip` archives, each verified with `lipo -verify_arch`.
- **Automatic upstream merge**: A scheduled GitHub Actions workflow
  (`.github/workflows/sync-upstream.yml`, daily at 03:00 UTC) fetches
  `tw93/Kaku@main` and merges it with `--no-ff`. Whitelisted files
  (`Cargo.lock`, `config_version.txt`, release-guide docs, `locales/*.yml`,
  `audit.yml`) are auto-resolved; any other conflict aborts the merge for
  manual triage. The workflow can also be triggered manually via
  `workflow_dispatch`.

| Aspect | Upstream `tw93/Kaku` | This fork `zsyn666/Kaku-Chinese` |
|---|---|---|
| Default language | English | Simplified Chinese (`config.language = "en"` to switch back) |
| Release artifacts | Single universal `Kaku.dmg` | `Kaku.dmg` (universal) + `Kaku-arm64.dmg` + `Kaku-x64.dmg`, with per-arch update zips |
| Local builds | `make app` = native single-arch | `make app` = universal; `make app-native` / `app-arm64` / `app-x64` available |
| CI runtime | Sequential universal build (~30 min) | Parallel 3-runner matrix (universal / arm64 / x64, ~12 min) |
| Upstream sync | n/a | Daily 03:00 UTC auto-merge with whitelisted resolution |
| Maintainer | `tw93` | `zsyn666` (this fork only; the `vercel` docs site still belongs to upstream) |

**Download guidance**: Apple Silicon users may prefer `Kaku-arm64.dmg` for the
smallest download, Intel users `Kaku-x64.dmg`, and `Kaku.dmg` when in doubt.
All packages target macOS 11.0+.

## Why

Kaku (書く, かく) is the Japanese word for writing: the act of putting thought into form. A deeply customized fork of WezTerm, built for practical defaults on day one while keeping full Lua customization and a fast, lightweight feel.

Part of a trilogy: [Kaku](https://github.com/tw93/Kaku) (書く) writes code, [Waza](https://github.com/tw93/Waza) (技) drills habits, [Kami](https://github.com/tw93/Kami) (紙) ships documents. Think of them as a family: Kaku is the dad, Waza the big sister, Kami the little sister.

## Features

- **Zero Config**: Defaults with JetBrains Mono, macOS font rendering, and low-res font sizing.
- **Theme-Aware Experience**: Auto-switches between dark and light modes with macOS, with tuned selection colors, font weight, and practical color overrides support.
- **Curated Shell Suite**: Built-in zsh plugins with optional CLI tools for prompt, diff, and navigation workflows.
- **Fast & Lightweight**: 40% smaller binary, instant startup, lazy loading, stripped-down GPU-accelerated core.
- **WezTerm-Compatible Config**: Use WezTerm's Lua config directly with full API compatibility and no migration.
- **Polished Defaults**: Copy on select, clickable file paths, history peek from full-screen apps, and visual bell on background tab completion.

## Quick Start

1. [Download Kaku DMG](https://github.com/zsyn666/Kaku-Chinese/releases/latest) (universal, arm64, or x64 variant) and drag it to Applications.
2. Or install a package manager: `brew install tw93/tap/kakuku` (upstream cask may require the tap).
3. Open Kaku. Releases are notarized by Apple and open without security warnings.
4. On first launch, Kaku sets up your shell environment automatically. The default UI is Simplified Chinese; set `config.language = "en"` in `~/.config/kaku/kaku.lua` for English.

## Usage Guide

| Action | Shortcut |
| :--- | :--- |
| New Tab | `Cmd + T` |
| New Window | `Cmd + N` |
| Close Tab/Pane | `Cmd + W` |
| Navigate Tabs | `Cmd + Shift + [` / `]` or `Cmd + 1–9` |
| Navigate Panes | `Cmd + Opt + Arrows` |
| Split Pane Vertical | `Cmd + D` |
| Split Pane Horizontal | `Cmd + Shift + D` |
| Open Settings Panel | `Cmd + ,` |
| AI Panel | `Cmd + Shift + A` |
| AI Chat | `Cmd + L` |
| Apply AI Suggestion | `Cmd + Shift + E` |
| Open Lazygit | `Cmd + Shift + G` |
| Yazi File Manager | `Cmd + Shift + Y` or `y` |
| Clear Screen | `Cmd + K` |

Full keybinding reference: [docs/keybindings.md](docs/keybindings.md)

## Kaku AI

Kaku has a built-in assistant with two modes and a settings page for AI coding tools.

- **Error recovery**: When a command fails, Kaku automatically suggests a fix. Press `Cmd + Shift + E` to apply.
- **Natural language to command**: Type `# <description>` at the prompt and press Enter. Kaku sends the query to the LLM and injects the resulting command back into the prompt, ready to review and run.
- **AI Tools Config**: Manage settings for Claude Code, Codex, Gemini CLI, Copilot CLI, Kimi Code, and more.

### Assistant Setup

Run `kaku ai` to configure the assistant fields directly:

| Field | Use |
| :--- | :--- |
| Auth Type | API key or Follow Codex user connection |
| Simple Model | Lightweight command generation and quick chat model |
| Deep Model | Primary `Cmd + L` / `k` chat model |
| Base URL | OpenAI-compatible API root, such as `https://api.openai.com/v1` |
| API Key | Provider API key when Auth Type is API key |

Full AI assistant docs: [docs/features.md](docs/features.md)

## Performance

| Metric | Upstream | Kaku | Methodology |
| :--- | :--- | :--- | :--- |
| **Executable Size** | ~67 MB | ~40 MB | Aggressive symbol stripping & feature pruning |
| **Resources Volume** | ~100 MB | ~80 MB | Asset optimization & lazy-loaded assets |
| **Launch Latency** | Standard | Instant | Just-in-time initialization |
| **Shell Bootstrap** | ~200ms | ~100ms | Optimized environment provisioning |

## FAQ

**Is there a Windows or Linux version?** Not currently. Kaku is macOS-only for now.

**Can I use transparent windows?** Yes, set `config.window_background_opacity` in `~/.config/kaku/kaku.lua`.

**The `kaku` command is missing.** Run `/Applications/Kaku.app/Contents/MacOS/kaku init --update-only && exec zsh -l`, then `kaku doctor`.

Full FAQ: [docs/faq.md](docs/faq.md)

## Docs

- [Keybindings](docs/keybindings.md) - full shortcut reference
- [Features](docs/features.md) - AI assistant, lazygit, yazi, remote files, shell suite
- [Configuration](docs/configuration.md) - themes, fonts, custom keybindings, Lua API
- [CLI Reference](docs/cli.md) - `kaku ai`, `kaku config`, `kaku doctor`, and more
- [FAQ](docs/faq.md) - common questions and troubleshooting

## Background

I heavily rely on the CLI for both work and personal projects. Tools I've built, like [Mole](https://github.com/tw93/mole) and [Pake](https://github.com/tw93/pake), reflect this.

I used Alacritty for years and learned to value speed and simplicity. As my workflow shifted toward AI-assisted coding, I wanted stronger tab and pane ergonomics. I also explored Kitty, Ghostty, Warp, and iTerm2. Each is strong in different areas, but I still wanted a setup that matched my own balance of performance, defaults, and control.

WezTerm is robust and highly hackable, and I am grateful for its engine and ecosystem. So I built Kaku to be that environment: fast, polished, and ready to work.

## Contributors

Big thanks to all contributors who helped build Kaku. Go follow them! ❤️

<a href="https://github.com/tw93/Kaku/graphs/contributors">
  <img src="./CONTRIBUTORS.svg?v=2" width="1000" />
</a>

## Support

- The most direct way to support the upstream author is getting [Mole for Mac](https://mole.fit), their paid Mac cleanup app.
- If Kaku helped you, give it a star, [share it](https://twitter.com/intent/tweet?url=https://github.com/tw93/Kaku&text=Kaku%20-%20A%20fast%20terminal%20built%20for%20AI%20coding.), or open an issue or PR.
- Upstream has two cats, TangYuan and Coke. You can feed them <a href="https://cats.tw93.fun?name=Kaku" target="_blank">canned food 🥩</a>.

<details>
<summary>These lovely people already did 🐱</summary>
<br/>
<a href="https://cats.tw93.fun?name=Kaku"><img src="https://cdn.jsdelivr.net/gh/tw93/sponsors@main/assets/sponsors.svg" width="1000" loading="lazy" /></a>
</details>

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.

This is a fork of [Kaku](https://github.com/tw93/Kaku) (MIT) by [tw93](https://github.com/tw93). The original MIT-licensed code remains under its terms; new modifications and the combined work are distributed under GPLv3. Attribution for WezTerm and the bundled fonts is in [NOTICE.md](NOTICE.md).
