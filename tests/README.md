# Tests

`tests/gearbox.lua` is a deterministic smoke and regression harness for Gearbox.
It supplies a small Hammerspoon API double, loads the real Spoon modules, and
asserts the resulting graph and runtime behavior without launching
applications or drawing a macOS window.

```text
tests/gearbox.lua
  → mocked hs.* boundary
  → real Spoons/Gearbox modules and data
  → assertions over menus, themes, lifecycle, and persistence
```

## Coverage

| Concern | Assertions |
| --- | --- |
| Menu graph | Discovery, ordering, dividers, parent links, reserved and duplicate keys |
| Themes | All bundled IDs, grouped ordering, overrides, color models, system/manual selection |
| Persistence | Restoration, changed-default invalidation, missing-theme cleanup, disabled persistence |
| Runtime | Hotkey replacement, partial-start rollback, modal cleanup, direct and arrow-key activation |
| HUD boundary | Checked rows, immediate theme refresh, lazy appearance resolution |
| Scratchpad | Webview prewarming, root-menu invocation, sizing, capacity, dynamic footer, persistence, toggle, and reuse |
| Host resolution | System fonts and macOS accent are resolved only at their documented lifecycle points |

The harness runs with a command-line Lua interpreter:

```sh
lua tests/gearbox.lua "$(pwd)"
```

Lua parsing, Nix module evaluation, and generated-Lua parsing remain separate
repository checks. `nix flake check` verifies the exported Home Manager and
nix-darwin module shapes; a live Hammerspoon run remains the visual and native
API boundary.
