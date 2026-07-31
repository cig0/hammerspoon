| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `programs.hammerspoon-spoons.enable` | boolean | `false` | Whether to enable the Hammerspoon Spoons integration. |
| `programs.hammerspoon-spoons.extraConfig` | strings concatenated with "\n" | `""` | Lua appended to the managed init.lua after the enabled Spoons load. |
| `programs.hammerspoon-spoons.manageInit` | boolean | `true` | Whether to manage ~/.hammerspoon/init.lua. Disable this when an existing init.lua should remain authoritative, then require "nix-spoons" from that file. |
| `programs.hammerspoon-spoons.spoons.gearbox.enable` | boolean | `true` | Whether to install and load Gearbox. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.timeout` | signed integer or floating point number | `0` | Seconds before the menu closes. Zero disables timeout and intentionally causes Gearbox startup to fail; normal use requires a positive value. |
