# Nix delivery

The repository exports optional Home Manager and nix-darwin modules. Nix owns
delivery, loader wiring, Gearbox's required timeout and shared placement, and
Scratchpad settings; the Spoon owns every other runtime setting.

```text
Spoons/Gearbox
  + programs.hammerspoon-spoons.spoons.gearbox.menu.{position,timeout}
  + programs.hammerspoon-spoons.spoons.gearbox.scratchpad.*
  → Nix-derived Gearbox copy
  → ~/.hammerspoon/Spoons/Gearbox

enabled Spoon set
  → ~/.hammerspoon/nix-spoons.lua
  → require("Spoons.Gearbox").start()
  → deployed Spoons/Gearbox/config.lua
```

`nix-spoons.lua` is the Nix-owned loader for enabled Spoons. A managed
`~/.hammerspoon/init.lua` requires that loader before appending `extraConfig`;
an externally owned entrypoint must require the loader itself.

## Exports

| Flake output | Destination |
| --- | --- |
| `homeModules.hammerspoon-spoons` | Standalone Home Manager or Home Manager embedded elsewhere |
| `homeModules.default` | Alias of `homeModules.hammerspoon-spoons` |
| `darwinModules.hammerspoon-spoons` | nix-darwin configuration routed through Home Manager |
| `darwinModules.default` | Alias of `darwinModules.hammerspoon-spoons` |
| `interfaces.homeManagerOptions` | Reusable Home Manager delivery, Gearbox placement and timeout, and Scratchpad schema |
| `interfaces.homeManagerOptionDocs` | Markdown-ready option documentation metadata |

## Home Manager

The Home Manager module exposes delivery controls, shared Gearbox and
Scratchpad placement, the required timeout, and Scratchpad settings:

```nix
{
  imports = [ inputs.hammerspoon.homeModules.default ];

  programs.hammerspoon-spoons = {
    enable = true;
    manageInit = true;
    spoons.gearbox = {
      enable = true;
      menu = {
        position = "bottom";
        timeout = 5;
      };
      scratchpad = {
        enable = true;
        fontSize = 18;
        width = 800;
        height = 600;
        maxCharacters = 4096;
        persistContent = true;
        showInstructions = true;
      };
    };
  };
}
```

The module copies Gearbox into the Nix store, substitutes `menu.position`,
`menu.timeout`, and the seven `scratchpad.*` values in that copy, and links it
at `~/.hammerspoon/Spoons/Gearbox`. `menu.position` is the enum `"top"` or
`"bottom"` and applies to both windows; bottom placement mirrors the top margin.
The default timeout is the disabled sentinel `0`; normal use requires an
explicit positive value. Hammerspoon itself must be installed separately.

When another module or hand-written file owns the entrypoint:

```nix
programs.hammerspoon-spoons.manageInit = false;
```

That entrypoint then loads the generated Spoon loader:

```lua
require("nix-spoons")
```

## nix-darwin

The nix-darwin adapter identifies one Home Manager user and forwards the same
delivery options:

```nix
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.hammerspoon.darwinModules.default
  ];

  programs.hammerspoon-spoons = {
    enable = true;
    user = "jane";
    spoons.gearbox = {
      enable = true;
      menu.position = "bottom";
      menu.timeout = 5;
      scratchpad.fontSize = 18;
      scratchpad.width = 800;
      scratchpad.height = 600;
    };
  };
}
```

The named account must exist under `users.users`. The adapter does not write
directly into a home directory.

## Configuration ownership

[`Spoons/Gearbox/config.lua`](../../Spoons/Gearbox/config.lua) is Gearbox's
runtime configuration contract. Standalone installations read it directly.
Nix delivery derives a store copy and replaces its `menu.position`,
`menu.timeout`, and Scratchpad values with the corresponding
`programs.hammerspoon-spoons.spoons.gearbox.*` options.

```text
repository Spoons/Gearbox/config.lua
  + Nix menu.{position,timeout} and scratchpad.*
  → deployed Spoons/Gearbox/config.lua
  → Gearbox.start()
  → validation
  → theme, loader, runtime, HUD, and scratchpad
```

No runtime override table is generated or passed to `Gearbox.start()`. All
other Gearbox values remain owned by the repository file, so a flake input
update deploys their changes. Placement, timeout, and Scratchpad options are
deployment-time exceptions: the shipped timeout `0` intentionally prevents
startup until an installation chooses a positive duration, while shared
placement and Scratchpad policy, sizing, and editor font size remain
host-configurable.

The generated option snapshot is
[`ALL-OPTIONS.md`](./ALL-OPTIONS.md).

## Where to look next

- [`../../README.md`](../../README.md) — repository entry point and Spoon
  catalogue.
- [`../../Spoons/Gearbox/README.md`](../../Spoons/Gearbox/README.md) — Gearbox
  installation, controls, and complete runtime configuration.
- [`ALL-OPTIONS.md`](./ALL-OPTIONS.md) — generated Home Manager option surface.
