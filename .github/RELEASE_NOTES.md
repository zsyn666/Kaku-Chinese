# V0.19.0 Restored

<div align="center">
  <img src="https://raw.githubusercontent.com/tw93/Kaku/main/assets/logo.png" alt="Kaku Logo" width="120" height="120" />
  <h1 style="margin: 12px 0 6px;">Kaku V0.19.0</h1>
  <p><em>A fast, out-of-the-box terminal built for AI coding.</em></p>
</div>

### Changelog

1. **Pane Input Broadcast Removed**: It was too easy to trigger by accident and could repeat a risky command in unrelated panes, so existing key assignments now do nothing.
2. **Sessions Restore More Completely**: Reopening Kaku brings back your windows, their panes, and each pane's directory, and one pane that fails to save no longer costs you the rest.
3. **Closing No Longer Hits the Wrong Pane**: A close confirmation stays tied to the pane it belongs to, and closing the active tab leaves you on the expected one.
4. **Display and Integration Fixes**: Light-theme selections stay visible, lazygit works in nested shells, clearing history leaves full-screen programs intact, tab renaming no longer freezes titles, and slow synchronized output stops tearing.

### 更新日志

1. **移除分屏输入广播**：这个功能容易误触，会把危险命令重复到无关分屏，原有快捷键保留但不再生效。
2. **会话恢复更完整**：重新打开时窗口、分屏和各自的目录都会还原，个别分屏未能保存也不影响其余。
3. **关闭不再误伤其他分屏**：确认框始终对应打开它的分屏，关闭当前标签页后会停在预期的标签页。
4. **显示与集成修复**：浅色主题选中内容清晰可见，lazygit 支持嵌套 shell，清空历史不打断全屏程序，重命名标签页不卡住标题，慢速同步输出不再撕裂。

Special thanks to @shlroland and @dufu1991 for their contributions to this release.

> https://github.com/tw93/Kaku
