# Spoons

`Spoons/` is the repository's ready-to-use Spoon boundary. Every child directory is a
ready-to-use Hammerspoon unit with its own entry point, configuration, runtime,
data, and documentation.

```text
~/.hammerspoon/init.lua
  → Spoons/<name>/init.lua
    → Spoon-owned modules and data
```

No shared registry or runtime is required. Reusable source libraries live in
[`../lib/`](../lib/); a Spoon that depends on one packages a private copy.

## Catalogue

| Spoon | Entry point | Concern |
| --- | --- | --- |
| [Gearbox](./Gearbox/README.md) | `require("Spoons.Gearbox").start()` | Keyboard launcher, scratchpad, nested menus, themes, navigation, and macOS power controls |

The root [`init.lua`](../init.lua) is a clone-friendly loader with Spoon imports
left commented until selected.

## Where to look next

- [`Gearbox/README.md`](./Gearbox/README.md) — installation, controls,
  configuration, and runtime boundaries.
- [`../lib/RetroUI/README.md`](../lib/RetroUI/README.md) — standalone
  retro-dialog library and API.
- [`../assets/docs/NIX.md`](../assets/docs/NIX.md) — optional Home Manager
  delivery.
