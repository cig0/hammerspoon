# Gearbox

Gearbox is a native Hammerspoon keyboard launcher with nested menus, direct
shortcuts, arrow navigation, an editable scratchpad, loupe scaling, macOS power
controls, and auto-discovered themes. It uses the macOS system font by default
and can follow the current appearance and accent.

## Requirements

- macOS with [Hammerspoon](https://www.hammerspoon.org/) installed and running.
- A positive menu timeout, set in `config.lua` for a standalone installation or
  through the Nix delivery option.

Gearbox has no third-party Lua dependencies and does not require Nix. It
bundles its first-party RetroUI dependency privately when installed, so a
standalone Spoon remains self-contained.

## Install and enable

### Standalone

From a checkout of this repository, copy the Spoon into Hammerspoon's standard
configuration tree:

```sh
mkdir -p ~/.hammerspoon/Spoons/Gearbox
cp -R Spoons/Gearbox/. ~/.hammerspoon/Spoons/Gearbox/
```

Set `menu.timeout` to a positive value in [`config.lua`](./config.lua), then
load Gearbox from `~/.hammerspoon/init.lua`:

```lua
require("Spoons.Gearbox").start()
```

Reload Hammerspoon and press `alt+cmd+space`. A full clone at
`~/.hammerspoon` already has the expected directory layout; only the import in
the repository's root [`init.lua`](../../init.lua) needs to be enabled.

The Spoon itself contains `lib/RetroUI/package.json`, whose version is the
exact bundled library version. Gearbox resolves that private namespace first;
canonical `lib.RetroUI` is only a development fallback for an incomplete
checkout.

### Nix

The Home Manager module installs the Spoon and generates its loader. A working
configuration includes an explicit positive timeout:

```nix
programs.hammerspoon-spoons = {
  enable = true;
  spoons.gearbox.menu.timeout = 5;
};
```

See [Nix delivery](../../assets/docs/NIX.md) for module imports, managed and
external `init.lua` ownership, and the Home Manager integration boundary.

## Controls

```text
alt+cmd+space → open or close Gearbox and its scratchpad
shown key     → run or open the entry with that exact character
↑ / ↓         → select an entry
Return        → activate the selection
Esc           → return to the parent or exit
s             → open the scratchpad from the root menu
g             → open Gearbox configuration from the root menu
Tab           → insert a tab while editing the scratchpad
```

The first arrow press selects the first or last entry. Selection wraps by
default. Loupe scaling is immediate, so key repeat does not wait for an
animation.

Displayed character shortcuts are case-sensitive and use the character the
keyboard produces. With Caps Lock off, `w` produces `w` and Shift+`w` produces
`W`; with Caps Lock on, those results reverse. Digits and their shifted symbols
are distinct too, so `1` and `!` can activate different rows. Caps Lock changes
ASCII letters only.

Bundled menu data uses lowercase characters for navigation and uppercase
characters for applications. That is an explicit data convention, not a
runtime inference: a custom menu may assign any supported character to either
kind of action.

The session input listener runs only while a Gearbox menu is open. It observes
character key-down events plus Caps Lock state changes, remains active across
submenu transitions, and stops on exit, timeout, Scratchpad entry, or
`Gearbox.stop()`. Gearbox refuses to open the menu and shows an alert when macOS
Secure Input prevents reliable character capture.

### Character input provenance

Gearbox reads each key-down event with Hammerspoon's `getCharacters(true)`,
[verified against the Hammerspoon 1.1.1 source](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/eventtap/libeventtap_event.m#L516-L541),
which delegates to AppKit's
[`charactersIgnoringModifiers`](https://developer.apple.com/documentation/appkit/nsevent/charactersignoringmodifiers).
On 2026-08-27, a native AppKit probe for `w` returned cleaned characters `w`,
`W`, `w`, and `W` for no modifiers, Shift, Caps Lock, and Caps Lock+Shift.
Gearbox therefore applies the event-local, currently experimental
[`alphaShift` raw flag](https://www.hammerspoon.org/docs/hs.eventtap.event.html#rawFlagMasks)
once, and only to ASCII letters. If that event API is unavailable, it falls
back to Hammerspoon's
[`checkKeyboardModifiers()`](https://www.hammerspoon.org/docs/hs.eventtap.html#checkKeyboardModifiers)
poll.

## Menu map

```text
Gearbox
├── Calculator
├── ForkLift
├── KeePassXC
├── Obsidian
├── Passwords
├── Scratchpad
├── Agenda
│   ├── Calendar
│   ├── Mail
│   └── Reminders
├── AI
│   ├── ChatGPT
│   └── Gemini
├── Applications
│   ├── Communications
│   │   ├── Discord
│   │   └── WhatsApp
│   ├── Omni Software Suite
│   │   ├── OmniFocus
│   │   └── OmniOutliner
│   └── Photo & Video
│       ├── Affinity
│       ├── Photos
│       └── PowerPhotos
├── Developer Tools
│   ├── Codex
│   ├── Sublime Merge
│   ├── VirtualBuddy
│   └── Zed
├── Finder Folders
│   ├── I SHOOT RAW
│   ├── Desktop
│   ├── Documents
│   ├── Downloads
│   ├── Home
│   ├── iCloud
│   ├── Pictures
│   ├── Projects
│   ├── tmp
│   └── Sync
├── Web Browsers
│   ├── Brave Origin
│   ├── ChatGPT Atlas
│   ├── Comet Browser
│   ├── Firefox
│   └── Safari
├── macOS Utilities
│   ├── System Settings
│   ├── Keep Display Awake
│   ├── Prevent Idle Sleep
│   ├── Allow Normal Sleep
│   └── Sleep
└── Gearbox Configuration
    ├── Reload Hammerspoon
    ├── Save Versioned Profile
    ├── Reload Versioned Profile
    ├── Reset Local Overrides
    ├── Menu Position
    │   ├── Top
    │   └── Bottom
    ├── Scratchpad
    │   ├── Persist Content
    │   ├── Hammerspoon Settings
    │   ├── External File
    │   ├── Filename
    │   ├── Width
    │   └── Height
    └── Themes
        ├── Follow macOS
        ├── Show Outer Frame
        ├── Light: Catppuccin, Gearbox, Gruvbox
        └── Dark: Catppuccin, Dracula, Gearbox, Gruvbox, Monokai, Nord, Tokyo Night
```

Ordinary child menus are sorted by displayed label. `macOS Utilities` and
`Gearbox Configuration` occupy separate root sections. The root footer follows
Gearbox Configuration without another divider. Themes retain separate Light
and Dark sections and sort alphabetically within each.

The root header samples Caps Lock when the menu opens and refreshes immediately
when Caps Lock changes while it remains visible. The inverse-color `CAPS LOCK`
warning requires no polling timer or stored Caps Lock state. Gearbox
Configuration begins with the smaller, subdued memory aid “See Spoon
documentation to customize the menu shortcut.” An eight-point gap separates
the caption from the first option.

When `menu.showAccentBorder` is enabled, every menu draws a two-point outline
inside its canvas using the active theme accent. The shared corner radius keeps
the outline aligned with the menu background. The checked `Show Outer Frame`
item in Themes toggles the outline for the current preference profile.

The macOS power modes behave as one checked selection:

- `Keep Display Awake` enables `displayIdle`.
- `Prevent Idle Sleep` enables `systemIdle`.
- `Allow Normal Sleep` disables both and is the default.

Hammerspoon releases those assertions when its configuration reloads.

## Directory map

| Path | Owns |
| --- | --- |
| [`config.lua`](./config.lua) | Runtime configuration contract; Nix derives only `menu.timeout` |
| [`menus/`](./menus/README.md) | Passive, file-backed menu graph and action descriptors |
| [`themes/`](./themes/README.md) | Passive palettes and generated Themes-menu metadata |
| [`loader.lua`](./loader.lua) | Discovery, validation, ordering, dividers, and footers |
| [`actions.lua`](./actions.lua) | Application, filesystem, power, and theme operations |
| [`runtime.lua`](./runtime.lua) | Modal lifecycle, session input, timeout, selection, and rollback |
| [`hud.lua`](./hud.lua) | Canvas geometry, text, checks, selection, and loupe rendering |
| [`scratchpad.lua`](./scratchpad.lua) | Editable webview, keyboard handling, persistence, and focus |
| [`scratchpad_storage.lua`](./scratchpad_storage.lua) | Scratchpad settings/file persistence and atomic file replacement |
| [`configuration_menu.lua`](./configuration_menu.lua) | Passive generated Gearbox Configuration menu graph and memory-aid legend |
| [`preferences.lua`](./preferences.lua) | Profile/local preference layering and configuration actions |
| [`theme.lua`](./theme.lua) | Theme loading, persistence, colors, and the generated Themes menu |
| [`validation.lua`](./validation.lua) | Configuration, color, and hotkey validation |
| [`dependencies.lua`](./dependencies.lua) | Resolves the packaged RetroUI copy, then a development checkout |
| [`init.lua`](./init.lua) | Public `start()` and `stop()` boundary |
| [`tests/`](../../tests/README.md) | Mocked-Hammerspoon smoke and regression coverage |

```text
config.lua + preferences.json + local hs.settings + menus/*.lua + themes/*.lua
  → init.lua
    → configuration_menu.lua and theme.lua generate state-dependent menus
    → preferences.lua owns preference state and actions
    → loader.lua joins generated menus with menus/*.lua
    → validation.lua
    → runtime.lua + actions.lua
      → hud.lua
      → scratchpad.lua → scratchpad_storage.lua
```

## Configuration (`config.lua`)

[`config.lua`](./config.lua) is the runtime configuration contract. It contains
no Hammerspoon calls, and `Gearbox.start()` accepts no configuration arguments.
A standalone installation reads the file as shipped or edited locally. The
versioned profile and local preferences then override only menu position, outer
frame visibility, and the documented Scratchpad fields.

Nix delivery creates a derived copy of the Spoon and substitutes only
`menu.timeout` from
`programs.hammerspoon-spoons.spoons.gearbox.menu.timeout`. Every other setting
still comes directly from `config.lua`; no Lua override table is passed at
startup. See [configuration ownership](../../assets/docs/NIX.md#configuration-ownership).

### Hotkey and menu

| Option | Default | Meaning |
| --- | --- | --- |
| `hotkey.modifiers` | `{ "alt", "cmd" }` | Modifiers used to open or close Gearbox |
| `hotkey.key` | `"space"` | Hammerspoon key name paired with the modifiers |
| `menu.timeout` | `0` | Seconds before closing; zero leaves Gearbox stopped and shows its configuration dialog |
| `menu.position` | `"top"` | `"top"`, `"center"`, or `"bottom"` screen placement |
| `menu.screen` | `"main"` | `"main"` or the `"mouse"` pointer screen |
| `menu.width` | `420` | HUD width in points |
| `menu.showEmojis` | `true` | Includes the menu definition's emoji in its title |
| `menu.highlightGroups` | `true` | Uses the active accent behind group shortcut key caps at every submenu depth |
| `menu.showAccentBorder` | `true` | Draws a two-point active-theme accent border around every menu |

The zero timeout is a deliberate disabled sentinel, not a usable runtime
setting. `Gearbox.start()` opens a Borland-style RetroUI dialog that dismisses
after 30 seconds or immediately after pressing Return or clicking Accept, then
returns without failing Hammerspoon configuration loading or allocating
Gearbox menus, hotkeys, the HUD, or the scratchpad. Set a positive timeout in
`config.lua`, or in the Nix option that derives the deployed copy, to start
Gearbox normally.

The warning's 30-second legend and Accept button share a footer row. Return or
the `A` mnemonic presses and releases Accept; Tab and Shift-Tab move button
focus; only a left click that begins and ends on Accept activates it. A right
click, releasing over a different target, or dragging out of the button does
nothing. The button face shifts down-right over its shadow while held. Each
dismissal first releases its timer, modal bindings, canvas callback, and canvas;
repeated reloads or `Gearbox.stop()` cannot leave a warning behind.

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

Displayed character shortcuts accept either no Command, Option, or Control
modifier, or the exact subset used by the Gearbox hotkey. This permits an
immediate choice before the opening modifiers are released. Shift always
selects the resulting character, even when Shift belongs to the opening
hotkey. Escape, Up, Down, and Return remain bare controls, preserving modified
macOS shortcuts such as `alt+cmd+escape`.

Navigation keys may use named Hammerspoon keys or letters. Raw keycodes and
printable keypad names are rejected because they can describe the same
physical input as a resulting-character row, leaving two input owners.

### Scratchpad

| Option | Default | Meaning |
| --- | --- | --- |
| `scratchpad.enable` | `true` | Includes the scratchpad in the root menu |
| `scratchpad.fontSize` | `14` | Editor font size in pixels |
| `scratchpad.width` | `720` | Width in points, clamped to the selected screen |
| `scratchpad.height` | `480` | Height in points, clamped to the selected screen |
| `scratchpad.maxCharacters` | `4096` | Maximum editable text capacity; existing longer content is preserved |
| `scratchpad.persistContent` | `true` | Restores content through local `hs.settings` storage |
| `scratchpad.storagePath` | `nil` | Local `hs.settings`; an absolute or `~/` path selects one regular text file |
| `scratchpad.showInstructions` | `true` | Displays the non-editable keyboard reference footer |

The `s` shortcut and `openScratchpad` action are declared directly in
[`menus/leader.lua`](./menus/leader.lua), following the same structure as the
other root entries. Its generic `requires = "scratchpad"` metadata tells the
loader to omit the entry when `scratchpad.enable` is false.

The scratchpad inherits `menu.screen`, `menu.position`, the active semantic
palette, and the resolved Gearbox font family for editable text. Its editor size
comes from `scratchpad.fontSize`. The title and non-editable footer use Avenir
Next, which ships with macOS, with the macOS system UI font as a fallback. Its
borderless webview is created on first use and reused afterward, avoiding WebKit
allocation when the scratchpad is never opened. A failed first construction
releases partial native objects and leaves the Gearbox menu active for another
attempt. The non-editable footer derives the configured Gearbox hotkey using the
same modifier and key order as the main-menu Exit row. That hotkey closes the
scratchpad; no second global hotkey is created.

With persistence enabled and `storagePath = nil`, content is stored under
`hs.settings["Gearbox.scratchpad.content"]`. An absolute path or a path beginning
with `~/` selects one regular UTF-8 file instead. The parent directory must
already exist; missing files begin empty and are created on the first save.
Writes atomically replace the destination, reject symbolic links, and never
fall back to `hs.settings` after an error.

File content is reloaded whenever the Scratchpad opens, so a closed editor sees
changes synchronized from another host. There is no watcher or merge engine;
simultaneous editors remain last-writer-wins. Disabling persistence keeps
content only for the current Hammerspoon runtime. Neither backend is encrypted,
and selecting a file does not implicitly copy or clear content in the other
backend. `maxCharacters` limits new input without silently truncating content
that was already saved above the configured limit.

## Runtime preferences

The generated Gearbox Configuration menus update a strict subset of the
effective configuration:

| Menu | Values |
| --- | --- |
| Themes | outer frame visibility |
| Menu Position | `top`, `bottom` |
| Scratchpad | persistence, storage folder/filename, width, height |
| Profile | save, reload, clear local overrides |

Every selection applies immediately and is stored as a local override under
`hs.settings["Gearbox.preferences.local.v1"]`. The effective value flow is:

```text
config.lua defaults
  → ~/.config/hammerspoon-gearbox/preferences.json
  → local hs.settings overrides
  → HUD and Scratchpad
```

`Save Versioned Profile` atomically writes the complete portable subset and
clears redundant local overrides. `Reload Versioned Profile` re-reads the file
while retaining local overrides. `Reset Local Overrides` clears only the local
layer; Git remains responsible for reviewing, reverting, and distributing the
profile file.

```json
{
  "schemaVersion": 1,
  "menu": {
    "position": "bottom",
    "showAccentBorder": true
  },
  "scratchpad": {
    "persistContent": true,
    "storage": {
      "backend": "file",
      "path": "~/Library/Mobile Documents/com~apple~CloudDocs/Hammerspoon/scratchpad.txt"
    },
    "width": 800,
    "height": 600
  }
}
```

The profile is passive JSON, contains no executable Lua, and is read only at
startup or after the explicit reload action. Gearbox creates its parent
directory when saving but does not watch the file or commit changes. Existing
version-one profiles without `menu.showAccentBorder` retain the value from
`config.lua`; the field is written the next time the profile is saved.

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

Setting `theme.persistSelection = false` in `config.lua` clears any stored
choice after successful startup and returns every reload to the configured
`theme.name`. The Nix delivery boundary is documented in
[`assets/docs/NIX.md`](../../assets/docs/NIX.md#configuration-ownership).

## Appearance lifecycle

`theme.accentSource = "system"` queries AppKit once during Hammerspoon
configuration load. Changing the macOS accent afterward requires `hs.reload()`.
System light/dark appearance is evaluated whenever a menu opens, so it does not
require an appearance watcher. Fonts are likewise resolved once when the Spoon
starts.

HUD-only refreshes reuse those resolved host values. Canvas geometry, padding,
indices, and animation frame rate remain internal implementation state rather
than public configuration.

## Verification

The deterministic Lua harness exercises the real Gearbox modules against a
mocked Hammerspoon boundary:

```sh
lua tests/gearbox.lua "$(pwd)"
```

Run it from the repository root. `nix flake check` separately validates the
flake outputs; focused evaluation validates the Home Manager module. Native
rendering and application launches remain the live Hammerspoon boundary.

## Where to look next

- [`menus/README.md`](./menus/README.md) — menu graph, definition fields, and
  action descriptors.
- [`themes/README.md`](./themes/README.md) — palette schema, bundled themes,
  selection flow, and upstream provenance.
- [`assets/docs/NIX.md`](../../assets/docs/NIX.md) — Home Manager delivery.
- [`tests/README.md`](../../tests/README.md) — regression-harness scope.
