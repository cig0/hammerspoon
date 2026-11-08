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

## Customize sections

Save changes in the repository and reload Hammerspoon after deploying them.
For Nix installations, edits under `~/.hammerspoon` are temporary; the next
activation deploys the flake's copy again.

### Add an app to Developer Tools

Append this row to `items` in `developer.lua` to launch Ghostty with uppercase
`G` while that menu is open:

```lua
{
  key = "G",
  label = "Ghostty",
  kind = "application",
  action = {type = "launchApp", name = "Ghostty"},
},
```

Keep commas between rows. `items` stay in written order. Insert
`{divider = true},` between rows to separate groups. Back and Exit are added
by the loader.

### Move Developer Tools before the other app groups

Replace its `entry` in `developer.lua` with:

```lua
entry = {
  key = "d",
  label = "Developer Tools",
  section = "groups",
  sectionOrder = 100,
  order = 10,
},
```

| Field | Ordering rule |
| --- | --- |
| `section` | Groups sibling menus under one divider; defaults to `"groups"` |
| `sectionOrder` | Lower numbers appear first; defaults to `100` |
| `order` | Position inside the section; explicit numbers precede unnumbered entries |

Sibling menus in the same section must use the same `sectionOrder`. Ties
sort by label, then menu ID. macOS Utilities and Gearbox Configuration use
`section = "utilities"` and `sectionOrder = 200`. Give another child those
same values to place it in that section.

To move Developer Tools inside Applications, change its `parent` to
`"applications"`. Its `entry.key` must be unique in that parent.
Application rows can use uppercase keys alongside lowercase submenu keys.

### Change a Finder destination

In `finder.lua`, change the Projects row's `path` to
`home .. "/Projects/hoagie"` to open the Hoagie checkout. Paths are passed to
`hs.open`; use `home .. "/..."` for a home-relative folder.
Both main-menu `f` and Hyper+F use these rows.

## Add a submenu

The existing `web-browsers.lua` illustrates a submenu with Safari. To add a
different group, copy that file and change its `id`, title, entry key, and
app rows. Every menu needs a unique `id` and a parent except the single root.

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
sections place `macOS Utilities` and the generated `Gearbox Configuration`
entry together after ordinary groups. The root definition enables the divider
before Exit. Set `showFooterDivider = false` there to remove it.

`menus/` intentionally contains only passive, file-backed definitions. Two
generated menu sets join that graph during startup: `theme.lua` supplies
Themes, and `preferences.lua` supplies the definitions from
`configuration_menu.lua`.
Themes and Font Size are children of Gearbox Configuration.

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
