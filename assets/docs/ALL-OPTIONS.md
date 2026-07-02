| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `programs.hammerspoon-spoons.enable` | boolean | `false` | Whether to enable the Hammerspoon Spoons integration. |
| `programs.hammerspoon-spoons.extraConfig` | strings concatenated with "\n" | `""` | Lua appended to the managed init.lua after the enabled Spoons load.  |
| `programs.hammerspoon-spoons.manageInit` | boolean | `true` | Whether to manage ~/.hammerspoon/init.lua. Disable this when an existing init.lua should remain authoritative, then require "nix-spoons" from that file.  |
| `programs.hammerspoon-spoons.spoons.gearbox.enable` | boolean | `true` | Whether to load the Gearbox launcher. |
| `programs.hammerspoon-spoons.spoons.gearbox.font.bodyWeight` | one of "regular", "bold" | `"regular"` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.font.family` | null or string | `null` | Font family; null uses the macOS system font. |
| `programs.hammerspoon-spoons.spoons.gearbox.font.groupWeight` | one of "regular", "bold" | `"bold"` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.font.size` | signed integer or floating point number | `14` | Menu item font size. |
| `programs.hammerspoon-spoons.spoons.gearbox.font.titleSize` | signed integer or floating point number | `20` | Menu title font size. |
| `programs.hammerspoon-spoons.spoons.gearbox.font.titleWeight` | one of "regular", "bold" | `"bold"` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.hotkey.key` | string | `"space"` | Hammerspoon key name used to enter or close Gearbox. |
| `programs.hammerspoon-spoons.spoons.gearbox.hotkey.modifiers` | list of (one of "alt", "option", "cmd", "command", "ctrl", "control", "shift") | `["alt","cmd"]` | Modifiers used to enter or close Gearbox. |
| `programs.hammerspoon-spoons.spoons.gearbox.loupe.adjacentScale` | signed integer or floating point number | `1.06` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.loupe.duration` | signed integer or floating point number | `0` | Selection animation duration; zero gives immediate input. |
| `programs.hammerspoon-spoons.spoons.gearbox.loupe.enabled` | boolean | `true` | Whether keyboard selection magnifies nearby rows. |
| `programs.hammerspoon-spoons.spoons.gearbox.loupe.selectedScale` | signed integer or floating point number | `1.18` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.highlightGroups` | boolean | `true` | Whether group keys use the macOS accent color. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.position` | one of "top", "center", "bottom" | `"top"` | Vertical menu position within the selected screen. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.screen` | one of "main", "mouse" | `"main"` | Screen on which Gearbox appears. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.showEmojis` | boolean | `true` | Whether menu titles include their emoji. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.timeout` | signed integer or floating point number | `0` | Seconds before the menu closes; zero disables timeout. |
| `programs.hammerspoon-spoons.spoons.gearbox.menu.width` | signed integer | `420` | Menu width in points. |
| `programs.hammerspoon-spoons.spoons.gearbox.navigation.activateKey` | string | `"return"` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.navigation.cancelKey` | string | `"escape"` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.navigation.enabled` | boolean | `true` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.navigation.includeFooter` | boolean | `true` | Whether arrow navigation can select Back or Exit. |
| `programs.hammerspoon-spoons.spoons.gearbox.navigation.resetTimeoutOnInput` | boolean | `true` | Whether navigation input restarts an enabled timeout. |
| `programs.hammerspoon-spoons.spoons.gearbox.navigation.wrap` | boolean | `true` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.accentSource` | one of "system", "theme" | `"system"` | Whether highlighted controls use the macOS accent or the selected theme's accent.  |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.fallbackAccent` | submodule | `{"alpha":1,"blue":1,"green":0.48,"red":0.04}` |  |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.name` | string | `"system"` | Theme ID to select, or "system" to follow the macOS appearance.  |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.overrides` | attribute set of (submodule) | `{}` | Partial semantic color overrides keyed by discovered theme ID.  |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.persistSelection` | boolean | `true` | Whether selections made from the Themes menu survive Hammerspoon reloads.  |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.system.dark` | string | `"gearbox-dark"` | Theme ID used for the macOS dark appearance. |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.system.light` | string | `"gearbox-light"` | Theme ID used for the macOS light appearance. |
| `programs.hammerspoon-spoons.spoons.gearbox.theme.systemAccentText` | submodule | `{"alpha":1,"white":1}` |  |
