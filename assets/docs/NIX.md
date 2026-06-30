# Nix delivery

The repository exports optional Home Manager and nix-darwin modules. They
install or reference the same standalone Lua under `Spoons/`; generated Nix
configuration only supplies the override table passed to
`Spoons.Gearbox.start()`.

```text
Nix options
  → generated ~/.hammerspoon/hammerspoon-gadgets.lua
  → require("Spoons.Gearbox").start(overrides)
  → standalone Gearbox runtime
```

## Exports

| Flake output | Destination |
| --- | --- |
| `homeModules.default` | Standalone Home Manager or Home Manager embedded elsewhere |
| `darwinModules.default` | nix-darwin configuration with the Home Manager nix-darwin module |

## Home Manager

A standalone Home Manager flake can expose the repository as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hammerspoon.url =
      "github:cig0/hammerspoon";
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "aarch64-darwin";
    in
    {
      homeConfigurations.jane =
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs; };
          modules = [ ./home.nix ];
        };
    };
}
```

The corresponding `home.nix` imports the module and owns the user-facing
settings:

```nix
{ inputs, ... }:

{
  home.username = "jane";
  home.homeDirectory = "/Users/jane";
  home.stateVersion = "26.05";

  imports = [
    inputs.hammerspoon.homeModules.default
  ];

  programs.hammerspoon-gadgets = {
    enable = true;

    gearbox = {
      font.size = 16;
      font.titleSize = 22;
      menu.position = "top";

      theme = {
        name = "system";
        accentSource = "system";
        persistSelection = true;
      };
    };
  };
}
```

Apply it with the existing Home Manager configuration name:

```sh
home-manager switch --flake .#jane
```

Use the real username, home directory, architecture, and established Home
Manager `stateVersion`.

By default the module installs Hammerspoon, links Gearbox at
`~/.hammerspoon/Spoons/Gearbox`, and owns `~/.hammerspoon/init.lua`. When another
module or a hand-written file already owns that entry point:

```nix
programs.hammerspoon-gadgets.manageInit = false;
```

The existing `init.lua` then routes to the generated loader:

```lua
require("hammerspoon-gadgets")
```

## nix-darwin

Hammerspoon configuration is user state. The nix-darwin adapter therefore
routes ownership through Home Manager instead of writing into a home directory
from a root activation script.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hammerspoon.url =
      "github:cig0/hammerspoon";
  };

  outputs = inputs@{ nix-darwin, ... }: {
    darwinConfigurations.my-mac =
      nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./darwin-configuration.nix ];
      };
  };
}
```

`darwin-configuration.nix` imports Home Manager and forwards the same Gearbox
options to one named user:

```nix
{ inputs, ... }:

{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.hammerspoon.darwinModules.default
  ];

  users.users.jane.home = "/Users/jane";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jane.home.stateVersion = "26.05";
  };

  programs.hammerspoon-gadgets = {
    enable = true;
    user = "jane";

    gearbox = {
      menu.screen = "mouse";
      menu.width = 460;
      theme.persistSelection = true;
    };
  };

  system.stateVersion = 7;
}
```

Apply it with the existing nix-darwin configuration name:

```sh
sudo darwin-rebuild switch --flake .#my-mac
```

The named account must exist under `users.users`. The adapter imports the Home
Manager module for that account and forwards every option except its routing
field, `user`.

## Theme persistence

`programs.hammerspoon-gadgets.gearbox.theme.persistSelection` defaults to
`true`. Theme choices made in the Gearbox menu are stored by Hammerspoon under
the `hs.settings` key `Gearbox.theme.selection`, not written into the Nix store
or generated Lua.

```text
menu selection
  → hs.settings["Gearbox.theme.selection"]
  → ~/Library/Preferences/org.hammerspoon.Hammerspoon.plist
  → restored on the next Hammerspoon load
```

The stored record contains the selected theme ID and the configured
`theme.name`. It is accepted only while that configured default still matches
and the theme still exists. Changing `theme.name` in Nix clears the older
interactive choice and makes the new declarative value authoritative.

Set persistence to `false` when every reload must return to the Nix-selected
theme:

```nix
programs.hammerspoon-gadgets.gearbox.theme.persistSelection = false;
```

The complete Gearbox option map and standalone defaults live beside the Spoon in
[`Spoons/Gearbox/README.md`](../../Spoons/Gearbox/README.md#configuration-configlua).
