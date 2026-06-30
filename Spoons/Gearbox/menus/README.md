# Gearbox menus

`menus/` contains passive menu data. Each Lua file returns one definition;
none creates Hammerspoon objects, registers hotkeys, or depends on file load
order.

```text
menus/*.lua
  → loader.lua discovery and graph validation
  → ordered rows, dividers, and Back/Exit footer
  → runtime.lua modal bindings
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
      key = "s",
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
| `entry` | Shortcut, label, section, and ordering metadata shown by the parent |
| `items` | Rows owned by this menu |

The loader rejects duplicate IDs and keys, missing parents, parent cycles,
invalid Hammerspoon keys, reserved navigation keys, unsupported actions, and
missing action targets before runtime bindings are created.

## Current graph

| Definition | Parent | Parent key | Concern |
| --- | --- | --- | --- |
| `leader.lua` | — | — | Root applications |
| `agenda.lua` | `leader` | `n` | Calendar, Mail, Reminders |
| `applications.lua` | `leader` | `a` | Parent for application suites |
| `developer.lua` | `leader` | `d` | Developer applications |
| `finder.lua` | `leader` | `f` | Finder destinations |
| `browsers.lua` | `leader` | `w` | Web browsers |
| `macos.lua` | `leader` | `m` | Caffeinate modes and system sleep |
| `comms.lua` | `applications` | `c` | Communications |
| `omni.lua` | `applications` | `o` | Omni applications |
| `photo-and-video.lua` | `applications` | `p` | Photo and video applications |

Ordinary child definitions are sorted by their displayed label. Explicit
sections place `macOS Utilities` and the generated `Themes` entry after ordinary
groups and before the footer.

## Action descriptors

| Type | Owner at runtime |
| --- | --- |
| `launchApp` | `hs.application.launchOrFocus` |
| `openPath` | `hs.open` after home-directory expansion |
| `openMenu` | Runtime menu transition |
| `setCaffeinateMode` | Mutually exclusive Hammerspoon caffeinate assertions |
| `setTheme` | Theme selection and HUD refresh |
| `sleep` | `hs.caffeinate.systemSleep` |
| `exit` | Active modal exit |
| `custom` | Definition-owned callback escape hatch |
