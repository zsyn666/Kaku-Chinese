# V0.18.2 Dual

<div align="center">
  <img src="https://raw.githubusercontent.com/tw93/Kaku/main/assets/logo.png" alt="Kaku Logo" width="120" height="120" />
  <h1 style="margin: 12px 0 6px;">Kaku V0.18.2</h1>
  <p><em>A fast, out-of-the-box terminal built for AI coding.</em></p>
</div>

### Changelog

1. **Universal by Default**: `make app` now builds a universal binary (arm64 + x64) so local debug builds match release artifacts.
2. **Split Packages**: Release now ships `Kaku.dmg` (universal) plus `Kaku-arm64.dmg` and `Kaku-x64.dmg` for smaller per-architecture downloads.
3. **Security Audit Fixes**: Updated `h2` to 0.4.16 for `RUSTSEC-2026-0258` and trusted Homebrew `aws/tap` to clear CI annotations.

### 更新日志

1. **默认 Universal**：`make app` 现默认构建 Universal 包（arm64 + x64），本地调试产物与发布产物一致。
2. **双包分发**：发布同时提供 `Kaku.dmg`（Universal）以及 `Kaku-arm64.dmg` 与 `Kaku-x64.dmg`，按需下载更小体积。
3. **安全审计修复**：更新 `h2` 至 0.4.16 修复 `RUSTSEC-2026-0258`，并信任 Homebrew `aws/tap` 清除 CI 告警。

> https://github.com/tw93/Kaku
