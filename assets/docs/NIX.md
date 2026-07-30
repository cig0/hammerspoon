# Nix delivery

The repository exports optional Home Manager and nix-darwin modules. Nix owns
delivery and activation of the Spoons; each Spoon owns its behavior.

```text
Nix enable options
  → ~/.hammerspoon/Spoons/Gearbox
  → ~/.hammerspoon/nix-spoons.lua
  → require("Spoons.Gearbox").start()
  → Spoons/Gearbox/config.lua
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
| `interfaces.homeManagerOptions` | Reusable Home Manager delivery-option schema |
| `interfaces.homeManagerOptionDocs` | Markdown-ready option documentation metadata |

## Home Manager

The Home Manager module exposes only delivery controls:

```nix
{
  imports = [ inputs.hammerspoon.homeModules.default ];

  programs.hammerspoon-spoons = {
    enable = true;
    manageInit = true;
    spoons.gearbox.enable = true;
  };
}
```

The module links Gearbox at `~/.hammerspoon/Spoons/Gearbox`. Hammerspoon itself
must be installed separately. When another module or hand-written file owns
the entrypoint:

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
    spoons.gearbox.enable = true;
  };
}
```

The named account must exist under `users.users`. The adapter does not write
directly into a home directory.

## Configuration ownership

[`Spoons/Gearbox/config.lua`](../../Spoons/Gearbox/config.lua) is the sole
source of Gearbox behavior. The Home Manager and nix-darwin modules neither
redeclare its fields nor render a Lua override table.

```text
Spoons/Gearbox/config.lua
  → Gearbox.start()
  → validation
  → theme, loader, runtime, HUD, and scratchpad
```

This ownership is shared by standalone and Nix-delivered installations. A Nix
flake input update deploys a changed `config.lua`; host profiles only decide
whether the Spoon is present and loaded.

The generated option snapshot is
[`ALL-OPTIONS.md`](./ALL-OPTIONS.md).
