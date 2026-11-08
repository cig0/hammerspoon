# Nix delivery

The Home Manager module copies Gearbox into `~/.hammerspoon/Spoons/Gearbox`
and generates `nix-spoons.lua`. A managed `init.lua` loads that file before
appending `extraConfig`.

| Setting | Owner |
| --- | --- |
| Loader, activation, backups | Home Manager module |
| Menu toggle, timeout, placement, Scratchpad options | Home Manager options substituted into `config.lua` |
| Global shortcuts | `hyperkeys.lua`, replaced when `quickLaunch` is non-null |
| Caps Lock tap/hold handler | `capsLockViaF18` option |
| Physical Caps Lock → F18 mapping | Native nix-darwin configuration |
| Menu rows, section order, palettes | Gearbox Lua files in this repository |
| Font size | Local Gearbox preference on each Mac |
| Saved position, frame visibility, Scratchpad preferences | Profile and local settings applied after `config.lua` |

## Change the Gearbox shortcut

The default is **Ctrl+Alt+Cmd+Space**. Set
`programs.hammerspoon-spoons.spoons.gearbox.hotkey.modifiers` and `.key` to
change it. See the [shortcut quick reference](../../Spoons/Gearbox/README.md#tldr--change-the-gearbox-shortcut)
for complete manual, Home Manager, and Hoagie examples and reload instructions.

## Exports

| Flake output | Destination |
| --- | --- |
| `modules.homeManager.hammerspoon-spoons` | Home Manager module with class checking |
| `homeModules.hammerspoon-spoons` | Established Home Manager import path, standalone or embedded |
| `homeModules.default` | Alias of `homeModules.hammerspoon-spoons` |
| `interfaces.homeManagerOptions` | Reusable Home Manager delivery, Gearbox shortcut, placement and timeout, and Scratchpad schema |
| `interfaces.homeManagerOptionDocs` | Markdown-ready option documentation metadata |

[`modules/hammerspoon-spoons.nix`](../../modules/hammerspoon-spoons.nix)
defines the module, option schema, activation script, and docs interface.

## Home Manager

The Home Manager module exposes delivery controls, shared Gearbox and
Scratchpad placement, the shortcut, the required timeout, and Scratchpad settings:

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

The module substitutes the toggle hotkey, `capsLockViaF18`, `menu.position`,
`menu.timeout`, and the seven exposed `scratchpad.*` values into `config.lua`.
A non-null `quickLaunch` replaces `hyperkeys.lua`. Activation deploys the Spoon
as regular user-writable files at
`~/.hammerspoon/Spoons/Gearbox` during Home Manager activation; the same
copy semantics apply to `nix-spoons.lua`, and to `init.lua` when managed.
`menu.position` is the enum `"top"` or `"bottom"` and applies to both
windows; bottom placement mirrors the top margin. The default timeout is
the disabled sentinel `0`; normal use requires an explicit positive value.
Hammerspoon itself must be installed separately.

The Nix build stages the configuration in the store. Activation copies it to
`~/.hammerspoon` as regular, user-writable files; Hammerspoon runs those
copies. Edit and reload them while trying an idea. Once a change is approved,
bring it back to this repository before the next activation, which re-asserts
the flake content (`extraConfig` covers entrypoint-only snippets). A target
that differs from the version being deployed is preserved as `<path>.hm-bak`
before the fresh copy lands. Existing backups are kept; additional ones use
`<path>.hm-bak-1`, then increasing suffixes. A complete writable replacement is
staged before the current target changes. Files use atomic replacement;
directory publication failures restore the previous tree. An interruption
between directory renames leaves the previous tree recoverable in its backup.
`spoons.gearbox.enable = false` removes the deployed Gearbox tree and
preserves a tree that differs from the shipped sources by the same rule.
Disabling the module entirely leaves previously deployed files in place.

`nix flake check` builds a configured Gearbox tree and exercises the generated
activation script in a temporary home. It checks all option substitutions,
default/source agreement, writable regular copies, repeated activation,
backup suffixes, symlink replacement, and Gearbox disable cleanup. It does not
launch Hammerspoon; the Lua harnesses cover runtime behavior separately.

When another module or hand-written file owns the entrypoint:

```nix
programs.hammerspoon-spoons.manageInit = false;
```

That entrypoint then loads the generated Spoon loader:

```lua
require("nix-spoons")
```

## Integration boundary

The module is user-scoped and does not accept a username. A standalone Home
Manager configuration imports it directly. When Home Manager is embedded in
another module system, the parent configuration selects the user and that
user's Home Manager configuration imports the same module:

```nix
{
  home-manager.users.cig0 = {
    imports = [ inputs.hammerspoon.homeModules.default ];

    programs.hammerspoon-spoons = {
      enable = true;
      spoons.gearbox.menu.timeout = 5;
    };
  };
}
```

The surrounding NixOS or nix-darwin configuration owns
`home-manager.users.<name>`; this repository does not duplicate that selection
through a second `user` option. Hammerspoon itself is macOS-only, so NixOS is
not a runtime target.

Without Home Manager, use the standalone installation documented in the
[Gearbox README](../../Spoons/Gearbox/README.md#standalone). The flake does not
export a system-level module that writes directly into a user's home directory.

## Caps Lock shortcuts

Enable the Gearbox F18 handler in Home Manager:

```nix
programs.hammerspoon-spoons = {
  enable = true;
  spoons.gearbox = {
    menu.timeout = 60;
    capsLockViaF18 = true;
  };
};
```

Map the physical Caps Lock key to F18 in the native nix-darwin configuration:

```nix
system.keyboard = {
  enableKeyMapping = true;
  userKeyMapping = [
    {
      HIDKeyboardModifierMappingSrc = 30064771129; # Caps Lock
      HIDKeyboardModifierMappingDst = 30064771181; # F18
    }
  ];
};
```

Activate nix-darwin and Home Manager, then reload Hammerspoon. nix-darwin
applies the keyboard map on activation and at boot. Home Manager deploys
Gearbox's handler. Both settings are required for the physical shortcut.

Press and release Caps Lock alone to toggle capitalization. Hold it and press
a mapped letter to open its app or menu. Caps Lock+F opens Finder Folders.
Release the chord before selecting a folder. A chord preserves
the existing capitalization state. An unmapped letter passes through and
cancels the toggle. The four-modifier Hyper shortcuts remain available.

The physical remap applies system-wide. Tap-to-toggle requires Gearbox running
and keyboard input available to Hammerspoon. Quitting Hammerspoon leaves the
key mapped to F18. To return to native Caps Lock, remove its mapping and
activate nix-darwin again with `enableKeyMapping = true` so it applies the
remaining mapping table, including an empty table when appropriate.

Hoagie's integration defaults `capsLockViaF18` on for Darwin-enabled hosts
when the Hammerspoon input exposes the option. Its Darwin output supplies the
physical mapping when Gearbox and the handler are enabled and the menu timeout
is positive. After publishing edits to this repository, run these commands
from the Hoagie checkout, then reload Hammerspoon:

```sh
nix flake update hammerspoon
hoagie hs
```

Setting
`programs.hammerspoon-spoons.spoons.gearbox.capsLockViaF18 = false` disables
the handler and omits the generated mapping. Use the reversal procedure above
to restore native Caps Lock.

## Configuration ownership

[`Spoons/Gearbox/config.lua`](../../Spoons/Gearbox/config.lua) is Gearbox's
runtime configuration contract. Standalone installations read it directly.
Quick Launch defaults to the shortcut map in
[hyperkeys.lua](../../Spoons/Gearbox/hyperkeys.lua). Set
`programs.hammerspoon-spoons.spoons.gearbox.quickLaunch` to replace that map,
for example `{ f = { type = "openMenu"; menu = "finder"; }; m = "Mail"; }`.
Only those two shortcuts are installed with this override. Use `f = "Finder";`
for the original Finder app shortcut. An empty set disables Quick Launch.

To customize sections or folder destinations, edit the repository's
[`menus/*.lua`](../../Spoons/Gearbox/menus/README.md#customize-sections).
There is no Nix option for menu rows. Deploy the updated flake input, activate
Home Manager, and reload Hammerspoon. Keep experiments made in the installed
copy in the repository before rebuilding; activation replaces that copy.

`Gearbox.start()` accepts no override argument. The deployed `config.lua`
loads first, then the versioned profile and local preferences apply their
supported fields. Use Reset Local Overrides and check the profile if a saved
position or Scratchpad setting masks a new Nix default.

The generated option snapshot is
[`ALL-OPTIONS.md`](./ALL-OPTIONS.md).

## Where to look next

- [`../../README.md`](../../README.md) — repository entry point and Spoon
  catalogue.
- [`../../Spoons/Gearbox/README.md`](../../Spoons/Gearbox/README.md) — Gearbox
  installation, controls, and complete runtime configuration.
- [`ALL-OPTIONS.md`](./ALL-OPTIONS.md) — generated Home Manager option surface.
