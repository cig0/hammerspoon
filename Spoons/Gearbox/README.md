# Gearbox

Gearbox is a native Hammerspoon keyboard launcher with nested menus, direct
shortcuts, arrow navigation, loupe scaling, macOS power controls, and
auto-discovered themes. It uses the macOS system font by default and can follow
the current appearance and accent.

## Enable Gearbox

From a checkout of this repository, copy the Spoon into Hammerspoon's standard
configuration tree:

```sh
mkdir -p ~/.hammerspoon/Spoons/Gearbox
cp -R Spoons/Gearbox/. ~/.hammerspoon/Spoons/Gearbox/
```

Add `require("Spoons.Gearbox").start()` to your
`~/.hammerspoon/init.lua` file:

```lua
require("Spoons.Gearbox").start()
```

Reload Hammerspoon and press `alt+cmd+space`. A full clone at
`~/.hammerspoon` already has the expected directory layout; only the import in
the repository's root [`init.lua`](../../init.lua) needs to be enabled.

## Controls

```text
alt+cmd+space → open or close Gearbox
letter key    → run or open the displayed entry
↑ / ↓         → select an entry
Return        → activate the selection
Esc           → return to the parent or exit
```

The first arrow press selects the first or last entry. Selection wraps by
default. Loupe scaling is immediate, so key repeat does not wait for an
animation.

## Menu map

```text
Gearbox
├── Calculator
├── ForkLift
├── KeePassXC
├── Passwords
├── Agenda
│   ├── Calendar
│   ├── Mail
│   └── Reminders
├── Applications
│   ├── Communications
│   ├── Omni Software Suite
│   └── Photo & Video
├── Developer Tools
├── Finder Folders
├── Web Browsers
├── macOS Utilities
│   ├── System Settings
│   ├── Reload Hammerspoon
│   ├── Keep Display Awake
│   ├── Prevent Idle Sleep
│   ├── Allow Normal Sleep
│   └── Sleep
└── Themes
    ├── Follow macOS
    ├── Light: Catppuccin, Gearbox, Gruvbox
    └── Dark: Catppuccin, Dracula, Gearbox, Gruvbox, Monokai, Nord, Tokyo Night
```

Ordinary child menus are sorted by displayed label. `macOS Utilities` and
`Themes` occupy the utilities section immediately before the final Exit
divider. Themes retain separate Light and Dark sections and sort
alphabetically within each.

The macOS power modes behave as one checked selection:

- `Keep Display Awake` enables `displayIdle`.
- `Prevent Idle Sleep` enables `systemIdle`.
- `Allow Normal Sleep` disables both and is the default.

Hammerspoon releases those assertions when its configuration reloads.

## Directory map

| Path | Owns |
| --- | --- |
| [`config.lua`](./config.lua) | Passive standalone defaults |
| [`menus/`](./menus/README.md) | Passive menu graph and action descriptors |
| [`themes/`](./themes/README.md) | Passive palettes and Themes-menu metadata |
| [`loader.lua`](./loader.lua) | Discovery, validation, ordering, dividers, and footers |
| [`actions.lua`](./actions.lua) | Application, filesystem, power, and theme operations |
| [`runtime.lua`](./runtime.lua) | Modal lifecycle, hotkeys, timeout, selection, and rollback |
| [`hud.lua`](./hud.lua) | Canvas geometry, text, checks, selection, and loupe rendering |
| [`theme.lua`](./theme.lua) | Theme loading, persistence, fonts, appearance, and colors |
| [`init.lua`](./init.lua) | Public `start()` and `stop()` boundary |
| [`tests/`](../../tests/README.md) | Mocked-Hammerspoon smoke and regression coverage |

```text
config.lua + menus/*.lua + themes/*.lua
  → init.lua validation
  → loader.lua + theme.lua
  → runtime.lua + actions.lua + hud.lua
```

## Configuration (`config.lua`)

[`config.lua`](./config.lua) is the standalone source of user-facing defaults.
It contains no Hammerspoon calls. Nix users receive the same shape as an
override table generated beneath
`programs.hammerspoon-spoons.spoons.gearbox`; see the
[Nix document](../../assets/docs/NIX.md).

### Hotkey and menu

| Option | Default | Meaning |
| --- | --- | --- |
| `hotkey.modifiers` | `{ "alt", "cmd" }` | Modifiers used to open or close Gearbox |
| `hotkey.key` | `"space"` | Hammerspoon key name paired with the modifiers |
| `menu.timeout` | `0` | Seconds before closing; zero disables timeout |
| `menu.position` | `"top"` | `"top"`, `"center"`, or `"bottom"` screen placement |
| `menu.screen` | `"main"` | `"main"` or the `"mouse"` pointer screen |
| `menu.width` | `420` | HUD width in points |
| `menu.showEmojis` | `true` | Includes the menu definition's emoji in its title |
| `menu.highlightGroups` | `true` | Uses the active accent behind group shortcuts |

