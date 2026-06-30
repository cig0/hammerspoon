# Spoons

`Spoons/` is the repository's library boundary. Every child directory is a
ready-to-use Hammerspoon unit with its own entry point, configuration, runtime,
data, and documentation.

```text
~/.hammerspoon/init.lua
  → Spoons/<name>/init.lua
    → Spoon-owned modules and data
```

No shared registry or runtime is required. Copying one Spoon does not pull in
the others.

## Catalogue

| Spoon | Entry point | Concern |
| --- | --- | --- |
| [Gearbox](./Gearbox/README.md) | `require("Spoons.Gearbox").start()` | Keyboard launcher, nested menus, themes, navigation, and macOS power controls |

The root [`init.lua`](../init.lua) is a clone-friendly loader with Spoon imports
left commented until selected.
