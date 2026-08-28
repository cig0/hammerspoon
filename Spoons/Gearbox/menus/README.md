# Gearbox menus

`menus/` contains passive menu data. Each Lua file returns one definition;
none creates Hammerspoon objects, registers hotkeys, or depends on file load
order.

```text
menus/*.lua
  → loader.lua discovery and graph validation
  → ordered rows, dividers, and Back/Exit footer
  → runtime.lua character dispatch and named-key modal bindings
```

Files beginning with `.` or `_` are ignored. Every other `.lua` file enters the
same validated graph.

## Definition shape

```lua
return {
  id = "browsers",
  title = "Web Browsers",
  emoji = "🌐",
  parent = "leader",

  entry = {
    key = "w",
    label = "Web Browsers",
  },

  items = {
    {
      key = "S",
      label = "Safari",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Safari",
      },
    },
  },
}
```

| Field | Destination |
| --- | --- |
| `id` | Stable graph identity |
| `title`, `emoji` | HUD header |
| `parent` | Parent menu ID; omitted only by the root |
| `entry.key`, `entry.label` | Shortcut and label shown by the parent |
| `entry.section`, `entry.sectionOrder`, `entry.order` | Optional parent-section and deterministic ordering metadata |
| `items` | Rows owned by this menu; omitted when the definition only groups children |
| `items[].requires` | Optional feature name whose `config.<name>.enable` controls the row |
| `items[].action` | Descriptor validated by `actions.lua` and dispatched by `runtime.lua` |
| `{ divider = true }` | Explicit divider between item groups |
| `showFooterDivider` | Optional Boolean; `false` places Back/Exit directly after the final row |

The loader rejects duplicate IDs and keys, missing parents, parent cycles,
invalid Hammerspoon keys, reserved navigation keys, unsupported actions, and
missing action targets before runtime bindings are created.

## Activation-key contract

An item or child-menu entry may use one exact printable ASCII character other
than space. Letter case is significant: `w` and `W` are separate shortcuts, as
are a digit and its shifted symbol such as `1` and `!`. Runtime dispatch uses
the character produced by Shift and Caps Lock, not an inferred physical chord.
See the main README's
[character input provenance](../README.md#character-input-provenance) for the
native event contract.

Bundled definitions use lowercase characters for menu navigation and uppercase
characters for application launches. Keep that convention explicit in menu
data; the loader does not guess action intent from case.

Named Hammerspoon keys such as `escape`, `return`, `up`, and `down` remain
modal-owned physical controls. The generated Back/Exit footer and configured
navigation controls follow that path. A modal-owned letter reserves both cases
because Caps Lock can produce either one without changing the modal chord.
Raw keycodes and printable keypad names are not valid menu-row or navigation
keys because they can alias a resulting-character row. Use the resulting
character itself for those entries.

## Current graph

| Definition | Parent | Parent key | Concern |
| --- | --- | --- | --- |
| `leader.lua` | — | — | Root applications and optional scratchpad |
| `agenda.lua` | `leader` | `n` | Calendar, Mail, Reminders |
| `ai.lua` | `leader` | `i` | ChatGPT and Gemini |
| `applications.lua` | `leader` | `a` | Parent for application suites |
| `developer.lua` | `leader` | `d` | Developer applications |
| `finder.lua` | `leader` | `f` | Finder destinations |
| `web-browsers.lua` | `leader` | `w` | Web browsers |
| `macos.lua` | `leader` | `m` | Caffeinate and macOS system controls |
| `comms.lua` | `applications` | `c` | Communications |
| `omni.lua` | `applications` | `o` | Omni applications |
| `photo-and-video.lua` | `applications` | `p` | Photo and video applications |

Ordinary child definitions are sorted by their displayed label. Explicit root
sections place `macOS Utilities` after ordinary groups, then add a divider
before the generated `Gearbox Configuration` entry. The root definition omits
the otherwise-default divider before its Exit footer.

`menus/` intentionally contains only passive, file-backed definitions. Two
state-dependent definitions join that graph during startup: `theme.lua`
generates `Themes` from the discovered palettes, and `preferences.lua`
generates `Gearbox Configuration` from the supported preference operations.
Themes is a child of Gearbox Configuration.

## Action descriptors

| Type | Owner at runtime |
| --- | --- |
| `launchApp` | `hs.application.launchOrFocus` |
| `openPath` | `hs.open` |
| `openMenu` | Runtime menu transition |
| `setCaffeinateMode` | Mutually exclusive Hammerspoon caffeinate assertions |
| `setTheme` | Theme selection and HUD refresh |
| `configure` | Validated preferences, profile operations, and HUD refresh |
| `openScratchpad` | Scratchpad display and menu dismissal |
| `reload` | `hs.reload` |
| `sleep` | `hs.caffeinate.systemSleep` |
| `exit` | Active modal exit |
| `custom` | Definition-owned callback escape hatch |

## Where to look next

- [`../README.md`](../README.md) — Gearbox installation, controls, and complete
  configuration.
- [`../themes/README.md`](../themes/README.md) — the generated Themes menu and
  palette contract.
- [`../preferences.lua`](../preferences.lua) — generated Gearbox Configuration
  menus and their profile/local preference state.
- [`../loader.lua`](../loader.lua) — discovery, validation, sorting, dividers,
  and footer assembly.
