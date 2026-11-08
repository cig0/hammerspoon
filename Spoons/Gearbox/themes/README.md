# Gearbox themes

`themes/` contains passive palette definitions. Every visible `.lua` file is loaded, validated, and added to the generated Themes menu. Files beginning with `.` or `_` are ignored.

Gearbox Configuration → Themes controls appearance. All theme rows are arrow-only (no shortcut keys — navigate with ↑/↓ + return):

| Control             | What it changes                                  |
| ------------------- | ------------------------------------------------ |
| Show Outer Frame    | Accent outline around the panel                  |
| Show Window Shadow  | Soft drop shadow, enabled by default             |
| Transparency        | Menu background opacity, 50–100% in steps of 5   |
| Set matching themes | Independent light/dark palettes for Follow macOS |

Follow macOS uses the saved light/dark pair. The selected row is checked; preview updates immediately. Escape returns to Themes.

```text
themes/*.lua
  → theme.lua discovery, validation, and overrides
  → light/dark groups sorted by label
  → HUD semantic colors
```

## Definition shape

Each palette file returns:

| Field            | Purpose                                         |
| ---------------- | ----------------------------------------------- |
| `id`             | Stable selection and persistence value          |
| `label`          | Display name in Themes menu                     |
| `group`          | `light` or `dark`                               |
| `selectionAlpha` | Highlight alpha when using accent               |
| `selection`      | Optional highlight color                        |
| `selectionText`  | Optional selected-row text color                |
| `frame`          | Optional outer frame color (defaults to accent) |
| `background`     | HUD surface                                     |
| `primary`        | Title/primary text                              |
| `secondary`      | Supporting text                                 |
| `divider`        | Separators                                      |
| `accent`         | Checks/selection                                |
| `accentText`     | Text over accent                                |

`key` is no longer used for palettes — menus are arrow-only. Older docs mentioning per-palette keys (`a`/`l`/`g` etc.) are stale; IDs still matter for persistence.

Colors: `{ white, alpha }` or `{ red, green, blue, alpha }` (`0…1`). Partial overrides may omit `alpha`.

## Bundled themes

| Group | Theme              | ID                  |
| ----- | ------------------ | ------------------- |
| Light | Purple Tentacle    | `purple-tentacle`   |
| Light | Catppuccin Latte   | `catppuccin-latte`  |
| Light | Catppuccin Mocha\* | `catppuccin-mocha`  |
| Light | Gruvbox Light      | `gruvbox-light`     |
| Dark  | Catppuccin Mocha   | `catppuccin-mocha`  |
| Dark  | Dracula            | `dracula`           |
| Dark  | Gruvbox Dark Hard  | `gruvbox-dark-hard` |
| Dark  | Gruvbox Dark       | `gruvbox-dark`      |
| Dark  | Monokai            | `monokai`           |
| Dark  | Nord               | `nord`              |
| Dark  | Tokyo Night        | `tokyo-night`       |

\*Catppuccin Mocha is dark despite being listed in both groups in legacy docs — keep the dark row as canonical. Saved selections refer to IDs above.

Frame exceptions: Gruvbox Light uses `#72553c`; both dark Gruvbox use `#665c54`; others use accent. Show Outer Frame toggles for all.

## Selection flow

`theme.name = "system"` maps macOS appearance to the matching light/dark palette on open. Pair defaults to `theme.system.light` / `theme.system.dark`; Set matching themes edits either slot.

With `theme.persistSelection = true`, choices persist at `hs.settings["Gearbox.theme.selection"]` and restore after reload. See `../README.md#theme-persistence` for fallback/invalidation rules.

## Customize Nord

Merge into `config.lua:theme`:

```lua
theme = {
  name = "nord",
  accentSource = "theme",
  overrides = {
    nord = { background = {white = 0.08}, selectionAlpha = 0.18 },
  },
}
```

Reload. If a saved choice overrides `theme.name`, pick Nord in the menu or clear saved selection.

To add a palette: copy `gruvbox-dark-hard.lua` → new visible `.lua`, change `id`/`label`/colors. No key needed. Reload to discover.

## Palette provenance

| Preset      | Upstream                                                                                        | License                                                                                |
| ----------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Gruvbox     | [morhetz/gruvbox](https://github.com/morhetz/gruvbox)                                           | [MIT/X11](https://github.com/morhetz/gruvbox#license)                                  |
| Catppuccin  | [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin)                               | [MIT](https://github.com/catppuccin/catppuccin/blob/main/LICENSE)                      |
| Monokai     | [Sublime Text default packages](https://github.com/sublimehq/Packages)                          | Upstream                                                                               |
| Nord        | [Nord](https://www.nordtheme.com/docs/colors-and-palettes)                                      | [MIT](https://github.com/nordtheme/nord/blob/develop/license)                          |
| Dracula     | [dracula/dracula-theme](https://github.com/dracula/dracula-theme)                               | [MIT](https://github.com/dracula/dracula-theme/blob/main/LICENSE)                      |
| Tokyo Night | [tokyo-night/tokyo-night-vscode-theme](https://github.com/tokyo-night/tokyo-night-vscode-theme) | [MIT](https://github.com/tokyo-night/tokyo-night-vscode-theme/blob/master/LICENSE.txt) |

## Where to look next

- `../README.md` — install, config, persistence
- `../menus/README.md` — declarative graph (arrow-only `key` contract)
- `../theme.lua` — discovery / validation / persistence
