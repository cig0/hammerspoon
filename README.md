<table>
  <tr>
    <td><img src="./assets/images/repo/Hammerspoon.png" alt="Hammerspoon" width="240"></td>
    <td>
      <h2 align="center"><em>Hammerspoon libraries and ready-to-use Spoons for a sharper macOS workflow.</em></h2>
    </td>
  </tr>
</table>

This repository collects independent Hammerspoon libraries under
[`Spoons/`](./Spoons/). Each Spoon brings its own Lua runtime, defaults, data,
tests, and adjacent documentation. Copy one into an existing Hammerspoon
configuration or deliver it through the optional Nix modules; the Lua code
does not depend on Nix.

## Table of contents

| Entry | Kind | Purpose |
| --- | --- | --- |
| [Gearbox](./Spoons/Gearbox/README.md) | Spoon | Native keyboard launcher with nested menus, an editable scratchpad, arrow navigation, themes, and macOS power controls, inspired by [LeaderKey](https://github.com/mikker/LeaderKey) <3 |
| [Nix delivery](./assets/docs/NIX.md) | Integration | Home Manager and nix-darwin modules for deploying Hammerspoon configuration and enabled Spoons |

## Quick start

For a dedicated Hammerspoon configuration:

```sh
git clone https://github.com/cig0/hammerspoon.git ~/.hammerspoon
```

Uncomment the Spoon in [`init.lua`](./init.lua), reload Hammerspoon, and press
`alt+cmd+space`.

For an existing configuration, copy the desired Spoon beneath
`~/.hammerspoon/Spoons/` and load it from `~/.hammerspoon/init.lua`:

```lua
require("Spoons.Gearbox").start()
```

The [Gearbox guide](./Spoons/Gearbox/README.md) contains the exact copy command,
configuration map, and runtime behavior.

## Theme persistence

Gearbox stores an interactive theme selection with Hammerspoon's `hs.settings`
key `Gearbox.theme.selection`. The value is backed by
`~/Library/Preferences/org.hammerspoon.Hammerspoon.plist`; Gearbox never rewrites
`config.lua`.

The standalone default is `theme.persistSelection = true`. Nix exposes the
same behavior as:

```nix
programs.hammerspoon-spoons.spoons.gearbox.theme.persistSelection = true;
```

Changing the configured default invalidates an older interactive selection, so
declarative configuration remains authoritative. See
[Gearbox configuration](./Spoons/Gearbox/README.md#configuration-configlua) and
[Nix delivery](./assets/docs/NIX.md#theme-persistence).

## Repository map

```text
init.lua
  → Spoons/<name>/init.lua
    → local configuration, data, runtime, and documentation

flake.nix
  → nix/home-manager.nix
  → nix/darwin.nix
    → the same independent Spoons
```

[`Spoons/README.md`](./Spoons/README.md) is the library catalogue. Adding
another Spoon adds another self-contained directory and, when useful, an
optional Nix adapter. It does not create a shared runtime between Spoons.

## License

Unless otherwise stated, everything in this repository is covered by:

```text
Copyright (C) 2025-2026 Martín Cigorraga <cig0.github@gmail.com>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License v3 or later.

This program is distributed without any warranty; without even the implied
warranty of merchantability or fitness for a particular purpose. See the GNU
General Public License for details.
```
