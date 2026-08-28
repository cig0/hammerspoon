# Tests

`tests/gearbox.lua` is a deterministic smoke and regression harness for Gearbox.
It supplies a small Hammerspoon API double, loads the real Spoon modules, and
asserts the resulting graph and runtime behavior without launching
applications or drawing a macOS window.

```text
config.lua + optional profile + local settings
  → tests/gearbox.lua
  → mocked hs.* boundary
  → real Spoons/Gearbox modules and data
  → assertions over menus, themes, lifecycle, and persistence
```

`tests/retroui.lua` is the focused library suite. It exercises pure frame
layout, theme validation, button-group state, and mocked canvas, keyboard,
mouse, and timer behavior.

`tests/retroui-package.lua` assembles a temporary Gearbox artifact and checks
canonical/private namespace loading, missing and broken bundle failures, and
byte-identical bundled RetroUI files. It is deterministic delivery coverage,
not a replacement for a live Hammerspoon hit-testing check.

## Coverage

| Concern | Assertions |
| --- | --- |
| Menu graph | Discovery, ordering, dividers, parent links, reserved and duplicate keys |
| Themes | All bundled IDs, grouped ordering, overrides, color models, system/manual selection |
| Preferences | Config/profile/local precedence, generated configuration menus, prompts, save/reload/reset, validation |
| Persistence | Theme restoration, Scratchpad settings/file backends, atomic replacement, cross-open reload, visible failures |
| Runtime | Zero-timeout RetroUI dialog, hotkey replacement, partial-start rollback, session-scoped character capture and live Caps Lock observation, exact case and symbol dispatch, Secure Input refusal, repeat suppression, modal cleanup, and arrow-key activation |
| RetroUI | Frame styles and alignment, asymmetric padding, footer actions, box-glyph width, strict themes and mnemonics, targeted redraws, button focus/press state, keyboard and left-mouse activation, background dismissal, and cleanup races |
| Packaging | Manifest identity, complete private bundle, private preference, canonical fallback, and broken/missing-bundle diagnostics |
| HUD boundary | Root Caps Lock warning, passive memory-aid legend, optional accent border, checked rows, group key-cap backgrounds, immediate theme refresh, lazy appearance resolution |
| Scratchpad | Lazy Webview construction, failed-first-use cleanup, sizing, font size, symmetric placement, capacity, persistence, storage switching, and reuse |
| Host resolution | System fonts and macOS accent are resolved only at their documented lifecycle points |

The harness runs with a command-line Lua interpreter:

```sh
lua tests/gearbox.lua "$(pwd)"
lua tests/retroui.lua "$(pwd)"
lua tests/retroui-package.lua "$(pwd)"
```

Parse changed Lua files separately. A live Hammerspoon run remains the visual
and native API boundary.

## Where to look next

- [`../Spoons/Gearbox/README.md`](../Spoons/Gearbox/README.md) — public
  behavior and configuration contract.