### Fonts and loupe

| Option | Default | Meaning |
| --- | --- | --- |
| `font.family` | `nil` | macOS system font; otherwise a valid installed family |
| `font.size` | `14` | Menu-row text size |
| `font.titleSize` | `20` | Header text size |
| `font.bodyWeight` | `"regular"` | Ordinary-entry weight |
| `font.groupWeight` | `"bold"` | Child-menu entry weight |
| `font.titleWeight` | `"bold"` | Header weight |
| `loupe.enabled` | `true` | Magnifies selected and adjacent rows |
| `loupe.selectedScale` | `1.18` | Selected-row scale |
| `loupe.adjacentScale` | `1.06` | Neighboring-row scale |
| `loupe.duration` | `0` | Selection-frame animation duration; zero is immediate |

### Themes

| Option | Default | Meaning |
| --- | --- | --- |
| `theme.name` | `"system"` | Fixed theme ID or automatic macOS light/dark selection |
| `theme.persistSelection` | `true` | Restores valid Themes-menu choices after reload |
| `theme.system.light` | `"gearbox-light"` | Palette used by light macOS appearance |
| `theme.system.dark` | `"gearbox-dark"` | Palette used by dark macOS appearance |
| `theme.accentSource` | `"system"` | `"system"` accent or the selected theme's accent |
| `theme.fallbackAccent` | macOS blue | RGB accent used when AppKit lookup fails |
| `theme.systemAccentText` | white | Text rendered over the macOS accent |
| `theme.overrides` | `{}` | Partial semantic overrides keyed by theme ID |

A partial theme override replaces only the supplied values:

```lua
theme = {
  overrides = {
    ["nord"] = {
      background = { white = 0.08 },
      selectionAlpha = 0.18,
    },
  },
}
```

Colors use either a complete grayscale or RGB model. Do not mix `white` with
RGB components. An omitted override alpha inherits the selected theme's value.
Bundled IDs and semantic palette fields are documented beside the
[theme definitions](./themes/README.md).

### Navigation

| Option | Default | Meaning |
| --- | --- | --- |
| `navigation.enabled` | `true` | Enables arrow selection and activation |
| `navigation.wrap` | `true` | Wraps at the first and last selectable row |
| `navigation.activateKey` | `"return"` | Activates the current selection |
| `navigation.cancelKey` | `"escape"` | Returns to the parent or exits |
| `navigation.includeFooter` | `true` | Includes Back or Exit in arrow navigation |
| `navigation.resetTimeoutOnInput` | `true` | Restarts an enabled timeout after navigation |

Displayed item shortcuts accept the retained Gearbox modifiers, allowing an
immediate choice before those keys are released. Escape, Up, Down, and Return
remain bare controls, preserving modified macOS shortcuts such as
`alt+cmd+escape`.

## Theme persistence

Selecting a theme updates the open HUD immediately. With
`theme.persistSelection = true`, Gearbox stores this record through
Hammerspoon:

```lua
hs.settings.set("Gearbox.theme.selection", {
  selection = "nord",
  configuredDefault = "system",
})
```

`hs.settings` is backed by:

```text
~/Library/Preferences/org.hammerspoon.Hammerspoon.plist
```

Gearbox does not rewrite `config.lua`. The stored selection is restored only
while its `configuredDefault` still matches `theme.name` and the selected theme
still exists. Otherwise it is cleared after the replacement runtime starts
successfully.

The first successful Gearbox startup also migrates a valid legacy
`Shift7.theme.selection` record, including the former `shift7-light` and
`shift7-dark` IDs, then removes the legacy key.

The current value can be inspected or cleared in the Hammerspoon console:

```lua
hs.settings.get("Gearbox.theme.selection")
hs.settings.clear("Gearbox.theme.selection")
```

Nix exposes the same switch:

```nix
programs.hammerspoon-spoons.spoons.gearbox.theme.persistSelection = true;
```

Setting it to `false` clears any stored choice after successful startup and
returns every reload to the configured `theme.name`. The complete Nix ownership
flow is documented in
[`assets/docs/NIX.md`](../../assets/docs/NIX.md#theme-persistence).

## Appearance lifecycle

`theme.accentSource = "system"` queries AppKit once during Hammerspoon
configuration load. Changing the macOS accent afterward requires `hs.reload()`.
System light/dark appearance is evaluated whenever a menu opens, so it does not
require an appearance watcher. Fonts are likewise resolved once when the Spoon
starts.

HUD-only refreshes reuse those resolved host values. Canvas geometry, padding,
indices, and animation frame rate remain internal implementation state rather
than public configuration.
