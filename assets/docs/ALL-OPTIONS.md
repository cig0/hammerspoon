| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `programs.hammerspoon-spoons.enable` | boolean | `false` | Whether to enable the Hammerspoon Spoons integration. |
| `programs.hammerspoon-spoons.extraConfig` | strings concatenated with "\n" | `""` | Lua appended to the managed init.lua after the enabled Spoons load. |
| `programs.hammerspoon-spoons.manageInit` | boolean | `true` | Whether to manage ~/.hammerspoon/init.lua. Disable this when an existing init.lua should remain authoritative, then require "nix-spoons" from that file. |
| `programs.hammerspoon-spoons.spoons.gearbox.enable` | boolean | `true` | Whether to install and load Gearbox. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.position` | one of "top", "bottom" | `"top"` | Shared vertical placement for the Gearbox menu and Scratchpad. Bottom mirrors the top offset from the opposite screen edge. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.timeout` | signed integer or floating point number | `0` | Seconds before the menu closes. Zero disables timeout and intentionally causes Gearbox startup to fail; normal use requires a positive value. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.enable` | boolean | `true` | Whether to expose the editable scratchpad in the Gearbox root menu. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.fontSize` | signed integer or floating point number | `14` | Scratchpad editor font size in pixels. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.height` | signed integer | `480` | Scratchpad height in points. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.maxCharacters` | signed integer | `4096` | Maximum editable scratchpad capacity in characters. Existing saved content above the limit is preserved and must be reduced before more text can be added. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.persistContent` | boolean | `true` | Whether scratchpad content survives Hammerspoon reloads through local, unencrypted hs.settings storage. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.showInstructions` | boolean | `true` | Whether to show the non-editable keyboard reference footer. |
| `programs.hammerspoon-spoons.spoons.gearbox.scratchpad.width` | signed integer | `720` | Scratchpad width in points. |
