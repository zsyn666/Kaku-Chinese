# V0.17.0 Linked

<div align="center">
  <img src="https://raw.githubusercontent.com/tw93/Kaku/main/assets/logo.png" alt="Kaku Logo" width="120" height="120" />
  <h1 style="margin: 12px 0 6px;">Kaku V0.17.0</h1>
  <p><em>A fast, out-of-the-box terminal built for AI coding.</em></p>
</div>

### Changelog

1. **Responses API and Native Search**: Choose `api_mode = "responses"` for Responses-compatible endpoints, and turn on provider-hosted web search without a separate search key.
2. **Pick Your Managed Shell**: `kaku init` can install zsh or fish on purpose, and Kaku keeps that choice across XDG config paths instead of only trusting `$SHELL`.
3. **Richer Terminal Clicks**: Cmd+Click opens bare domains like `github.com`, file links can launch your editor via `config.file_link_editor`, and Option+Click moves the cursor inside the current input line.
4. **Safer AI Tools**: Tool paths, web requests, and code search are harder to abuse; incomplete streams no longer look like successful turns.
5. **Stability Fixes**: Launch no longer dies on oversized draw batches, windows stay below the menu bar, top tabs line up with traffic lights, font fallback is safer, and shell state plus drag-select scroll behave more predictably.

### 更新日志

1. **Responses API 与原生搜索**：兼容端点可选 `api_mode = "responses"`，并开启服务商托管的 web search，不必再配单独搜索 Key。
2. **自选托管 Shell**：`kaku init` 可明确安装 zsh 或 fish，选择会写入状态并在 XDG 路径间保持一致，不再只听 `$SHELL`。
3. **更完整的点击交互**：Cmd+Click 可打开 `github.com` 这类裸域名；文件链接可用 `config.file_link_editor` 指定编辑器；Option+Click 可在当前输入行内移动光标。
4. **更安全的 AI 工具**：路径、网络请求与代码搜索边界更严；流式被截断时不会再被当成成功回合。
5. **稳定性修复**：超大绘制批次不再导致启动崩溃，窗口不会拖进菜单栏后方，顶栏标签与红绿灯对齐，字体回退更安全，Shell 状态与拖选滚动也更稳。

Special thanks to @ddotz and @F1Justin for their contributions to this release.

> https://github.com/tw93/Kaku
