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

## 分支概述

本仓库为 [zsyn666](https://github.com/zsyn666) 维护的分支，基于
[tw93/Kaku](https://github.com/tw93/Kaku)。该分支持续跟进上游 `main`，
并在以下三个方面提供增强：

- **默认简体中文 UI**：应用通过 `rust-i18n` 默认启用 `zh-CN`（源自上游 PR #362），
  `locales/zh-CN.yml` 与 `locales/en.yml` 保持键值一致。如需恢复英文，
  在 `kaku.lua` 中设置 `config.language = "en"` 即可。
- **ARM64 与 x86-64 双架构支持**：`make app` 默认构建 Universal（fat `arm64 + x86_64`）。
  CI 并行构建并发布三个安装包——`Kaku.dmg`（Universal）、`Kaku-arm64.dmg`
  （Apple Silicon）、`Kaku-x64.dmg`（Intel），并同步提供对应架构的
  `kaku_for_update*.zip` 更新包，均经 `lipo -verify_arch` 校验。
- **自动合并上游**：定时工作流（`.github/workflows/sync-upstream.yml`，每日 03:00 UTC）
  拉取 `tw93/Kaku@main` 并以 `--no-ff` 合并。白名单文件（`Cargo.lock`、
  `config_version.txt`、发布文档、`locales/*.yml`、`audit.yml`）自动解决冲突；
  其余冲突将中止合并并转人工处理。该工作流亦可通过 `workflow_dispatch` 手动触发。

| 维度 | 上游 `tw93/Kaku` | 本分支 `zsyn666/Kaku-Chinese` |
|---|---|---|
| 默认语言 | 英文 | 简体中文（`config.language = "en"` 可切回） |
| 发布产物 | 单一 Universal `Kaku.dmg` | `Kaku.dmg`（Universal）+ `Kaku-arm64.dmg` + `Kaku-x64.dmg`，并附各架构更新 zip |
| 本地构建 | `make app` = 本机单架构 | `make app` = Universal；另提供 `make app-native` / `app-arm64` / `app-x64` |
| CI 构建 | 串行 Universal（约 30 分钟） | 3 Runner 并行矩阵（universal、arm64、x64，约 12 分钟） |
| 上游同步 | 无 | 每日 03:00 UTC 自动合并，白名单自动解决冲突 |
| 维护者 | `tw93` | `zsyn666`（仅限本分支；`vercel` 文档站仍归属上游） |

**下载建议**：Apple Silicon 用户可选择 `Kaku-arm64.dmg` 以获取最小体积，
Intel 用户选择 `Kaku-x64.dmg`，如不确定可选择 `Kaku.dmg`。
所有包均适配 macOS 11.0 及以上。

## Why

Kaku（書く，かく）是"书写"的日语表达：将思考落实到形式的过程。它是 WezTerm 的深度定制分支，
从第一天起就为实用默认值而构建，同时保留完整的 Lua 定制能力与轻量快速的使用体验。

三部曲之一：[Kaku](https://github.com/tw93/Kaku)（書く）负责写代码，
[Waza](https://github.com/tw93/Waza)（技）训练习惯，
[Kami](https://github.com/tw93/Kami)（紙）交付文档。它们是一个家庭：
Kaku 是父亲，Waza 是姐姐，Kami 是妹妹。

## 特性

- **零配置**：默认使用 JetBrains Mono、macOS 字体渲染与低分辨率字体尺寸。
- **主题感知体验**：随 macOS 自动切换深色与浅色模式，提供调校过的选区颜色、
  字重与实用的颜色覆盖支持。
- **精选 Shell 套件**：内置 zsh 插件，可选 CLI 工具覆盖提示符、差异与导航工作流。
- **轻量高速**：二进制体积减小 40%，启动即时响应，惰性加载，精简 GPU 加速核心。
- **兼容 WezTerm 配置**：直接使用 WezTerm 的 Lua 配置，完整 API 兼容，无需迁移。
- **打磨的默认体验**：选中即复制、可点击的文件路径、全屏应用中的历史预览、
  后台标签页完成时的视觉铃声。

## 快速开始

1. [下载 Kaku DMG](https://github.com/zsyn666/Kaku-Chinese/releases/latest)
   （提供 Universal、arm64、x64 三种选择），拖拽到"应用程序"文件夹。
2. 或通过包管理器安装：`brew install tw93/tap/kakuku`（上游 cask 可能需要该 tap）。
3. 打开 Kaku。所有版本均经 Apple 公证，不会出现安全警告。
4. 首次启动时，Kaku 自动配置 shell 环境。默认 UI 为简体中文，
   如需英文请在 `~/.config/kaku/kaku.lua` 中设置 `config.language = "en"`。

## 使用指南

| 操作 | 快捷键 |
| :--- | :--- |
| 新建标签页 | `Cmd + T` |
| 新建窗口 | `Cmd + N` |
| 关闭标签/面板 | `Cmd + W` |
| 切换标签 | `Cmd + Shift + [` / `]` 或 `Cmd + 1–9` |
| 切换面板 | `Cmd + Opt + 方向键` |
| 垂直拆分面板 | `Cmd + D` |
| 水平拆分面板 | `Cmd + Shift + D` |
| 打开设置面板 | `Cmd + ,` |
| AI 面板 | `Cmd + Shift + A` |
| AI 对话 | `Cmd + L` |
| 应用 AI 建议 | `Cmd + Shift + E` |
| 打开 Lazygit | `Cmd + Shift + G` |
| Yazi 文件管理器 | `Cmd + Shift + Y` 或 `y` |
| 清屏 | `Cmd + K` |

完整快捷键参考：[docs/keybindings.md](docs/keybindings.md)

## Kaku AI

Kaku 内置助手，提供两种模式与 AI 编码工具设置页。

- **错误恢复**：命令执行失败时，Kaku 自动给出修复建议，按 `Cmd + Shift + E` 应用。
- **自然语言转命令**：在提示符下输入 `# <描述>` 并回车，Kaku 将查询发送至 LLM，
  并把生成结果注入提示符，确认后再执行。
- **AI 工具配置**：管理 Claude Code、Codex、Gemini CLI、Copilot CLI、Kimi Code 等工具设置。

### 助手配置

直接运行 `kaku ai` 配置助手字段：

| 字段 | 用途 |
| :--- | :--- |
| 认证方式 | API Key 或跟随 Codex 用户连接 |
| 简单模型 | 轻量的命令生成与快速对话模型 |
| 深度模型 | 主要的 `Cmd + L` / `k` 对话模型 |
| Base URL | OpenAI 兼容 API 根地址，如 `https://api.openai.com/v1` |
| API Key | 认证方式为 API Key 时的密钥 |

完整 AI 助手文档：[docs/features.md](docs/features.md)

## 性能

| 指标 | 上游 | Kaku | 说明 |
| :--- | :--- | :--- | :--- |
| **可执行文件体积** | ~67 MB | ~40 MB | 激进符号剥离与功能裁剪 |
| **资源体积** | ~100 MB | ~80 MB | 资源优化与惰性加载 |
| **启动延迟** | 常规 | 即时 | 即时初始化 |
| **Shell 启动** | ~200ms | ~100ms | 优化的环境预置 |

## 常见问题

**有 Windows 或 Linux 版本吗？** 暂时没有，Kaku 目前仅支持 macOS。

**可以使用透明窗口吗？** 可以，在 `~/.config/kaku/kaku.lua` 中设置
`config.window_background_opacity`。

**`kaku` 命令缺失。** 依次运行
`/Applications/Kaku.app/Contents/MacOS/kaku init --update-only && exec zsh -l`，
然后执行 `kaku doctor`。

完整 FAQ：[docs/faq.md](docs/faq.md)

## 文档

- [快捷键](docs/keybindings.md) — 完整快捷键参考
- [功能](docs/features.md) — AI 助手、lazygit、yazi、远程文件、shell 套件
- [配置](docs/configuration.md) — 主题、字体、自定义快捷键、Lua API
- [CLI 参考](docs/cli.md) — `kaku ai`、`kaku config`、`kaku doctor` 等
- [FAQ](docs/faq.md) — 常见问题与故障排查

## 背景

我的工作与个人项目重度依赖 CLI。为此我构建的工具，如
[Mole](https://github.com/tw93/mole) 与 [Pake](https://github.com/tw93/pake)，
均体现了这一取向。

我多年使用 Alacritty，并逐渐体会到速度与简洁的价值。随着工作流转向 AI 辅助编程，
我需要更强大的标签页与面板交互。我也尝试过 Kitty、Ghostty、Warp 与 iTerm2，
各有所长，但我依然追求性能、默认值与可控性之间的平衡。

WezTerm 稳固且高度可定制，我对其引擎与生态系统深表感谢。因此我构建了 Kaku，
作为这样一个环境：快速、精致、开箱即用。

## 贡献者

感谢所有帮助构建 Kaku 的贡献者，请关注他们！❤️

<a href="https://github.com/tw93/Kaku/graphs/contributors">
  <img src="./CONTRIBUTORS.svg?v=2" width="1000" />
</a>

## 支持

- 支持上游作者最直接的方式是购买 [Mole for Mac](https://mole.fit)。
- 如果 Kaku 对你有帮助，欢迎点星、[分享](https://twitter.com/intent/tweet?url=https://github.com/tw93/Kaku&text=Kaku%20-%20A%20fast%20terminal%20built%20for%20AI%20coding.)，
  或提交 issue / PR。
- 上游有两只猫：汤圆与可乐。若 Kaku 让你的生活更美好，
  可以给它们投喂<a href="https://cats.tw93.fun?name=Kaku" target="_blank">猫粮 🥩</a>。

<details>
<summary>已有爱心人士投喂 🐱</summary>
<br/>
<a href="https://cats.tw93.fun?name=Kaku"><img src="https://cdn.jsdelivr.net/gh/tw93/sponsors@main/assets/sponsors.svg" width="1000" loading="lazy" /></a>
</details>

## 许可证

GNU General Public License v3.0 — 详见 [LICENSE](LICENSE)。

本仓库为 [Kaku](https://github.com/tw93/Kaku) (MIT) 的分支，原作者为
[tw93](https://github.com/tw93)。原始 MIT 代码维持其许可证条款；
新修改与合并作品以 GPLv3 分发。WezTerm 与内置字体的署名见
[NOTICE.md](NOTICE.md)。
