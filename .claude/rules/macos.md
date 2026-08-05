# Kaku macOS Platform Rules

> macOS 26 上 AppKit 自动注入是 PAC-fault / 崩溃的高频来源。改 menubar / window handling 前必读本文。

## 两套像素坐标空间，禁止混算

窗口/屏幕几何存在两套空间，只在"窗口所在屏 scale == 主屏 scale"时数值兼容，混用的 bug 只在外接屏暴露（#456 拖动跳变）：

- **Canonical ScreenPoint 空间**：`cartesian_to_screen_point` 定义（全局 point × `screens[0]` 主屏 scale、Y 翻转）。`set_window_position` / `window_position` / `MouseEvent::screen_coords` / `MouseEvent::window_origin` 都在这里。
- **窗口 backing 空间**：`MouseEvent::coords`、`dimensions.pixel_*`、UI item 布局坐标，用窗口自己屏幕的 backingScaleFactor。

规则：跨空间换算一律在 `window/src/os/macos` 层做；GUI 层需要窗口原点用 `MouseEvent::window_origin`，不要用 `screen_coords - coords` 推算；居中走 `WindowOps::center()`（原生、单屏 point 空间）。`ScreenInfo.rect`（`screens()` / `resolve_geometry` / `--position` / Lua `screens()`）已统一到 canonical 空间（`nsscreen_to_screen_info` 走 `cartesian_to_screen_point`），`build_window` 不再对 resolve 出的 x/y 除 scale（除一次就是 upstream 继承的 Retina 落点折半 bug，size 的除法保留，那是 px→pt 给 NSWindow 用的）。

## 默认渲染后端是 WebGpu，CGL-only 的 wake 修复护不住它

bundled `kaku.lua` 设了 `front_end = 'WebGpu'`（Metal via wgpu）。`window/src/os/macos` 里的睡眠/唤醒防护（`SYSTEM_SLEEPING` flush 闸门、`BackendImpl::update`、display-change present defer）全部只作用于 CGL 路径，对默认用户是 no-op。给 sleep/wake/display-reconfig 加修复时必须同时考虑 WebGpu 路径（#458）。

WebGpu surface 失效的恢复入口在 `TermWindow::do_paint_webgpu`：休眠唤醒会让 Metal drawable 失效但窗口尺寸不变，`WebGpuState::resize` 对相同尺寸是故意 no-op（热路径），所以恢复必须走 `reconfigure_surface()` 强制 `surface.configure`，不能用 `resize(dims)` 代替。wgpu Metal 后端把 nil `nextDrawable` 映射成 `SurfaceError::Timeout`，所以 Timeout 连续出现同样要触发重配，不能永远静默跳帧。症状签名：键盘输入照常进 PTY、画面停在旧帧，说明是渲染管线死了而不是主线程卡死。

## AppKit Menu 自动注入是地雷

NSApplication 默认会向 Window menu 和 Help menu 注入自己的项（Tile / Move & Resize / Bring All to Front / Help Search），并把 NSWindowRepresentingMenuItem 挂在 Windows menu 下做 dangling reference 。在 macOS 26 上，这些注入项可能 PAC-fault：

- `-[NSMenu _performKeyEquivalentWithDelegate:]` 在 Ctrl+Cmd+F 路由时崩
- Windows menu 关闭窗口后 NSWindowRepresentingMenuItem dangling
- Help Search field 触发 menu 重新计算时崩

## 必须执行的兜底

- 不要调 `setWindowsMenu:` 让 AppKit 接管 Windows menu。Kaku 有自己的 tab/window 切换器。
- 不要调 `setHelpMenu:` 让 AppKit 注入 Help Search。Kaku 没有 help book。
- 窗口创建时调 `setExcludedFromWindowsMenu:` 让 AppKit 看不见我们的 NSWindow，避免它把窗口加到 Windows menu。

参考历史 commit：
- `1ec3823` - 第一次排查 NSWindowRepresentingMenuItem dangling
- `4b15bab` - 进一步 stop AppKit from injecting into Window/Help menus
- `fc2dfa9` - redirect AppKit Spotlight for Help to an orphan menu
- `6ba7381` - restore synchronous menubar init to prevent key event loss

## Menubar 初始化时序

Menubar **必须同步初始化**。延后到 async block 会丢早期按键事件（Cmd+Q 在启动后立刻按下会被吞）。见 `6ba7381`。

## Key Equivalent

新增 KeyAssignment 前确认走 Kaku 自己的按键分发路径，不要走 AppKit menu 的 `performKeyEquivalent`。后者会经过被 PAC-fault 的注入项。

### menu keyEquivalent 会拦 keyDown，吞掉 raw-mode TUI 的 Ctrl+letter

macOS 26 上 NSMenu 的 keyEquivalent modifier 匹配并不严格相等。给 menu item 装 `Ctrl+letter` 形式的快捷键，即使带额外 modifier（如 `NSFunctionKeyMask` 想做 `Fn+Ctrl+letter`），仍会拦截 plain `Ctrl+letter` 的 keyDown。后果：

- AppKit 把 keyDown 路由给 menu item action，NSWindow 收不到。
- keyUp 不走 `performKeyEquivalent:`，所以 keyUp 照常进 Kaku。
- `termwiz/src/input.rs` 的 `encode` 对 `is_down=false` 直接返回空字符串，PTY 上一个字节都不会到。
- 普通 shell `cat -v` 测试看到 `^C` 不代表 raw-mode 也工作；启动时机和 cooked vs raw 都会让 menu 拦截表现不一致。**必须**在 raw-mode TUI (claude / codex / vim / htop) 里实测。

兜底：任何"模仿系统快捷键"的 menu 项宁可 `keys: vec![]` 不设快捷键，让用户从菜单点。`kaku-gui/src/commands.rs` 里的 keyEquivalent 装配逻辑必须统一从按键候选本身取 modifiers，不要为个别 menu 项走强制 modifier 的特例化路径（历史上的特例化路径已删，不要加回）。

参考历史：`a14b26d` 之后的 CenterWindow 修复（删掉给 Window > Center 装 `Fn+Ctrl+C` keyEquivalent 的特例，因为 macOS 26 把它当 plain Ctrl+C 拦了，导致 raw-mode 下 Ctrl+C 不退 claude/codex）。

### 排查 keyDown 丢失

`config.debug_key_events = true` 重启 Kaku，复现按键，看 `~/.local/share/kaku/kaku-gui-log-<pid>.txt`：

- grep `key_event.*CTRL`。
- 如果只有 `key_is_down: false`、没有 `key_is_down: true`，就是 menu keyEquivalent 拦了 keyDown。
- 这种情况下不要去查 termwiz / PTY / termios，先找 `set_key_equiv_modifier_mask` 装配点。

## 调试方式

- 怀疑 menu 注入相关崩溃时：`defaults read com.apple.dt.Xcode` 找最近 crash log。
- 看 `NSMenu _performKeyEquivalentWithDelegate:` 栈帧是 AppKit 注入项的标志。
- 主要复现环境是一台 macOS 26 实机。
