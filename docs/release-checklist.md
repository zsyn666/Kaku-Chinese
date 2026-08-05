# Release Checklist

## macOS Tab Bar Matrix

Before shipping a release that touches windowing, titlebar coloring, tab bar
layout, or transparency, build the app with `make app` and verify these macOS
config combinations manually:

| Tab position | Tab style | Opacity | Window state | Expected result |
| --- | --- | --- | --- | --- |
| Top | Fancy | Opaque | Windowed | Tab text/icons stay visible below integrated traffic lights. |
| Top | Fancy | Transparent | Windowed | Tab text/icons stay visible; transparent titlebar has no gap. |
| Top | Retro | Opaque | Windowed | Tab text/icons stay visible below integrated traffic lights. |
| Top | Retro | Transparent | Windowed | Tab text/icons stay visible; transparent titlebar has no gap. |
| Bottom | Fancy | Opaque | Windowed | Bottom tab bar is visible and top content clears traffic lights. |
| Bottom | Fancy | Transparent | Windowed | Bottom tab bar is visible; top titlebar area has no gap. |
| Bottom | Retro | Opaque | Windowed | Bottom tab bar is visible and top content clears traffic lights. |
| Bottom | Retro | Transparent | Windowed | Bottom tab bar is visible; top titlebar area has no gap. |
| Top | Fancy | Opaque | Fullscreen | Native titlebar does not cover the rendered tab bar. |
| Bottom | Fancy | Opaque | Fullscreen | Bottom tab bar remains visible after entering and leaving fullscreen. |

The key regression guard is `update_titlebar_background()` in
`window/src/os/macos/window.rs`: native titlebar coloring must remain opt-in for
opaque windows, otherwise `NSTitlebarContainerView` can cover the Metal-rendered
top tab bar.
