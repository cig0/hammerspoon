# Gearbox themes

`themes/` contains passive visual definitions. Every visible `.lua` file is
loaded, validated, and added to the generated Themes menu. Files beginning with
`.` or `_` are ignored. Gearbox Configuration → Themes also controls the menu's appearance:

| Key | Control | What it changes |
| --- | --- | --- |
| `o` | Show Outer Frame | Accent outline around the panel |
| `w` | Show Window Shadow | Soft drop shadow, enabled by default |
| `p` | Transparency | Menu background opacity, from 100% to 50% in steps of 5 |
| `f` | Set matching themes | Independent light and dark palettes for Follow macOS |

The menu starts opaque. In Transparency, press `4` for 85%, `1` for 100%,
or `-` for 50%. The selected row is checked and the preview updates immediately.
Escape returns to Themes. Text, highlights, and Scratchpad use their own colors.

Set matching themes lists the same palettes in light and dark groups. Each
group has one checked choice. Choosing a palette assigns its appearance slot
without switching Follow macOS on or off. When Follow macOS is active, changing
the current appearance's palette updates the open menu immediately. Escape
returns to Themes.

```text
themes/*.lua
  → theme.lua discovery, validation, and overrides
  → light/dark menu groups sorted by label
  → HUD semantic colors
```

## Definition shape

Each theme owns:

| Field | Purpose |
| --- | --- |
| `id` | Stable selection and persistence value |
| `label`, `key` | Themes menu presentation |
| `group` | `light` or `dark` menu section |
| `selectionAlpha` | Highlight alpha when using the accent color |
| `selection` | Optional row highlight color, independent of the macOS accent |
| `selectionText` | Optional selected-row text color |
| `frame` | Optional outer frame color; defaults to the active accent |
| `background` | HUD surface |
| `primary` | Title and primary text |
| `secondary` | Supporting text |
| `divider` | Section separators |
| `accent` | Group keys, checks, and selection |
| `accentText` | Text rendered over the accent |

Colors use one complete model: `{ white, alpha }` or
`{ red, green, blue, alpha }`. Partial user overrides may omit `alpha`; the
theme's existing alpha is retained. Color components and `selectionAlpha` stay
within `0...1`; IDs and menu keys must be unique.

## Bundled themes

| Group | Theme | Key |
| --- | --- | --- |
| Light | Catppuccin Latte | `a` |
| Light | Gearbox Light | `l` |
| Light | Gruvbox Light | `g` |
| Dark | Catppuccin Mocha | `c` |
| Dark | Dracula | `r` |
| Dark | Gruvbox Dark Hard | `d` |
| Dark | Gruvbox Dark | `h` |
| Dark | Monokai | `m` |
| Dark | Nord | `n` |
| Dark | Tokyo Night | `t` |

The two dark Gruvbox labels follow background darkness. The darker palette
keeps ID `gearbox-dark` and key `d`, and displays Gruvbox Dark Hard.
The lighter palette keeps ID `gruvbox-dark-hard` and key `h`, and displays
Gruvbox Dark. Saved selections still refer to those IDs.

The dark Gruvbox variants use the light palette's cream `#fbf1c7` selection with dark brown
`#3c3836` text. Gruvbox Light uses a brown `#665c54` selection with the
dark Gruvbox palette's normal pale yellow text, `#fbf1c7`. Only the selected
row switches text colors. These selections also apply with
`theme.accentSource = "system"`.

Gruvbox Light has a Habano brown frame (`#72553c`). Both dark Gruvbox
themes use a muted gray-brown (`#665c54`) for their frame.
Other palettes use the active accent. Show Outer Frame toggles the outline
for every theme.

## Selection flow

`theme.name = "system"` maps the current macOS appearance to
the matching light or dark palette whenever a menu opens. The pair defaults to
`theme.system.light` and `theme.system.dark`; Set matching themes changes either
slot. A fixed theme ID bypasses that appearance query.

With `theme.persistSelection = true`, menu choices are stored under
`hs.settings["Gearbox.theme.selection"]` and restored after a Hammerspoon reload.
The saved record includes both matching choices. A removed or wrong-group
palette falls back to its configured slot; changing a configured slot resets
that slot's saved choice. The record is discarded when `theme.name` changes or
the selected theme no longer exists. Disabling persistence resets the selection
and pair on reload. The detailed storage and Nix behavior are in
the [Gearbox configuration](../README.md#theme-persistence) section.

## Customize Nord

Edit the existing `theme` table in `config.lua` to use Nord with a darker
background:

```lua
theme = {
  -- Keep the other existing theme settings.
  name = "nord",
  accentSource = "theme",
  overrides = {
    nord = {
      background = {white = 0.08},
      selectionAlpha = 0.18,
    },
  },
},
```

Merge these fields into that table, then reload Hammerspoon. A saved theme
choice can take precedence while `theme.name` stays the same; choose Nord
in the Themes menu or clear the saved selection as described above.

To add a palette, copy `gearbox-dark.lua` to a new visible `.lua` file and
change its ID, label, key, and colors. Choose a key unused across both theme
groups and the generated controls (`s` for Follow macOS, `o` for Show Outer
Frame, `w` for Show Window Shadow, `p` for Transparency, and `f` for Set matching
themes). Navigation keys are also reserved. Reload Hammerspoon to discover the
new palette.

## Palette provenance

Bundled third-party presets map upstream palette roles onto Gearbox's semantic
surfaces:

| Preset | Upstream | License |
| --- | --- | --- |
| Gruvbox | [morhetz/gruvbox](https://github.com/morhetz/gruvbox) | [MIT/X11](https://github.com/morhetz/gruvbox#license) |
| Catppuccin | [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) | [MIT](https://github.com/catppuccin/catppuccin/blob/main/LICENSE) |
| Monokai | [Sublime Text default packages](https://github.com/sublimehq/Packages) | [Upstream license](https://github.com/sublimehq/Packages/blob/master/LICENSE) |
| Nord | [Nord palette](https://www.nordtheme.com/docs/colors-and-palettes) | [MIT](https://github.com/nordtheme/nord/blob/develop/license) |
| Dracula | [dracula/dracula-theme](https://github.com/dracula/dracula-theme) | [MIT](https://github.com/dracula/dracula-theme/blob/main/LICENSE) |
| Tokyo Night | [tokyo-night/tokyo-night-vscode-theme](https://github.com/tokyo-night/tokyo-night-vscode-theme) | [MIT](https://github.com/tokyo-night/tokyo-night-vscode-theme/blob/master/LICENSE.txt) |

## Where to look next

- [`../README.md`](../README.md) — theme configuration, overrides, persistence,
  and appearance lifecycle.
- [`../menus/README.md`](../menus/README.md) — the surrounding declarative menu
  graph.
- [`../theme.lua`](../theme.lua) — discovery, validation, persistence, and
  semantic-color resolution.
